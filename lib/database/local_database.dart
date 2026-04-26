import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

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
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        username        TEXT    NOT NULL UNIQUE,
        password        TEXT    NOT NULL,
        role            TEXT    NOT NULL DEFAULT 'DELIVERY_AGENT',
        active          INTEGER NOT NULL DEFAULT 1,
        fcm_token       TEXT,
        first_name      TEXT,
        last_name       TEXT,
        phone           TEXT,
        cnib_image_path   TEXT,
        cnib_ocr_text     TEXT,
        cnib_national_id  TEXT,
        cnib_serial       TEXT,
        birth_date        TEXT,
        birth_place       TEXT,
        gender            TEXT,
        profession        TEXT,
        cnib_issue_date   TEXT,
        cnib_expiry_date  TEXT,
        created_at        TEXT    DEFAULT (datetime('now'))
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
        manualLocationLink TEXT,
        deliveryType       TEXT,
        scheduledTime      TEXT,
        deliveryCost       REAL,
        distance           REAL,
        subtotal           REAL    DEFAULT 0,
        tax                REAL    DEFAULT 0,
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
      {'key': 'contact_email', 'value': ''},
      {'key': 'support_whatsapp', 'value': ''},
      {'key': 'store_api_origin', 'value': AppConfig.defaultStoreApiOrigin},
    ]) {
      batch.insert('app_config', entry,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();

    // ── Seed : compte admin ──────────────────────────────────────────────────
    await db.insert('users', {
      'username': AppConfig.defaultLocalAdminUsername,
      'password': _hash(AppConfig.defaultLocalAdminPassword),
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
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
    if (oldVersion < 6) {
      await _migrateToV6(db);
    }
    if (oldVersion < 7) {
      await _migrateToV7(db);
    }
    if (oldVersion < 8) {
      await _migrateToV8(db);
    }
  }

  /// Aligne le mot de passe du compte [AppConfig.defaultLocalAdminUsername] sur la valeur courante d’AppConfig.
  Future<void> _migrateToV7(Database db) async {
    final h = _hash(AppConfig.defaultLocalAdminPassword);
    await db.update(
      'users',
      {'password': h},
      where: 'username = ?',
      whereArgs: [AppConfig.defaultLocalAdminUsername],
    );
  }

  Future<void> _migrateToV8(Database db) async {
    // Si l’installation existante a une ancienne URL (ou une URL vide), on la corrige.
    // Sinon on ne casse pas la config déjà personnalisée.
    final rows = await db.query(
      'app_config',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['store_api_origin'],
      limit: 1,
    );
    if (rows.isEmpty) {
      await db.insert(
        'app_config',
        {'key': 'store_api_origin', 'value': AppConfig.defaultStoreApiOrigin},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return;
    }

    final current = (rows.first['value'] as String?)?.trim() ?? '';
    final normalized = normalizeStoreApiOrigin(current) ?? '';
    final lower = normalized.toLowerCase();
    final shouldReplace =
        lower.isEmpty || lower.contains('sucre-store.socialracine.com');
    if (shouldReplace) {
      await db.update(
        'app_config',
        {'value': AppConfig.defaultStoreApiOrigin},
        where: 'key = ?',
        whereArgs: ['store_api_origin'],
      );
    }
  }

  Future<void> _migrateToV4(Database db) async {
    final userCols = await db.rawQuery('PRAGMA table_info(users)');
    final names = userCols.map((c) => c['name'] as String).toSet();
    if (!names.contains('first_name')) {
      await db.execute('ALTER TABLE users ADD COLUMN first_name TEXT');
    }
    if (!names.contains('last_name')) {
      await db.execute('ALTER TABLE users ADD COLUMN last_name TEXT');
    }
    if (!names.contains('phone')) {
      await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
    }
    if (!names.contains('cnib_image_path')) {
      await db.execute('ALTER TABLE users ADD COLUMN cnib_image_path TEXT');
    }
    if (!names.contains('cnib_ocr_text')) {
      await db.execute('ALTER TABLE users ADD COLUMN cnib_ocr_text TEXT');
    }
    await db.insert(
      'app_config',
      {'key': 'contact_email', 'value': ''},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'app_config',
      {'key': 'support_whatsapp', 'value': ''},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _migrateToV5(Database db) async {
    final userCols = await db.rawQuery('PRAGMA table_info(users)');
    final names = userCols.map((c) => c['name'] as String).toSet();
    Future<void> addCol(String col, String ddl) async {
      if (!names.contains(col)) {
        await db.execute(ddl);
      }
    }
    await addCol('cnib_national_id', 'ALTER TABLE users ADD COLUMN cnib_national_id TEXT');
    await addCol('cnib_serial', 'ALTER TABLE users ADD COLUMN cnib_serial TEXT');
    await addCol('birth_date', 'ALTER TABLE users ADD COLUMN birth_date TEXT');
    await addCol('birth_place', 'ALTER TABLE users ADD COLUMN birth_place TEXT');
    await addCol('gender', 'ALTER TABLE users ADD COLUMN gender TEXT');
    await addCol('profession', 'ALTER TABLE users ADD COLUMN profession TEXT');
    await addCol('cnib_issue_date', 'ALTER TABLE users ADD COLUMN cnib_issue_date TEXT');
    await addCol('cnib_expiry_date', 'ALTER TABLE users ADD COLUMN cnib_expiry_date TEXT');
  }

  Future<void> _migrateToV6(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(orders)');
    final names = cols.map((c) => c['name'] as String).toSet();

    Future<void> addCol(String col, String ddl) async {
      if (!names.contains(col)) {
        await db.execute(ddl);
      }
    }

    await addCol('manualLocationLink',
        'ALTER TABLE orders ADD COLUMN manualLocationLink TEXT');
    await addCol('deliveryType', 'ALTER TABLE orders ADD COLUMN deliveryType TEXT');
    await addCol('scheduledTime', 'ALTER TABLE orders ADD COLUMN scheduledTime TEXT');
    await addCol('deliveryCost', 'ALTER TABLE orders ADD COLUMN deliveryCost REAL');
    await addCol('distance', 'ALTER TABLE orders ADD COLUMN distance REAL');
    await addCol('subtotal', 'ALTER TABLE orders ADD COLUMN subtotal REAL DEFAULT 0');
    await addCol('tax', 'ALTER TABLE orders ADD COLUMN tax REAL DEFAULT 0');
  }

  Future<void> clearOrders() async {
    await db.delete('orders');
  }

  /// Garantit le compte admin (et livreur démo) en base pour les installs / migrations anciennes.
  Future<void> ensureDefaultLocalAccounts() async {
    final database = db;
    Future<void> ensureUser({
      required String username,
      required String plainPassword,
      required String role,
    }) async {
      final existing = await database.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );
      if (existing.isNotEmpty) return;
      await database.insert('users', {
        'username': username,
        'password': _hash(plainPassword),
        'role': role,
        'active': 1,
      });
    }

    await ensureUser(
      username: AppConfig.defaultLocalAdminUsername,
      plainPassword: AppConfig.defaultLocalAdminPassword,
      role: 'ADMIN',
    );
    await ensureUser(
      username: 'livreur',
      plainPassword: 'livreur123',
      role: 'DELIVERY_AGENT',
    );
  }

  Future<UserModel?> authenticateLocalUser(
    String username,
    String plainPassword,
  ) async {
    final rows = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, _hash(plainPassword)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    if ((row['active'] as int? ?? 1) != 1) return null;
    return UserModel.fromSqlite(row);
  }
}
