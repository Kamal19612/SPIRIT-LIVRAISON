import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/backends_dao.dart';
import '../database/local_database.dart';
import '../models/backend_login_status.dart';
import '../models/backend_server_model.dart';
import '../models/user_model.dart';
import 'store_api_bridge.dart';

class AuthLoginResult {
  final UserModel user;
  final List<BackendServer> authenticatedBackends;
  final List<BackendLoginFailure> failedBackends;

  const AuthLoginResult({
    required this.user,
    required this.authenticatedBackends,
    this.failedBackends = const [],
  });

  BackendLoginStatus get backendStatus => BackendLoginStatus(
        connected: authenticatedBackends,
        failed: failedBackends,
      );
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _storage = const FlutterSecureStorage();
  static const _userKey = 'store_api_user_json';

  Future<void> logout() async {
    await StoreApiBridge.instance.clearAllSessions();
    await _storage.delete(key: _userKey);
  }

  Future<List<BackendServer>> getAuthenticatedBackends() =>
      StoreApiBridge.instance.getAuthenticatedBackends();

  Future<List<BackendServer>> getConfiguredBackends({bool activeOnly = true}) =>
      BackendsDao.instance.getAll(activeOnly: activeOnly);

  Future<UserModel?> tryRestoreSession() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = (map['id'] as num?)?.toInt() ?? 0;
      final username = map['username']?.toString() ?? '';
      final role = map['role']?.toString() ?? 'DELIVERY_AGENT';
      if (id <= 0 || username.isEmpty) return null;

      final backends = await StoreApiBridge.instance.getAuthenticatedBackends();
      final isLocalOnly = map['localOnly'] == true;
      if (!isLocalOnly && backends.isEmpty) return null;

      return UserModel(id: id, username: username, role: role);
    } catch (_) {
      return null;
    }
  }

  Future<int?> getCurrentUserId() async {
    final u = await tryRestoreSession();
    return u?.id;
  }

  Future<UserModel> _persistLocalSession(UserModel localUser) async {
    await StoreApiBridge.instance.clearAllSessions();
    await _storage.write(
      key: _userKey,
      value: jsonEncode({
        'id': localUser.id,
        'username': localUser.username,
        'role': localUser.role,
        'localOnly': true,
      }),
    );
    return localUser;
  }

  Future<UserModel?> _tryLocalLogin(String usernameOrEmail, String password) async {
    await LocalDatabase.instance.ensureDefaultLocalAdmin();
    return LocalDatabase.instance.authenticateLocalUser(
      usernameOrEmail.trim(),
      password,
    );
  }

  Future<AuthLoginResult> login(String usernameOrEmail, String password) async {
    final backends = await BackendsDao.instance.getAll(activeOnly: true);

    if (backends.isEmpty) {
      final localUser = await _tryLocalLogin(usernameOrEmail, password);
      if (localUser == null) {
        throw Exception('Identifiants incorrects.');
      }
      final user = await _persistLocalSession(localUser);
      return AuthLoginResult(user: user, authenticatedBackends: const []);
    }

    await StoreApiBridge.instance.clearAllSessions();

    final successes = <BackendServer>[];
    final failures = <BackendLoginFailure>[];
    BackendLoginResult? primaryLogin;
    String? lastError;

    for (final backend in backends) {
      if (backend.id == null) continue;
      try {
        final result = await StoreApiBridge.instance.loginOnBackend(
          backend: backend,
          username: usernameOrEmail,
          password: password,
        );
        successes.add(backend);
        primaryLogin ??= result;
      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        lastError = msg;
        failures.add(BackendLoginFailure(backend: backend, message: msg));
      }
    }

    if (successes.isEmpty || primaryLogin == null) {
      final localUser = await _tryLocalLogin(usernameOrEmail, password);
      if (localUser != null) {
        final user = await _persistLocalSession(localUser);
        return AuthLoginResult(user: user, authenticatedBackends: const []);
      }
      throw Exception(lastError ?? 'Identifiants incorrects.');
    }

    await StoreApiBridge.instance.setAuthenticatedBackendIds(
      successes.map((b) => b.id!).toList(),
    );

    final user = UserModel(
      id: primaryLogin.userId,
      username: primaryLogin.displayName,
      role: primaryLogin.effectiveRole,
    );

    await _storage.write(
      key: _userKey,
      value: jsonEncode({
        'id': user.id,
        'username': user.username,
        'role': user.role,
        'localOnly': false,
        'backendCount': successes.length,
      }),
    );

    return AuthLoginResult(
      user: user,
      authenticatedBackends: successes,
      failedBackends: failures,
    );
  }
}
