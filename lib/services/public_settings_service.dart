import 'package:dio/dio.dart';

import 'store_api_bridge.dart';

class PublicSettingsService {
  PublicSettingsService._();
  static final PublicSettingsService instance = PublicSettingsService._();

  Future<Map<String, String>> fetch() async {
    final origin = await StoreApiBridge.instance.apiOrigin;
    if (origin == null || origin.isEmpty) return {};

    final res = await StoreApiBridge.instance.dio.get<dynamic>(
      '$origin/api/public/settings',
      options: Options(headers: {'Accept': 'application/json'}),
    );

    if ((res.statusCode ?? 0) < 200 || (res.statusCode ?? 0) >= 300) return {};
    if (res.data is! Map) return {};

    final raw = Map<String, dynamic>.from(res.data as Map);
    return raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }
}

