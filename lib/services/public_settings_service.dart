import 'package:dio/dio.dart';

import '../database/backends_dao.dart';
import '../models/backend_server_model.dart';
import 'store_api_bridge.dart';

class PublicSettingsService {
  PublicSettingsService._();
  static final PublicSettingsService instance = PublicSettingsService._();

  /// Réglages vitrine pour une commande (backend + code boutique).
  Future<Map<String, String>> fetchForOrder({
    int? backendId,
    String? storeCode,
  }) async {
    BackendServer? backend;
    if (backendId != null) {
      backend = await BackendsDao.instance.getById(backendId);
    }
    if (backend == null) {
      final list = await StoreApiBridge.instance.getAuthenticatedBackends();
      if (list.isEmpty) return {};
      backend = list.first;
    }

    final headers = <String, String>{'Accept': 'application/json'};
    final code = (storeCode ?? backend.storeCode).trim().toLowerCase();
    if (code.isNotEmpty) {
      headers['X-Store-Code'] = code;
    }

    final res = await StoreApiBridge.instance.dio.get<dynamic>(
      '${backend.origin}/api/public/settings',
      options: Options(headers: headers),
    );

    if ((res.statusCode ?? 0) < 200 || (res.statusCode ?? 0) >= 300) return {};
    if (res.data is! Map) return {};

    final raw = Map<String, dynamic>.from(res.data as Map);
    return raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }
}
