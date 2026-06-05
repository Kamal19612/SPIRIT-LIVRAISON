import 'package:dio/dio.dart';

import '../models/backend_server_model.dart';
import '../utils/url_normalize.dart';

/// Test de joignabilité d’un backend Spring (STORE-ALL ou compatible).
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

  /// Vérifie `GET {origin}/api/public/settings`.
  Future<String> testOrigin(String rawOrigin, {String? storeCode, String? label}) async {
    if (rawOrigin.trim().isEmpty) {
      return 'Saisissez l’URL du backend (ex. http://192.168.1.5:8085).';
    }
    final base = normalizeBackendOrigin(rawOrigin);
    if (base == null) {
      return 'URL invalide — utilisez http:// ou https:// (sans /api à la fin).';
    }

    final headers = <String, String>{'Accept': 'application/json'};
    final code = storeCode?.trim().toLowerCase();
    if (code != null && code.isNotEmpty) {
      headers['X-Store-Code'] = code;
    }

    final url = '$base/api/public/settings';
    final name = label?.trim().isNotEmpty == true ? label!.trim() : base;
    try {
      final res = await _dio.get<dynamic>(url, options: Options(headers: headers));
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        var extra = '';
        if (res.data is Map) {
          final storeName = (res.data as Map)['store_name']?.toString();
          if (storeName != null && storeName.isNotEmpty) {
            extra = ' — $storeName';
          }
        }
        return 'Connexion OK ($status) — $name$extra';
      }
      return 'Réponse inattendue ($status) sur $url';
    } on DioException catch (e) {
      final msg = e.message ?? e.type.name;
      return 'Échec ($name) : $msg';
    }
  }

  Future<String> testBackend(BackendServer backend) {
    return testOrigin(
      backend.origin,
      storeCode: backend.storeCode,
      label: backend.name,
    );
  }
}
