import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import 'local_database.dart';

class DriversDao {
  DriversDao._();
  static final DriversDao instance = DriversDao._();

  Database get _db => LocalDatabase.instance.db;

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  UserModel _fromRow(Map<String, dynamic> row) => UserModel(
        id: row['id'] as int,
        username: row['username'] as String,
        role: row['role'] as String,
        active: (row['active'] as int? ?? 1) == 1,
        lat: row['lat'] != null ? (row['lat'] as num).toDouble() : null,
        lng: row['lng'] != null ? (row['lng'] as num).toDouble() : null,
        fcmToken: row['fcm_token'] as String?,
      );

  // ── Lecture ────────────────────────────────────────────────────────────────

  Future<List<UserModel>> getAllDrivers() async {
    final rows = await _db.rawQuery('''
      SELECT u.id, u.username, u.role, u.active, u.fcm_token,
             dl.lat, dl.lng
      FROM users u
      LEFT JOIN driver_locations dl ON dl.driver_id = u.id
      WHERE u.role = 'DELIVERY_AGENT'
      ORDER BY u.username ASC
    ''');
    return rows.map(_fromRow).toList();
  }

  /// Livreurs actifs avec une position connue (pour l'assignation)
  Future<List<UserModel>> getActiveDriversWithLocation() async {
    final rows = await _db.rawQuery('''
      SELECT u.id, u.username, u.role, u.active, u.fcm_token,
             dl.lat, dl.lng
      FROM users u
      INNER JOIN driver_locations dl ON dl.driver_id = u.id
      WHERE u.role = 'DELIVERY_AGENT' AND u.active = 1
    ''');
    return rows.map(_fromRow).toList();
  }

  // ── Écriture ───────────────────────────────────────────────────────────────

  Future<void> createDriver(String username, String password) async {
    await _db.insert('users', {
      'username': username,
      'password': _hash(password),
      'role': 'DELIVERY_AGENT',
      'active': 1,
    });
  }

  Future<void> toggleActive(int id, bool active) async {
    await _db.update(
      'users',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLocation(int driverId, double lat, double lng) async {
    await _db.insert(
      'driver_locations',
      {
        'driver_id': driverId,
        'lat': lat,
        'lng': lng,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
