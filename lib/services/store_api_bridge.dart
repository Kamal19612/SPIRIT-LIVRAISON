import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/backends_dao.dart';
import '../models/backend_server_model.dart';
import '../models/backend_session_info.dart';
import '../models/order_model.dart';
import '../utils/url_normalize.dart';

class BackendLoginResult {
  final String token;
  final bool isDelivery;
  final bool isAdmin;
  final bool isSuperAdmin;
  final int? storeId;
  final int userId;
  final String displayName;

  const BackendLoginResult({
    required this.token,
    required this.isDelivery,
    required this.isAdmin,
    this.isSuperAdmin = false,
    this.storeId,
    required this.userId,
    required this.displayName,
  });

  String get effectiveRole {
    if (isDelivery) return 'DELIVERY_AGENT';
    if (isSuperAdmin) return 'SUPER_ADMIN';
    return 'ADMIN';
  }

  BackendSessionInfo get sessionInfo => BackendSessionInfo(
        storeId: storeId,
        isSuperAdmin: isSuperAdmin,
      );
}

/// Client API multi-backend (STORE-ALL / Spring compatible).
class StoreApiBridge {
  StoreApiBridge._() {
    _installAuthInterceptor();
  }
  static final StoreApiBridge instance = StoreApiBridge._();

  static const _authBackendIdsKey = 'auth_backend_ids';
  /// Canal JWT distinct du web admin STORE-ALL (sessions parallèles).
  static const storeAllClientType = 'mobile';

  final _storage = const FlutterSecureStorage();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  bool _sessionInvalidationHandling = false;
  Future<void> Function()? onSessionInvalidated;

  void resetSessionInvalidationGuard() {
    _sessionInvalidationHandling = false;
  }

  Dio get dio => _dio;

