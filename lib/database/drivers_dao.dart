import 'dart:convert';
import 'dart:io';

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
        firstName: row['first_name'] as String?,
        lastName: row['last_name'] as String?,
        phone: row['phone'] as String?,
        cnibImagePath: row['cnib_image_path'] as String?,
        cnibOcrText: row['cnib_ocr_text'] as String?,
        cnibNationalId: row['cnib_national_id'] as String?,
        cnibSerial: row['cnib_serial'] as String?,
        birthDate: row['birth_date'] as String?,
        birthPlace: row['birth_place'] as String?,
        gender: row['gender'] as String?,
        profession: row['profession'] as String?,
        cnibIssueDate: row['cnib_issue_date'] as String?,
        cnibExpiryDate: row['cnib_expiry_date'] as String?,
      );

  static const _driverSelect = '''
      u.id, u.username, u.role, u.active, u.fcm_token,
      u.first_name, u.last_name, u.phone, u.cnib_image_path, u.cnib_ocr_text,
      u.cnib_national_id, u.cnib_serial, u.birth_date, u.birth_place,
      u.gender, u.profession, u.cnib_issue_date, u.cnib_expiry_date,
      dl.lat, dl.lng
  ''';

  // ── Lecture ────────────────────────────────────────────────────────────────

  Future<List<UserModel>> getAllDrivers() async {
    final rows = await _db.rawQuery('''
      SELECT $_driverSelect
      FROM users u
      LEFT JOIN driver_locations dl ON dl.driver_id = u.id
      WHERE u.role = 'DELIVERY_AGENT'
      ORDER BY u.username ASC
    ''');
    return rows.map(_fromRow).toList();
  }

  Future<UserModel?> getDriverById(int id) async {
    final rows = await _db.rawQuery('''
      SELECT $_driverSelect
      FROM users u
      LEFT JOIN driver_locations dl ON dl.driver_id = u.id
      WHERE u.id = ? AND u.role = 'DELIVERY_AGENT'
    ''', [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Livreurs actifs avec une position connue (pour l'assignation)
  Future<List<UserModel>> getActiveDriversWithLocation() async {
    final rows = await _db.rawQuery('''
      SELECT $_driverSelect
      FROM users u
      INNER JOIN driver_locations dl ON dl.driver_id = u.id
      WHERE u.role = 'DELIVERY_AGENT' AND u.active = 1
    ''');
    return rows.map(_fromRow).toList();
  }

  Future<String> _uniqueUsername(String base) async {
    var u = base;
    var n = 0;
    while (true) {
      final rows = await _db.query('users', where: 'username = ?', whereArgs: [u]);
      if (rows.isEmpty) return u;
      n++;
      u = '${base}_$n';
    }
  }

  /// [phone] sert de base au nom d'utilisateur de connexion (chiffres conservés).
  static String usernameFromPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'livreur';
    return 'u$digits';
  }

  // ── Écriture ───────────────────────────────────────────────────────────────

  /// Retourne le nom d’utilisateur de connexion généré.
  Future<String> createDriver({
    required String lastName,
    required String firstName,
    required String phone,
    required String password,
    String? cnibImagePath,
    String? cnibOcrText,
    String? cnibNationalId,
    String? cnibSerial,
    String? birthDate,
    String? birthPlace,
    String? gender,
    String? profession,
    String? cnibIssueDate,
    String? cnibExpiryDate,
  }) async {
    final username = await _uniqueUsername(usernameFromPhone(phone));
    await _db.insert('users', {
      'username': username,
      'password': _hash(password),
      'role': 'DELIVERY_AGENT',
      'active': 1,
      'last_name': lastName.trim(),
      'first_name': firstName.trim(),
      'phone': phone.trim(),
      'cnib_image_path': cnibImagePath,
      'cnib_ocr_text': cnibOcrText,
      'cnib_national_id': _nullIfEmpty(cnibNationalId),
      'cnib_serial': _nullIfEmpty(cnibSerial),
      'birth_date': _nullIfEmpty(birthDate),
      'birth_place': _nullIfEmpty(birthPlace),
      'gender': _nullIfEmpty(gender),
      'profession': _nullIfEmpty(profession),
      'cnib_issue_date': _nullIfEmpty(cnibIssueDate),
      'cnib_expiry_date': _nullIfEmpty(cnibExpiryDate),
    });
    return username;
  }

  static String? _nullIfEmpty(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  Future<void> toggleActive(int id, bool active) async {
    await _db.update(
      'users',
      {'active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDriver(int id) async {
    final rows = await _db.query(
      'users',
      columns: ['cnib_image_path'],
      where: 'id = ? AND role = ?',
      whereArgs: [id, 'DELIVERY_AGENT'],
    );
    if (rows.isEmpty) return;

    final path = rows.first['cnib_image_path'] as String?;
    if (path != null && path.isNotEmpty) {
      try {
        await File(path).delete();
      } catch (_) {}
    }

    await _db.delete('order_assignments', where: 'driverId = ?', whereArgs: [id]);
    await _db.rawUpdate(
      'UPDATE orders SET deliveryAgentId = NULL WHERE deliveryAgentId = ?',
      [id],
    );
    await _db.delete('driver_locations', where: 'driver_id = ?', whereArgs: [id]);
    await _db.delete(
      'users',
      where: 'id = ? AND role = ?',
      whereArgs: [id, 'DELIVERY_AGENT'],
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
