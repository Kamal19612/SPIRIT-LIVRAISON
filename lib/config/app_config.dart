class AppConfig {
  static const String dbName    = 'delivery_manager.db';
  static const int    dbVersion = 10;

  // Valeurs par défaut (écrasées par app_config en base)
  static const String defaultAppName      = 'Delivery Manager';
  static const String defaultLogoUrl      = '';
  static const String defaultPrimaryColor = '#F5AD41';

  /// Origine publique du backend Spring Boot, **sans** `/` final ni suffixe `/api`
  /// (les appels utilisent `{origin}/api/...`). Surchargeable : Admin app → Intégrations.
  /// En local : `http://<IP>:8081`.
  /// API Spring (Sucre Store / même backend que la boutique). Surchargeable : Admin app → Intégrations.
  static const String defaultStoreApiOrigin = 'https://sucrestore.socialracine.com';
}
