import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';
import '../utils/url_normalize.dart';
import 'local_database.dart';

class AppConfigDao {
  AppConfigDao._();
  static final AppConfigDao instance = AppConfigDao._();

  Database get _db => LocalDatabase.instance.db;

  Future<String?> getValue(String key) async {
    final rows = await _db.query('app_config', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setValue(String key, String value) async {
    await _db.insert(
      'app_config',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// URL backend saisie manuellement (sans `/api`). `null` si non configurée.
  Future<String?> getStoreApiOrigin() async {
    final raw = await getValue(AppConfig.storeApiOriginConfigKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return normalizeBackendOrigin(raw);
  }

  Future<Map<String, String>> getAll() async {
    final rows = await _db.query('app_config');
    return Map.fromEntries(
      rows.map((r) => MapEntry(r['key'] as String, r['value'] as String)),
    );
  }
}
