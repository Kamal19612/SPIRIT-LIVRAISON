import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../database/drivers_dao.dart';
import '../models/backend_server_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'backend_admin_api.dart';
import 'store_api_bridge.dart';

class AdminUserService {
  AdminUserService._();
  static final AdminUserService instance = AdminUserService._();

  Future<List<BackendServer>> _sessionBackends() =>
      StoreApiBridge.instance.getAuthenticatedBackends();

  Future<bool> _useStoreApi() async {
    final u = await AuthService.instance.tryRestoreSession();
    if (u == null || !u.isAdmin) return false;
    final backends = await _sessionBackends();
    return backends.isNotEmpty;
  }

  void _log(String method, String url, int? status, String detail) {
    if (!kDebugMode) return;
    debugPrint('[StoreAPI] $method $url → ${status ?? '?'} $detail');
  }

  String? _errorMessage(Response<dynamic> res, {required String fallback}) {
    final data = res.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is String && data.isNotEmpty) return data;
    return '$fallback (${res.statusCode ?? 0})';
  }

  List<UserModel> _parseDrivers(dynamic data, {required BackendServer backend}) {
    if (data is! List) return [];
    final out = <UserModel>[];
    for (final item in data) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final role = map['role']?.toString() ?? '';
      if (role != 'DELIVERY_AGENT') continue;
      final user = UserModel.fromStoreApi(
        map,
        backendId: backend.id!,
        backendName: backend.name,
      );
      if (user.id > 0 && user.username.isNotEmpty) {
        out.add(user);
      }
    }
    out.sort((a, b) => a.username.compareTo(b.username));
    return out;
  }

  Future<({List<UserModel> drivers, String? error})> _fetchDriversOnBackend(
    BackendServer backend,
  ) async {
    final id = backend.id;
    if (id == null) return (drivers: <UserModel>[], error: 'Serveur invalide.');

    final token = await StoreApiBridge.instance.getJwt(id);
    if (token == null) {
      return (drivers: <UserModel>[], error: 'Session expirée sur ${backend.name}.');
    }

    final session = await StoreApiBridge.instance.resolveAdminSession(
      backendId: id,
      backend: backend,
      token: token,
    );
    final storeId = await StoreApiBridge.instance.resolveManagerStoreId(
      backendId: id,
      backend: backend,
      token: token,
      session: session,
    );
    if (storeId == null) {
      return (
        drivers: <UserModel>[],
        error: 'Boutique introuvable sur ${backend.name} (vérifiez code ou ID boutique).',
      );
    }

    final url = BackendAdminApi.adminUsersUrl(backend: backend, managerStoreId: storeId);
    try {
      final res = await StoreApiBridge.instance.dio.get<dynamic>(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        ),
      );
      final code = res.statusCode ?? 0;
      _log('GET', url, code, 'users (${backend.name})');
      if (code == 200) {
        return (drivers: _parseDrivers(res.data, backend: backend), error: null);
      }
      if (code == 401 || code == 403) {
        return (drivers: <UserModel>[], error: 'Accès utilisateurs refusé sur ${backend.name}.');
      }
      return (
        drivers: <UserModel>[],
        error: _errorMessage(res, fallback: 'Erreur sur ${backend.name}') ??
            'Erreur $code sur ${backend.name}.',
      );
    } catch (e) {
      return (drivers: <UserModel>[], error: 'Impossible de joindre ${backend.name} ($e).');
    }
  }

  Future<List<UserModel>> fetchAdminDriversForBackend(int backendId) async {
    final backends = await _sessionBackends();
    final backend = backends.where((b) => b.id == backendId).firstOrNull;
    if (backend == null) {
      throw Exception('Serveur #$backendId non connecté.');
    }
    final result = await _fetchDriversOnBackend(backend);
    if (result.error != null && result.drivers.isEmpty) {
      throw Exception(result.error);
    }
    return result.drivers;
  }

  Future<List<UserModel>> fetchAdminDrivers() async {
    final backends = await _sessionBackends();
    if (backends.isEmpty) {
      throw Exception('Aucun serveur connecté (JWT). Reconnectez-vous.');
    }

    final merged = <UserModel>[];
    var anySuccess = false;
    String? lastError;

    for (final backend in backends) {
      final result = await _fetchDriversOnBackend(backend);
      if (result.drivers.isNotEmpty) {
        anySuccess = true;
        merged.addAll(result.drivers);
      } else if (result.error != null) {
        lastError = result.error;
      } else {
        anySuccess = true;
      }
    }

    if (!anySuccess) {
      throw Exception(lastError ?? 'Impossible de charger les livreurs.');
    }
    return merged;
  }

  Future<BackendServer> _backendForDriver(UserModel driver) async {
    final backendId = driver.backendId;
    if (backendId == null) {
      throw Exception('Livreur sans serveur d’origine.');
    }
    final backends = await _sessionBackends();
    final backend = backends.where((b) => b.id == backendId).firstOrNull;
    if (backend == null) {
      throw Exception('Session expirée pour ce serveur.');
    }
    return backend;
  }

  Future<int> _managerStoreIdFor(BackendServer backend, String token) async {
    final storeId = await StoreApiBridge.instance.resolveManagerStoreId(
      backendId: backend.id!,
      backend: backend,
      token: token,
    );
    if (storeId == null) {
      throw Exception('Boutique introuvable sur ${backend.name}.');
    }
    return storeId;
  }

  String _defaultEmail(String loginId, BackendServer backend) {
    final code = backend.storeCode.trim().toLowerCase();
    final suffix = code.isNotEmpty ? code : 'store';
    return '$loginId@$suffix.livraison.local';
  }

  Map<String, dynamic> _createPayload({
    required String loginId,
    required String email,
    required String password,
    required String lastName,
    required String firstName,
    required String phone,
    String? cnibOcrText,
    String? cnibNationalId,
    String? cnibSerial,
    String? birthDate,
    String? birthPlace,
    String? gender,
    String? profession,
    String? cnibIssueDate,
    String? cnibExpiryDate,
  }) {
    final payload = <String, dynamic>{
      'username': loginId,
      'email': email,
      'password': password,
      'role': 'DELIVERY_AGENT',
      'active': true,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
    };
    void put(String key, String? value) {
      final t = value?.trim();
      if (t != null && t.isNotEmpty) payload[key] = t;
    }

    put('cnibOcrText', cnibOcrText);
    put('cnibNationalId', cnibNationalId);
    put('cnibSerial', cnibSerial);
    put('birthDate', birthDate);
    put('birthPlace', birthPlace);
    put('gender', gender);
    put('profession', profession);
    put('cnibIssueDate', cnibIssueDate);
    put('cnibExpiryDate', cnibExpiryDate);
    return payload;
  }

  Future<String> createDriver({
    required int backendId,
    required String username,
    required String lastName,
    required String firstName,
    required String phone,
    required String password,
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
    final backends = await _sessionBackends();
    final backend = backends.where((b) => b.id == backendId).firstOrNull;
    if (backend == null) {
      throw Exception('Serveur #$backendId non connecté.');
    }

    final loginId = DriversDao.normalizeLoginUsername(username);
    if (loginId.length < 3) {
      throw ArgumentError('Identifiant trop court (min. 3 caractères).');
    }

    final token = await StoreApiBridge.instance.getJwt(backend.id!);
    if (token == null) {
      throw Exception('Session expirée sur ${backend.name}.');
    }

    Object? lastError;
    try {
      final storeId = await _managerStoreIdFor(backend, token);
      final url = BackendAdminApi.adminUsersUrl(backend: backend, managerStoreId: storeId);
      final res = await StoreApiBridge.instance.dio.post<dynamic>(
        url,
        data: _createPayload(
          loginId: loginId,
          email: _defaultEmail(loginId, backend),
          password: password,
          lastName: lastName,
          firstName: firstName,
          phone: phone,
          cnibOcrText: cnibOcrText,
          cnibNationalId: cnibNationalId,
          cnibSerial: cnibSerial,
          birthDate: birthDate,
          birthPlace: birthPlace,
          gender: gender,
          profession: profession,
          cnibIssueDate: cnibIssueDate,
          cnibExpiryDate: cnibExpiryDate,
        ),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      final code = res.statusCode ?? 0;
      _log('POST', url, code, 'create driver (${backend.name})');
      if (code >= 200 && code < 300) return loginId;
      lastError = _errorMessage(res, fallback: 'Création refusée sur ${backend.name}');
    } catch (e) {
      lastError = e;
    }

    final msg = lastError?.toString().replaceFirst('Exception: ', '') ??
        'Impossible de créer le livreur sur ${backend.name}.';
    if (msg.contains('déjà') || msg.contains('already') || msg.contains('pris')) {
      throw Exception('Cet identifiant est déjà utilisé');
    }
    throw Exception(msg);
  }

  Future<void> toggleDriver(UserModel driver, bool active) async {
    final backend = await _backendForDriver(driver);
    final token = await StoreApiBridge.instance.getJwt(backend.id!);
    if (token == null) throw Exception('Session expirée sur ${backend.name}.');

    final storeId = await _managerStoreIdFor(backend, token);
    final email = driver.email ?? _defaultEmail(driver.username, backend);
    final url = BackendAdminApi.adminUserUrl(
      backend: backend,
      managerStoreId: storeId,
      userId: driver.id,
    );
    final res = await StoreApiBridge.instance.dio.put<dynamic>(
      url,
      data: {
        'username': driver.username,
        'email': email,
        'role': 'DELIVERY_AGENT',
        'active': active,
        'firstName': driver.firstName ?? '',
        'lastName': driver.lastName ?? '',
        'phone': driver.phone ?? '',
        'password': '',
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    final code = res.statusCode ?? 0;
    _log('PUT', url, code, 'toggle driver (${backend.name})');
    if (code < 200 || code >= 300) {
      throw Exception(
        _errorMessage(res, fallback: 'Mise à jour refusée') ?? 'Erreur $code',
      );
    }
  }

  Future<void> deleteDriver(UserModel driver) async {
    final backend = await _backendForDriver(driver);
    final token = await StoreApiBridge.instance.getJwt(backend.id!);
    if (token == null) throw Exception('Session expirée sur ${backend.name}.');

    final storeId = await _managerStoreIdFor(backend, token);
    final url = BackendAdminApi.adminUserUrl(
      backend: backend,
      managerStoreId: storeId,
      userId: driver.id,
    );
    final res = await StoreApiBridge.instance.dio.delete<dynamic>(
      url,
      options: Options(
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ),
    );
    final code = res.statusCode ?? 0;
    _log('DELETE', url, code, 'delete driver (${backend.name})');
    if (code < 200 || code >= 300) {
      throw Exception(
        _errorMessage(res, fallback: 'Suppression refusée') ?? 'Erreur $code',
      );
    }
  }

  Future<bool> shouldUseStoreApi() => _useStoreApi();
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
