import '../database/app_config_dao.dart';

class AppConfigService {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  Future<Map<String, String>> getAll() => AppConfigDao.instance.getAll();

  Future<void> save(Map<String, String> config) async {
    for (final entry in config.entries) {
      await AppConfigDao.instance.setValue(entry.key, entry.value);
    }
  }
}