  void _installAuthInterceptor() {
    _dio.interceptors.removeWhere((i) => i is InterceptorsWrapper);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          final code = response.statusCode ?? 0;
          final path = response.requestOptions.path;
          if (code == 401 &&
              !path.contains('/api/auth/login') &&
              response.requestOptions.headers['Authorization'] != null) {
            unawaited(_notifySessionInvalidated());
          }
          handler.next(response);
        },
      ),
    );
  }

  Future<void> _notifySessionInvalidated() async {
    if (_sessionInvalidationHandling) return;
    _sessionInvalidationHandling = true;
    await onSessionInvalidated?.call();
  }

  String _jwtKey(int backendId) => 'backend_jwt_$backendId';
  String _sessionKey(int backendId) => 'backend_session_$backendId';

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

  /// Session JWT active pour une origine (évite un login de test qui invalide le token).
  Future<bool> hasActiveSessionForOrigin(String rawOrigin) async {
    final jwt = await getJwtForOrigin(rawOrigin);
    return jwt != null && jwt.isNotEmpty;
  }

  Future<String?> getJwtForOrigin(String rawOrigin) async {
    final normalized = normalizeBackendOrigin(rawOrigin);
    if (normalized == null) return null;
    final backends = await getAuthenticatedBackends();
    for (final backend in backends) {
      if (backend.id == null) continue;
      final origin = normalizeBackendOrigin(backend.origin) ?? backend.origin;
      if (origin != normalized) continue;
      final jwt = await getJwt(backend.id!);
      if (jwt != null && jwt.isNotEmpty) return jwt;
    }
    return null;
  }

  Future<BackendServer?> getAuthenticatedBackendForOrigin(String rawOrigin) async {
    final normalized = normalizeBackendOrigin(rawOrigin);
    if (normalized == null) return null;
    final backends = await getAuthenticatedBackends();
    for (final backend in backends) {
      if (backend.id == null) continue;
      final origin = normalizeBackendOrigin(backend.origin) ?? backend.origin;
      if (origin == normalized) return backend;
    }
    return null;
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

  Future<void> saveBackendSession(int backendId, BackendSessionInfo session) async {
    await _storage.write(
      key: _sessionKey(backendId),
      value: jsonEncode(session.toJson()),
    );
  }

  Future<BackendSessionInfo?> getBackendSession(int backendId) async {
    final raw = await _storage.read(key: _sessionKey(backendId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return BackendSessionInfo.fromJson(Map<String, dynamic>.from(map));
    } catch (_) {
      return null;
    }
  }

  /// Résout la session admin (cache ou sonde `/api/super/orders` pour anciennes sessions).
  Future<BackendSessionInfo> resolveAdminSession({
    required int backendId,
    required BackendServer backend,
    required String token,
  }) async {
    final cached = await getBackendSession(backendId);
    if (cached != null && cached.canFetchAdminOrders) return cached;

    final probeUrl = '${backend.origin}/api/super/orders?size=1';
    try {
      final res = await _dio.get<dynamic>(
        probeUrl,
        options: Options(headers: _authHeaders(token)),
      );
      if ((res.statusCode ?? 0) == 200) {
        const session = BackendSessionInfo(isSuperAdmin: true);
        await saveBackendSession(backendId, session);
        return session;
      }
    } catch (_) {}

    return cached ?? const BackendSessionInfo();
  }

  /// Identifiant boutique pour les routes `/api/manager/{storeId}/...` (par serveur).
  Future<int?> resolveManagerStoreId({
    required int backendId,
    required BackendServer backend,
    required String token,
    BackendSessionInfo? session,
  }) async {
    final configured = backend.managerStoreId;
    if (configured != null && configured > 0) return configured;

    final sess = session ??
        await resolveAdminSession(
          backendId: backendId,
          backend: backend,
          token: token,
        );
    final fromSession = sess.storeId;
    if (fromSession != null && fromSession > 0) return fromSession;
    if (!sess.isSuperAdmin) return null;
    return _resolveSuperStoreId(backend: backend, token: token);
  }

  Future<int?> _resolveSuperStoreId({
    required BackendServer backend,
    required String token,
  }) async {
    final url = '${backend.origin}/api/super/stores';
    try {
      final res = await _dio.get<dynamic>(
        url,
        options: Options(headers: _authHeaders(token)),
      );
      if ((res.statusCode ?? 0) != 200) return null;
      final data = res.data;
      if (data is! List || data.isEmpty) return null;

      final code = backend.storeCode.trim().toLowerCase();
      if (code.isNotEmpty) {
        for (final item in data) {
          if (item is! Map) continue;
          final itemCode = item['code']?.toString().trim().toLowerCase() ?? '';
          if (itemCode == code) {
            return (item['id'] as num?)?.toInt();
          }
        }
      }

      final first = data.first;
      if (first is! Map) return null;
      return (first['id'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearBackendSession(int backendId) async {
    await _storage.delete(key: _jwtKey(backendId));
    await _storage.delete(key: _sessionKey(backendId));
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
        data: {
          'username': username.trim(),
          'password': password,
          'clientType': storeAllClientType,
        },
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
      final isSuperAdmin = roleStr.contains('ROLE_SUPER_ADMIN');
      final isAdmin = isSuperAdmin ||
          roleStr.contains('ROLE_ADMIN') ||
          roleStr.contains('ROLE_MANAGER') ||
          roleStr.contains('ADMIN') ||
          roleStr.contains('MANAGER') ||
          map['role']?.toString() == 'admin';

      if (!isDelivery && !isAdmin) {
        throw Exception('Compte sans accès livraison/admin sur ${backend.name}.');
      }

      final storeId = (map['storeId'] as num?)?.toInt();
      final id = (map['livreurId'] as num?)?.toInt() ??
          (map['userId'] as num?)?.toInt() ??
          0;
      final nom = map['nom']?.toString();
      final display = (nom != null && nom.trim().isNotEmpty)
          ? nom.trim()
          : username.trim();

      resetSessionInvalidationGuard();
      await saveJwt(backend.id!, token);
      await saveBackendSession(backend.id!, BackendSessionInfo(
        storeId: storeId,
        isSuperAdmin: isSuperAdmin,
      ));
      return BackendLoginResult(
        token: token,
        isDelivery: isDelivery,
        isAdmin: isAdmin,
        isSuperAdmin: isSuperAdmin,
        storeId: storeId,
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
