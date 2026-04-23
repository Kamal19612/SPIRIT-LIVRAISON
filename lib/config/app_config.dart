class AppConfig {
  static const String dbName    = 'delivery_manager.db';
  static const int    dbVersion = 6;

  /// Compte administrateur SQLite (réassuré au démarrage si absent).
  static const String defaultLocalAdminUsername = 'admin';
  static const String defaultLocalAdminPassword = 'admin123';

  // Valeurs par défaut (écrasées par app_config en base)
  static const String defaultAppName      = 'Delivery Manager';
  static const String defaultLogoUrl      = '';
  static const String defaultPrimaryColor = '#F5AD41';
}
