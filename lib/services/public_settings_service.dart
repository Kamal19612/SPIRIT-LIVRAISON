import 'package:dio/dio.dart';

import 'store_api_bridge.dart';

class PublicSettingsService {
  PublicSettingsService._();
  static final PublicSettingsService instance = PublicSettingsService._();

  /// Réglages vitrine (repli affichage retrait si `order.store` absent).
  /// [storeCode] → en-tête `X-Store-Code` (aligné STORE-ALL multi-boutique).
  Future<Map<String, String>> fetch({String? storeCode}) async {
    final origin = await StoreApiBridge.instance.apiOrigin;
    if (origin == null || origin.isEmpty) return {};

    final headers = <String, String>{'Accept': 'application/json'};
    final code = storeCode?.trim().toLowerCase();
    if (code != null && code.isNotEmpty) {
      headers['X-Store-Code'] = code;
    }

    final res = await StoreApiBridge.instance.dio.get<dynamic>(
      '$origin/api/public/settings',
      options: Options(headers: headers),
    );

    if ((res.statusCode ?? 0) < 200 || (res.statusCode ?? 0) >= 300) return {};
    if (res.data is! Map) return {};

    final raw = Map<String, dynamic>.from(res.data as Map);
    return raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }
}

