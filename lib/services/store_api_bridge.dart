import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/backends_dao.dart';
import '../models/backend_server_model.dart';
import '../models/order_model.dart';
import '../utils/url_normalize.dart';

class BackendLoginResult {
  final String token;
  final bool isDelivery;
  final bool isAdmin;
  final int userId;
  final String displayName;

  const BackendLoginResult({
    required this.token,
    required this.isDelivery,
    required this.isAdmin,
    required this.userId,
    required this.displayName,
  });

  String get effectiveRole => isDelivery ? 'DELIVERY_AGENT' : 'ADMIN';
}

/// Client API multi-backend (STORE-ALL / Spring compatible).
class StoreApiBridge {
  StoreApiBridge._();
  static final StoreApiBridge instance = StoreApiBridge._();

  static const _authBackendIdsKey = 'auth_backend_ids';

  final _storage = const FlutterSecureStorage();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  Dio get dio => _dio;

  String _jwtKey(int backendId) => 'backend_jwt_$backendId';

  Future<List<int>> getAuthenticatedBackendIds() async {
    final raw = await _storage.read(key: _authBackendIdsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.map((e) => (e as num).toInt()).where((id) => id > 0).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<BackendServer>> getAuthenticatedBackends() async {
    final ids = await getAuthenticatedBackendIds();
    return BackendsDao.instance.getByIds(ids);
  }

  Future<void> setAuthenticatedBackendIds(List<int> ids) async {
    final unique = ids.toSet().toList()..sort();
    if (unique.isEmpty) {
      await _storage.delete(key: _authBackendIdsKey);
      return;
    }
    await _storage.write(key: _authBackendIdsKey, value: jsonEncode(unique));
  }

  Future<String?> getJwt(int backendId) => _storage.read(key: _jwtKey(backendId));

  Future<void> saveJwt(int backendId, String token) async {
    await _storage.write(key: _jwtKey(backendId), value: token);
  }

  Future<void> clearBackendSession(int backendId) async {
    await _storage.delete(key: _jwtKey(backendId));
  }

  Future<void> clearAllSessions() async {
    final ids = await getAuthenticatedBackendIds();
    for (final id in ids) {
      await clearBackendSession(id);
    }
    await _storage.delete(key: _authBackendIdsKey);
    // Ancienne clé mono-backend
    await _storage.delete(key: 'store_api_jwt');
  }

  /// Connexion `POST /api/auth/login` sur un backend donné.
  Future<BackendLoginResult> loginOnBackend({
    required BackendServer backend,
    required String username,
    required String password,
  }) async {
    final url = '${backend.origin}/api/auth/login';
    try {
      final res = await _dio.post<dynamic>(
        url,
        data: {'username': username.trim(), 'password': password},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {'Accept': 'application/json'},
        ),
      );

      if (res.statusCode == 401 || res.statusCode == 403) {
        throw Exception('Identifiants refusés sur ${backend.name}.');
      }
      if ((res.statusCode ?? 0) < 200 ||
          (res.statusCode ?? 0) >= 300 ||
          res.data is! Map) {
        throw Exception(_errorMessage(res, fallback: 'Erreur sur ${backend.name}'));
      }

      final map = Map<String, dynamic>.from(res.data as Map);
      final token = map['token']?.toString() ?? '';
      if (token.isEmpty) throw Exception('Token absent (${backend.name}).');

      final roles = map['roles'];
      final roleStr = roles is List ? roles.join(' ') : (roles?.toString() ?? '');
      final isDelivery = roleStr.contains('ROLE_DELIVERY_AGENT') ||
          roleStr.contains('DELIVERY_AGENT') ||
          map['role']?.toString() == 'livreur';
      final isAdmin = roleStr.contains('ROLE_ADMIN') ||
          roleStr.contains('ROLE_SUPER_ADMIN') ||
          roleStr.contains('ROLE_MANAGER') ||
          roleStr.contains('ADMIN') ||
          roleStr.contains('MANAGER') ||
          map['role']?.toString() == 'admin';

      if (!isDelivery && !isAdmin) {
        throw Exception('Compte sans accès livraison/admin sur ${backend.name}.');
      }

      final id = (map['livreurId'] as num?)?.toInt() ??
          (map['userId'] as num?)?.toInt() ??
          0;
      final nom = map['nom']?.toString();
      final display = (nom != null && nom.trim().isNotEmpty)
          ? nom.trim()
          : username.trim();

      await saveJwt(backend.id!, token);
      return BackendLoginResult(
        token: token,
        isDelivery: isDelivery,
        isAdmin: isAdmin,
        userId: id > 0 ? id : 1,
        displayName: display,
      );
    } on DioException catch (e) {
      final msg = _messageFromDio(e);
      throw Exception(msg ?? 'Serveur injoignable (${backend.name}).');
    }
  }

  Future<Order> claimDeliveryOrder({
    required BackendServer backend,
    required int storeOrderId,
  }) async {
    final token = await getJwt(backend.id!);
    if (token == null) {
      throw Exception('Session absente pour ${backend.name}.');
    }
    final url = '${backend.origin}/api/delivery/orders/$storeOrderId/claim';
    final res = await _dio.put<dynamic>(
      url,
      options: Options(headers: _authHeaders(token)),
    );
    _ensure2xx(res, 'Prise en charge');
    if (res.data is Map) {
      return Order.fromJson(
        Map<String, dynamic>.from(res.data as Map),
        backendId: backend.id,
        backendName: backend.name,
      );
    }
    throw Exception('Réponse prise en charge invalide');
  }

  Future<void> completeDeliveryOnStore({
    required BackendServer backend,
    required int storeOrderId,
    required String code,
  }) async {
    final token = await getJwt(backend.id!);
    if (token == null) {
      throw Exception('Session absente pour ${backend.name}.');
    }
    final url = '${backend.origin}/api/delivery/orders/$storeOrderId/complete';
    final res = await _dio.post<dynamic>(
      url,
      data: {'code': code.trim()},
      options: Options(headers: _authHeaders(token)),
    );
    _ensure2xx(res, 'Validation livraison');
  }

  Future<void> registerFcmToken({
    required BackendServer backend,
    required String token,
    required String platform,
  }) async {
    final jwtToken = await getJwt(backend.id!);
    if (jwtToken == null) return;

    const paths = <String>[
      '/api/delivery/devices/register',
      '/api/webhooks/livraison/inscription',
    ];
    Object? lastError;
    for (final path in paths) {
      final url = '${backend.origin}$path';
      try {
        final res = await _dio.post<dynamic>(
          url,
          data: {'token': token, 'platform': platform},
          options: Options(headers: _authHeaders(jwtToken)),
        );
        if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
          return;
        }
        lastError = res.data;
      } on DioException catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) {
      throw Exception('Enregistrement FCM (${backend.name}): $lastError');
    }
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  void _ensure2xx(Response<dynamic> res, String action) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    String msg = '$action refusée ($code)';
    final data = res.data;
    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    } else if (data is String && data.isNotEmpty) {
      msg = data;
    }
    throw Exception(msg);
  }

  String? _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (e.message != null && e.message!.isNotEmpty) return e.message;
    return null;
  }

  String _errorMessage(Response<dynamic> res, {required String fallback}) {
    final data = res.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is String && data.isNotEmpty) return data;
    return '$fallback (${res.statusCode ?? 0})';
  }
}

String? normalizeStoreApiOrigin(String raw) => normalizeBackendOrigin(raw);
