import 'package:dio/dio.dart';

import '../database/app_config_dao.dart';
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

  /// Vérifie `GET {origin}/api/public/settings` (endpoint public multi-boutique).
  Future<String> testOrigin(String rawOrigin) async {
    if (rawOrigin.trim().isEmpty) {
      return 'Saisissez l’URL du backend (ex. http://192.168.1.5:8085).';
    }
    final base = normalizeBackendOrigin(rawOrigin);
    if (base == null) {
      return 'URL invalide — utilisez http:// ou https:// (sans /api à la fin).';
    }
    final url = '$base/api/public/settings';
    try {
      final res = await _dio.get<dynamic>(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        return 'Connexion OK ($code) — $base';
      }
      return 'Réponse inattendue ($code) sur $url';
    } on DioException catch (e) {
      final msg = e.message ?? e.type.name;
      return 'Échec : $msg ($url)';
    }
  }

  Future<String> testSavedOrigin() async {
    final saved = await AppConfigDao.instance.getStoreApiOrigin();
    if (saved == null) return 'Aucune URL enregistrée.';
    return testOrigin(saved);
  }
}
