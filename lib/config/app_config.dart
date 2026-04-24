class AppConfig {
  static const String dbName    = 'delivery_manager.db';
  static const int    dbVersion = 7;

  /// Compte administrateur SQLite : créé au premier lancement et réinjecté au démarrage
  /// si la ligne manque ([LocalDatabase.ensureDefaultLocalAccounts]). À changer en prod
  /// après la première connexion locale (Admin) si vous exposez l’APK publiquement.
  static const String defaultLocalAdminUsername = 'admin';
  static const String defaultLocalAdminPassword = r'Pass_word.(1)@!';

  // Valeurs par défaut (écrasées par app_config en base)
  static const String defaultAppName      = 'Delivery Manager';
  static const String defaultLogoUrl      = '';
  static const String defaultPrimaryColor = '#F5AD41';
}
