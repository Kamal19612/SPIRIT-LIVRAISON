import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_config_dao.dart';
import '../utils/url_normalize.dart';

class SupabaseAppClient {
  SupabaseAppClient._();
  static final SupabaseAppClient instance = SupabaseAppClient._();

  SupabaseClient? _client;
  String? _url;
  String? _anonKey;

  Future<SupabaseClient> client() async {
    final urlRaw = await AppConfigDao.instance.getValue('supabase_url');
    final anonRaw = await AppConfigDao.instance.getValue('supabase_anon_key');
    final url = normalizeHttpOrigin(urlRaw ?? '') ?? (urlRaw ?? '');
    final anonKey = (anonRaw ?? '').trim();

    if (url.trim().isEmpty || anonKey.isEmpty) {
      throw Exception('Supabase non configuré (URL / ANON KEY).');
    }

    final same = _client != null && _url == url && _anonKey == anonKey;
    if (same) return _client!;

    _client = SupabaseClient(
      url.trim(),
      anonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        timeout: Duration(seconds: 45),
      ),
    );
    _url = url;
    _anonKey = anonKey;
    return _client!;
  }
}

