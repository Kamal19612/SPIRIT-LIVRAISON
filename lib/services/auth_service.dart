import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/local_database.dart';
import '../models/user_model.dart';
import 'store_api_bridge.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage();

  String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  Future<UserModel> login(String username, String password) async {
    final rows = await LocalDatabase.instance.db.query(
      'users',
      where: 'username = ? AND active = 1',
      whereArgs: [username],
    );

    if (rows.isEmpty) throw Exception('Identifiants incorrects');

    final row  = rows.first;
    final hash = row['password'] as String;

    if (_hash(password) != hash) {
      throw Exception('Identifiants incorrects');
    }

    final role = row['role'] as String;
    if (!['DELIVERY_AGENT', 'ADMIN', 'SUPER_ADMIN'].contains(role)) {
      throw Exception('Accès réservé aux livreurs');
    }

    final user = UserModel(
      id:       row['id'] as int,
      username: row['username'] as String,
      role:     role,
    );

    await _storage.write(key: 'user_id',  value: user.id.toString());
    await _storage.write(key: 'username', value: user.username);
    await _storage.write(key: 'role',     value: user.role);

    if (role == 'DELIVERY_AGENT') {
      try {
        await StoreApiBridge.instance.loginWithCredentials(username, password);
      } catch (_) {
        await StoreApiBridge.instance.clearSession();
      }
    } else {
      await StoreApiBridge.instance.clearSession();
    }

    return user;
  }

  Future<void> logout() async {
    await StoreApiBridge.instance.clearSession();
    await _storage.deleteAll();
  }

  Future<UserModel?> tryRestoreSession() async {
    final idStr = await _storage.read(key: 'user_id');
    if (idStr == null || idStr.isEmpty) return null;

    final username = await _storage.read(key: 'username') ?? '';
    final role     = await _storage.read(key: 'role')     ?? '';
    final id       = int.tryParse(idStr);
    if (id == null) return null;

    return UserModel(id: id, username: username, role: role);
  }

  Future<int?> getCurrentUserId() async {
    final idStr = await _storage.read(key: 'user_id');
    return idStr != null ? int.tryParse(idStr) : null;
  }
}
