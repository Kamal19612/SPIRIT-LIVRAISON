class AppConfig {
  static const String dbName    = 'delivery_manager.db';
  static const int    dbVersion = 14;

  // Valeurs par défaut (écrasées par app_config en base)
  static const String defaultAppName      = 'Delivery Manager';
  static const String defaultLogoUrl      = '';
  static const String defaultPrimaryColor = '#F5AD41';

  /// Clé SQLite : URL backend saisie **manuellement** (Admin → Paramètres → Intégrations).
  /// Aucune URL n’est injectée au build — ex. `http://192.168.1.10:8085` (STORE-ALL).
  static const String storeApiOriginConfigKey = 'store_api_origin';

  /// Compte admin SQLite (module admin autonome, sans API).
  static const String defaultLocalAdminUsername = 'admin';
  static const String defaultLocalAdminPassword = 'Pass_word.(1)@!';
}
