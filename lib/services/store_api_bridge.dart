import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/app_config_dao.dart';
import '../models/order_model.dart';
import '../utils/url_normalize.dart';

/// Synchronisation des actions livreur avec l’API Sucre Store (Spring).
///
/// Exige [AppConfigDao] `store_api_origin` + `store_source_platform`, et un JWT
/// obtenu via [loginWithCredentials] (appelé après connexion locale si les
/// identifiants correspondent au compte livreur côté boutique).
class StoreApiBridge {
  StoreApiBridge._();
  static final StoreApiBridge instance = StoreApiBridge._();

  static const _jwtKey = 'store_api_jwt';

  final _storage = const FlutterSecureStorage();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  /// Origine API sans slash final (ex. `https://boutique.com:8081`).
  Future<String?> get apiOrigin async {
    final v = await AppConfigDao.instance.getValue('store_api_origin');
    if (v == null || v.trim().isEmpty) return null;
    return normalizeStoreApiOrigin(v);
  }

  /// Plateforme [Order.sourcePlatform] pour laquelle on appelle l’API STORE.
  Future<String?> get sourcePlatformFilter async {
    final v = await AppConfigDao.instance.getValue('store_source_platform');
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  Future<String?> get jwt async => _storage.read(key: _jwtKey);

  Future<bool> get isRemoteConfigured async {
    final o = await apiOrigin;
    final p = await sourcePlatformFilter;
    final t = await jwt;
    return o != null &&
        o.isNotEmpty &&
        p != null &&
        p.isNotEmpty &&
        t != null &&
        t.isNotEmpty;
  }

  /// Commande issue de la boutique configurée (évite d’appeler l’API avec un id tiers).
  Future<bool> shouldSyncOrder(Order order) async {
    if (!await isRemoteConfigured) return false;
    final want = await sourcePlatformFilter;
    if (want == null || want.isEmpty) return false;
    return order.sourcePlatform == want;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _jwtKey);
  }

  /// Connexion `POST /api/auth/login` — mot de passe en clair (comme le STORE).
  Future<void> loginWithCredentials(String username, String password) async {
    final origin = await apiOrigin;
    if (origin == null || origin.isEmpty) {
      await clearSession();
      return;
    }
    final url = '$origin/api/auth/login';
    try {
      final res = await _dio.post<dynamic>(
        url,
        data: {'username': username, 'password': password},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {'Accept': 'application/json'},
        ),
      );
      if (res.statusCode != 200 || res.data is! Map) {
        await clearSession();
        return;
      }
      final map = Map<String, dynamic>.from(res.data as Map);
      final token = map['token'] as String?;
      if (token == null || token.isEmpty) {
        await clearSession();
        return;
      }
      final roles = map['roles'];
      final roleStr = roles is List ? roles.join(' ') : roles?.toString() ?? '';
      if (!roleStr.contains('DELIVERY_AGENT') &&
          !roleStr.contains('ADMIN') &&
          !roleStr.contains('SUPER_ADMIN')) {
        await clearSession();
        throw Exception(
          'Ce compte boutique n’a pas le rôle livreur ou admin.',
        );
      }
      await _storage.write(key: _jwtKey, value: token);
    } on DioException catch (e) {
      await clearSession();
      final msg = _messageFromDio(e);
      if (msg != null) {
        throw Exception(msg);
      }
      rethrow;
    }
  }

  Future<void> claimDeliveryOrder(int storeOrderId) async {
    final origin = await apiOrigin;
    final token = await jwt;
    if (origin == null || token == null) {
      throw Exception('API boutique non configurée ou session absente.');
    }
    final url = '$origin/api/delivery/orders/$storeOrderId/claim';
    final res = await _dio.put<dynamic>(
      url,
      options: Options(headers: _authHeaders(token)),
    );
    _ensure2xx(res, 'Prise en charge');
  }

  Future<void> completeDeliveryOnStore(int storeOrderId, String code) async {
    final origin = await apiOrigin;
    final token = await jwt;
    if (origin == null || token == null) {
      throw Exception('API boutique non configurée ou session absente.');
    }
    final url = '$origin/api/delivery/orders/$storeOrderId/complete';
    final res = await _dio.post<dynamic>(
      url,
      data: {'code': code.trim()},
      options: Options(headers: _authHeaders(token)),
    );
    _ensure2xx(res, 'Validation livraison');
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
}

/// Origine boutique sans slash final (les chemins d’appel incluent `/api/...`).
///
/// Réutilise [normalizeHttpOrigin] pour corriger les espaces parasites dans les URLs collées.
String? normalizeStoreApiOrigin(String raw) => normalizeHttpOrigin(raw);
