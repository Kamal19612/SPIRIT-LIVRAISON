import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/app_config_dao.dart';
import '../database/local_database.dart';
import '../models/user_model.dart';
import '../utils/url_normalize.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage();
  static const _jwtKey = 'store_api_jwt';
  static const _userKey = 'store_api_user_json';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  Future<String?> _apiOrigin() async {
    final raw = await AppConfigDao.instance.getValue('store_api_origin');
    final origin = normalizeBackendOrigin(raw ?? '');
    if (origin == null || origin.trim().isEmpty) return null;
    return origin;
  }

  Future<void> logout() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _userKey);
  }

  Future<UserModel?> tryRestoreSession() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = (map['id'] as num?)?.toInt() ?? 0;
      final username = map['username']?.toString() ?? '';
      final role = map['role']?.toString() ?? 'DELIVERY_AGENT';
      if (id <= 0 || username.isEmpty) return null;
      return UserModel(id: id, username: username, role: role);
    } catch (_) {
      return null;
    }
  }

  Future<int?> getCurrentUserId() async {
    final u = await tryRestoreSession();
    return u?.id;
  }

  Future<UserModel> login(String usernameOrEmail, String password) async {
    final origin = "https://spdelivery.socialracine.com";

    // Sans URL boutique : authentification SQLite uniquement (comptes créés depuis l’admin app).
    if (origin == null || origin.isEmpty) {
      final localUser = await LocalDatabase.instance.authenticateLocalUser(
        usernameOrEmail.trim(),
        password,
      );
      if (localUser == null) {
        throw Exception(
          'Identifiants incorrects ou aucun compte local. Sans URL API boutique, seuls les '
          'utilisateurs enregistrés dans l’app (écran Admin) peuvent se connecter. Sinon, '
          'renseignez l’URL du backend Spring (clé store_api_origin) pour utiliser '
          'POST /api/auth/login.',
        );
      }
      await _storage.delete(key: _jwtKey);
      await _storage.write(
        key: _userKey,
        value: jsonEncode({
          'id': localUser.id,
          'username': localUser.username,
          'role': localUser.role,
        }),
      );
      return localUser;
    }

    final res = await _dio.post<dynamic>(
      '$origin/api/auth/login',
      data: {'username': usernameOrEmail.trim(), 'password': password},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Accept': 'application/json'},
      ),
    );

    if ((res.statusCode ?? 0) < 200 || (res.statusCode ?? 0) >= 300 || res.data is! Map) {
      throw Exception(_errorMessage(res, fallback: 'Erreur de connexion'));
    }

    final map = Map<String, dynamic>.from(res.data as Map);
    final token = map['token']?.toString() ?? '';
    if (token.isEmpty) throw Exception('Token absent.');

    // roles: ["ROLE_ADMIN", ...]
    final roles = map['roles'];
    final roleStr = roles is List ? roles.join(' ') : (roles?.toString() ?? '');

    final isDelivery = roleStr.contains('ROLE_DELIVERY_AGENT') || map['role']?.toString() == 'livreur';
    final isAdmin = roleStr.contains('ROLE_ADMIN') ||
        roleStr.contains('ROLE_SUPER_ADMIN') ||
        roleStr.contains('ROLE_MANAGER') ||
        map['role']?.toString() == 'admin';

    if (!isDelivery && !isAdmin) {
      throw Exception('Compte sans accès livraison/admin.');
    }

    final effectiveRole = isDelivery ? 'DELIVERY_AGENT' : 'ADMIN';
    final id = (map['livreurId'] as num?)?.toInt() ?? (map['userId'] as num?)?.toInt() ?? 0;
    final nom = map['nom']?.toString();
    final display = (nom != null && nom.trim().isNotEmpty) ? nom.trim() : usernameOrEmail.trim();

    final user = UserModel(id: id > 0 ? id : 1, username: display, role: effectiveRole);

    await _storage.write(key: _jwtKey, value: token);
    await _storage.write(
      key: _userKey,
      value: jsonEncode({'id': user.id, 'username': user.username, 'role': user.role}),
    );
    return user;
  }

  String _errorMessage(Response<dynamic> res, {required String fallback}) {
    final data = res.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is String && data.isNotEmpty) return data;
    return '$fallback (${res.statusCode ?? 0})';
  }
}
