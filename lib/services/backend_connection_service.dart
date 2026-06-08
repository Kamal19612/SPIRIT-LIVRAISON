import 'package:dio/dio.dart';

import '../models/backend_connection_test_result.dart';
import '../models/backend_server_model.dart';
import '../utils/url_normalize.dart';

/// Test de joignabilité + mini-login JWT + accès livraison (STORE-ALL).
class BackendConnectionService {
  BackendConnectionService._();
  static final BackendConnectionService instance = BackendConnectionService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  /// Diagnostic complet (API publique, login optionnel, `/api/delivery/orders`).
  Future<BackendConnectionTestResult> testFull({
    required String rawOrigin,
    String? storeCode,
    String? label,
    String? username,
    String? password,
  }) async {
    final steps = <BackendTestStep>[];

    if (rawOrigin.trim().isEmpty) {
      return BackendConnectionTestResult(steps: [
        const BackendTestStep(
          label: 'API publique',
          ok: false,
          detail: 'URL vide',
        ),
      ]);
    }

    final base = normalizeBackendOrigin(rawOrigin);
    if (base == null) {
      return BackendConnectionTestResult(steps: [
        const BackendTestStep(
          label: 'API publique',
          ok: false,
          detail: 'URL invalide (http:// ou https://, sans /api)',
        ),
      ]);
    }

    final name = label?.trim().isNotEmpty == true ? label!.trim() : base;
    steps.add(await _testPublicSettings(base, storeCode: storeCode, name: name));

    final user = username?.trim() ?? '';
    final pass = password ?? '';
    if (user.isEmpty || pass.isEmpty) {
      steps.add(const BackendTestStep(
        label: 'Login JWT',
        ok: true,
        skipped: true,
        detail: 'non testé (identifiants optionnels)',
      ));
      steps.add(const BackendTestStep(
        label: 'API livraison',
        ok: true,
        skipped: true,
        detail: 'nécessite un login JWT',
      ));
      steps.add(const BackendTestStep(
        label: 'API admin commandes',
        ok: true,
        skipped: true,
        detail: 'nécessite un login JWT',
      ));
      steps.add(const BackendTestStep(
        label: 'API admin livreurs',
        ok: true,
        skipped: true,
        detail: 'nécessite un login JWT',
      ));
      return BackendConnectionTestResult(steps: steps);
    }

    final login = await _testJwtLogin(base, user, pass);
    steps.add(login.step);

    if (!login.ok || login.token == null || login.token!.isEmpty) {
      steps.add(const BackendTestStep(
        label: 'API livraison',
        ok: false,
        skipped: true,
        detail: 'login JWT requis',
      ));
      steps.add(const BackendTestStep(
        label: 'API admin commandes',
        ok: false,
        skipped: true,
        detail: 'login JWT requis',
      ));
      steps.add(const BackendTestStep(
        label: 'API admin livreurs',
        ok: false,
        skipped: true,
        detail: 'login JWT requis',
      ));
      return BackendConnectionTestResult(steps: steps);
    }

    steps.add(await _testDeliveryOrders(base, login.token!));

    if (login.isAdmin) {
      steps.add(await _testAdminOrders(
        base,
        login.token!,
        isSuperAdmin: login.isSuperAdmin,
        storeId: login.storeId,
      ));
      steps.add(await _testAdminUsers(
        base,
        login.token!,
        isSuperAdmin: login.isSuperAdmin,
        storeId: login.storeId,
      ));
    } else {
      steps.add(const BackendTestStep(
        label: 'API admin commandes',
        ok: true,
        skipped: true,
        detail: 'compte livreur uniquement',
      ));
      steps.add(const BackendTestStep(
        label: 'API admin livreurs',
        ok: true,
        skipped: true,
        detail: 'compte livreur uniquement',
      ));
    }

    return BackendConnectionTestResult(steps: steps);
  }

  Future<BackendConnectionTestResult> testBackend(
    BackendServer backend, {
    String? username,
    String? password,
  }) {
    return testFull(
      rawOrigin: backend.origin,
      storeCode: backend.storeCode,
      label: backend.name,
      username: username,
      password: password,
    );
  }

  /// Raccourci texte (réseau seul) — conservé pour compatibilité.
  Future<String> testOrigin(String rawOrigin, {String? storeCode, String? label}) async {
    final result = await testFull(
      rawOrigin: rawOrigin,
      storeCode: storeCode,
      label: label,
    );
    return result.displayText;
  }

