import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../config/app_config.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Database get db {
    if (_db == null) throw StateError('Database not initialized. Call init() first.');
    return _db!;
  }

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConfig.dbName);

    _db = await openDatabase(
      path,
      version: AppConfig.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  Future<void> _onCreate(Database db, int version) async {
    // ── Utilisateurs ────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE users (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        username   TEXT    NOT NULL UNIQUE,
        password   TEXT    NOT NULL,
        role       TEXT    NOT NULL DEFAULT 'DELIVERY_AGENT',
        active     INTEGER NOT NULL DEFAULT 1,
        fcm_token  TEXT,
        created_at TEXT    DEFAULT (datetime('now'))
      )
    ''');

    // ── Commandes ────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE orders (
        id                INTEGER PRIMARY KEY,
        orderNumber       TEXT    NOT NULL,
        confirmationCode  TEXT,
        customerName      TEXT    NOT NULL DEFAULT '',
        customerAddress   TEXT    NOT NULL DEFAULT '',
        customerPhone     TEXT    NOT NULL DEFAULT '',
        customerNotes     TEXT,
        customerLatitude  REAL,
        customerLongitude REAL,
        total             REAL    DEFAULT 0,
        status            TEXT    DEFAULT 'CONFIRMED',
        sourcePlatform    TEXT    DEFAULT 'manual',
        syncStatus        TEXT    DEFAULT 'local',
        createdAt         TEXT,
        updatedAt         TEXT,
        deliveryAgentId   INTEGER
      )
    ''');

    // ── Positions livreurs ───────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE driver_locations (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        driver_id  INTEGER NOT NULL UNIQUE,
        lat        REAL    NOT NULL,
        lng        REAL    NOT NULL,
        updated_at TEXT    NOT NULL,
        FOREIGN KEY (driver_id) REFERENCES users(id)
      )
    ''');

    // ── Attributions commandes ───────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE order_assignments (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId     INTEGER NOT NULL,
        driverId    INTEGER NOT NULL,
        notifiedAt  TEXT,
        acceptedAt  TEXT,
        status      TEXT    DEFAULT 'NOTIFIED',
        UNIQUE(orderId, driverId)
      )
    ''');

    // ── Configuration application ────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE app_config (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        key   TEXT    NOT NULL UNIQUE,
        value TEXT    NOT NULL DEFAULT ''
      )
    ''');

    // ── Sources externes (intégrations plateformes) ──────────────────────────
    await db.execute('''
      CREATE TABLE external_sources (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT    NOT NULL,
        platformType TEXT    NOT NULL DEFAULT 'webhook',
        configJson   TEXT    NOT NULL DEFAULT '{}',
        isActive     INTEGER NOT NULL DEFAULT 1,
        createdAt    TEXT    NOT NULL
      )
    ''');

    // ── Actions en attente (sync offline) ───────────────────────────────────
    await db.execute('''
      CREATE TABLE pending_actions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        actionType  TEXT    NOT NULL,
        payloadJson TEXT    NOT NULL DEFAULT '{}',
        createdAt   TEXT    NOT NULL,
        status      TEXT    NOT NULL DEFAULT 'pending'
      )
    ''');

    // ── Seed : configuration par défaut ─────────────────────────────────────
    final batch = db.batch();
    for (final entry in [
      {'key': 'app_name',      'value': AppConfig.defaultAppName},
      {'key': 'app_logo_url',  'value': AppConfig.defaultLogoUrl},
      {'key': 'primary_color', 'value': AppConfig.defaultPrimaryColor},
      {'key': 'contact_phone', 'value': ''},
      {'key': 'contact_address', 'value': ''},
    ]) {
      batch.insert('app_config', entry,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();

    // ── Seed : compte admin ──────────────────────────────────────────────────
    await db.insert('users', {
      'username': 'admin',
      'password': _hash('admin123'),
      'role': 'ADMIN',
      'active': 1,
    });

    // ── Seed : livreur par défaut ────────────────────────────────────────────
    await db.insert('users', {
      'username': 'livreur',
      'password': _hash('livreur123'),
      'role': 'DELIVERY_AGENT',
      'active': 1,
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Pour les futures migrations incrémentales
    if (oldVersion < 3) {
      await _onCreate(db, newVersion);
    }
  }

  Future<void> clearOrders() async {
    await db.delete('orders');
  }
}