  Future<BackendTestStep> _testPublicSettings(
    String base, {
    String? storeCode,
    required String name,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final code = storeCode?.trim().toLowerCase();
    if (code != null && code.isNotEmpty) {
      headers['X-Store-Code'] = code;
    }

    final url = '$base/api/public/settings';
    try {
      final res = await _dio.get<dynamic>(url, options: Options(headers: headers));
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        var extra = name;
        if (res.data is Map) {
          final storeName = (res.data as Map)['store_name']?.toString();
          if (storeName != null && storeName.isNotEmpty) {
            extra = storeName;
          }
        }
        return BackendTestStep(
          label: 'API publique',
          ok: true,
          detail: '$extra ($status)',
        );
      }
      return BackendTestStep(
        label: 'API publique',
        ok: false,
        detail: 'réponse $status',
      );
    } on DioException catch (e) {
      return BackendTestStep(
        label: 'API publique',
        ok: false,
        detail: e.message ?? e.type.name,
      );
    }
  }

  Future<
      ({
        BackendTestStep step,
        bool ok,
        String? token,
        bool isDelivery,
        bool isAdmin,
        bool isSuperAdmin,
        int? storeId,
      })> _testJwtLogin(
    String base,
    String username,
    String password,
  ) async {
    final url = '$base/api/auth/login';
    try {
      final res = await _dio.post<dynamic>(
        url,
        data: {'username': username, 'password': password},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {'Accept': 'application/json'},
        ),
      );

      if (res.statusCode == 401 || res.statusCode == 403) {
        const step = BackendTestStep(
          label: 'Login JWT',
          ok: false,
          detail: 'identifiants refusés',
        );
        return (
          step: step,
          ok: false,
          token: null,
          isDelivery: false,
          isAdmin: false,
          isSuperAdmin: false,
          storeId: null,
        );
      }
      if ((res.statusCode ?? 0) < 200 || (res.statusCode ?? 0) >= 300 || res.data is! Map) {
        final step = BackendTestStep(
          label: 'Login JWT',
          ok: false,
          detail: 'réponse ${res.statusCode ?? 0}',
        );
        return (
          step: step,
          ok: false,
          token: null,
          isDelivery: false,
          isAdmin: false,
          isSuperAdmin: false,
          storeId: null,
        );
      }

      final map = Map<String, dynamic>.from(res.data as Map);
      final token = map['token']?.toString() ?? '';
      if (token.isEmpty) {
        const step = BackendTestStep(
          label: 'Login JWT',
          ok: false,
          detail: 'token absent',
        );
        return (
          step: step,
          ok: false,
          token: null,
          isDelivery: false,
          isAdmin: false,
          isSuperAdmin: false,
          storeId: null,
        );
      }

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
      final isStaff = isDelivery || isAdmin;
      final storeId = (map['storeId'] as num?)?.toInt();

      if (!isStaff) {
        const step = BackendTestStep(
          label: 'Login JWT',
          ok: false,
          detail: 'compte sans rôle livreur/admin',
        );
        return (
          step: step,
          ok: false,
          token: null,
          isDelivery: false,
          isAdmin: false,
          isSuperAdmin: false,
          storeId: null,
        );
      }

      final roleLabel = isDelivery
          ? 'livreur'
          : (isSuperAdmin ? 'super admin' : 'admin/manager');
      final nom = map['nom']?.toString().trim();
      final who = (nom != null && nom.isNotEmpty) ? nom : username;
      final step = BackendTestStep(
        label: 'Login JWT',
        ok: true,
        detail: '$roleLabel — $who',
      );
      return (
        step: step,
        ok: true,
        token: token,
        isDelivery: isDelivery,
        isAdmin: isAdmin,
        isSuperAdmin: isSuperAdmin,
        storeId: storeId,
      );
    } on DioException catch (e) {
      final step = BackendTestStep(
        label: 'Login JWT',
        ok: false,
        detail: e.message ?? e.type.name,
      );
      return (
        step: step,
        ok: false,
        token: null,
        isDelivery: false,
        isAdmin: false,
        isSuperAdmin: false,
        storeId: null,
      );
    }
  }

  Future<BackendTestStep> _testAdminOrders(
    String base,
    String token, {
    required bool isSuperAdmin,
    int? storeId,
  }) async {
    String? url;
    if (isSuperAdmin) {
      url = '$base/api/super/orders?size=1';
    } else if (storeId != null && storeId > 0) {
      url = '$base/api/manager/$storeId/orders?size=1';
    } else {
      return const BackendTestStep(
        label: 'API admin commandes',
        ok: false,
        detail: 'storeId absent (compte manager requis)',
      );
    }

    try {
      final res = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      final status = res.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return const BackendTestStep(
          label: 'API admin commandes',
          ok: false,
          detail: 'accès refusé (rôle admin requis)',
        );
      }
      if (status >= 200 && status < 300) {
        var count = 0;
        final data = res.data;
        if (data is Map && data['content'] is List) {
          count = (data['content'] as List).length;
          final total = data['totalElements'];
          if (total is num) {
            return BackendTestStep(
              label: 'API admin commandes',
              ok: true,
              detail: '$total commande(s) au total',
            );
          }
        } else if (data is List) {
          count = data.length;
        }
        return BackendTestStep(
          label: 'API admin commandes',
          ok: true,
          detail: count > 0 ? '$count commande(s) visible(s)' : 'endpoint accessible',
        );
      }
      return BackendTestStep(
        label: 'API admin commandes',
        ok: false,
        detail: 'réponse $status',
      );
    } on DioException catch (e) {
      return BackendTestStep(
        label: 'API admin commandes',
        ok: false,
        detail: e.message ?? e.type.name,
      );
    }
  }

  Future<int?> _fetchFirstSuperStoreId(String base, String token) async {
    final url = '$base/api/super/stores';
    try {
      final res = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      if ((res.statusCode ?? 0) != 200) return null;
      final data = res.data;
      if (data is! List || data.isEmpty) return null;
      final first = data.first;
      if (first is! Map) return null;
      return (first['id'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<BackendTestStep> _testAdminUsers(
    String base,
    String token, {
    required bool isSuperAdmin,
    int? storeId,
  }) async {
    var effectiveStoreId = storeId;
    if ((effectiveStoreId == null || effectiveStoreId <= 0) && isSuperAdmin) {
      effectiveStoreId = await _fetchFirstSuperStoreId(base, token);
    }
    if (effectiveStoreId == null || effectiveStoreId <= 0) {
      return const BackendTestStep(
        label: 'API admin livreurs',
        ok: false,
        detail: 'boutique introuvable (manager ou super admin)',
      );
    }

    final url = '$base/api/manager/$effectiveStoreId/users';
    try {
      final res = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      final status = res.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return const BackendTestStep(
          label: 'API admin livreurs',
          ok: false,
          detail: 'accès refusé (rôle admin requis)',
        );
      }
      if (status >= 200 && status < 300) {
        var drivers = 0;
        final data = res.data;
        if (data is List) {
          for (final item in data) {
            if (item is Map && item['role']?.toString() == 'DELIVERY_AGENT') {
              drivers++;
            }
          }
        }
        return BackendTestStep(
          label: 'API admin livreurs',
          ok: true,
          detail: drivers > 0 ? '$drivers livreur(s)' : 'endpoint accessible',
        );
      }
      return BackendTestStep(
        label: 'API admin livreurs',
        ok: false,
        detail: 'réponse $status',
      );
    } on DioException catch (e) {
      return BackendTestStep(
        label: 'API admin livreurs',
        ok: false,
        detail: e.message ?? e.type.name,
      );
    }
  }

  Future<BackendTestStep> _testDeliveryOrders(String base, String token) async {
    final url = '$base/api/delivery/orders?size=1';
    try {
      final res = await _dio.get<dynamic>(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      final status = res.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return const BackendTestStep(
          label: 'API livraison',
          ok: false,
          detail: 'accès refusé (rôle livreur requis)',
        );
      }
      if (status >= 200 && status < 300) {
        var count = 0;
        final data = res.data;
        if (data is Map && data['content'] is List) {
          count = (data['content'] as List).length;
          final total = data['totalElements'];
          if (total is num) {
            return BackendTestStep(
              label: 'API livraison',
              ok: true,
              detail: '$total commande(s) au total',
            );
          }
        } else if (data is List) {
          count = data.length;
        }
        return BackendTestStep(
          label: 'API livraison',
          ok: true,
          detail: count > 0 ? '$count commande(s) visible(s)' : 'endpoint accessible',
        );
      }
      return BackendTestStep(
        label: 'API livraison',
        ok: false,
        detail: 'réponse $status',
      );
    } on DioException catch (e) {
      return BackendTestStep(
        label: 'API livraison',
        ok: false,
        detail: e.message ?? e.type.name,
      );
    }
  }

}
