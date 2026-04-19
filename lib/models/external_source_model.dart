import 'dart:convert';

class ExternalSource {
  final int? id;
  final String name;
  final String platformType; // 'webhook' | 'rest_polling'
  final Map<String, dynamic> config;
  final bool isActive;
  final String createdAt;

  const ExternalSource({
    this.id,
    required this.name,
    required this.platformType,
    required this.config,
    required this.isActive,
    required this.createdAt,
  });

  // ── Config accessors — REST polling ─────────────────────────────────────────

  String get url           => config['url']           as String? ?? '';
  String get apiKey        => config['api_key']        as String? ?? '';
  String get authType      => config['auth_type']      as String? ?? 'none';
  String get responsePath  => config['response_path']  as String? ?? '';
  String get lastSyncAt    => config['last_sync_at']   as String? ?? '';
  String get lastError     => config['last_error']     as String? ?? '';
  int    get syncedCount   => (config['synced_count']  as num?)?.toInt() ?? 0;

  // ── Config accessors — Webhook ───────────────────────────────────────────────

  /// Secret partagé pour la vérification HMAC-SHA256 (côté serveur relais).
  String get webhookSecret   => config['webhook_secret']    as String? ?? '';

  /// Identifiant de cette source dans le champ `source` des payloads envoyés
  /// par le serveur relais (ex: "shopify", "woocommerce").
  String get sourceIdentifier => config['source_identifier'] as String? ?? name;

  /// Nombre d'événements reçus via ce webhook.
  int    get receivedCount   => (config['received_count']   as num?)?.toInt() ?? 0;

  /// Horodatage du dernier événement reçu.
  String get lastReceivedAt  => config['last_received_at']  as String? ?? '';

  /// Field mapping overrides: keys are our canonical names, values are source field names.
  /// e.g. {'orderNumber': 'ref_cmd', 'customerName': 'client'}
  Map<String, String> get fieldMapping {
    final raw = config['field_mapping'];
    if (raw == null) return {};
    if (raw is Map) return Map<String, String>.from(raw.map((k, v) => MapEntry(k.toString(), v.toString())));
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw) as Map;
        return Map<String, String>.from(decoded.map((k, v) => MapEntry(k.toString(), v.toString())));
      } catch (_) {}
    }
    return {};
  }

  // ── Factory / serialization ─────────────────────────────────────────────────

  factory ExternalSource.fromSqlite(Map<String, dynamic> row) {
    Map<String, dynamic> configMap = {};
    try {
      configMap =
          jsonDecode(row['configJson'] as String? ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    return ExternalSource(
      id: row['id'] as int?,
      name: row['name'] as String? ?? '',
      platformType: row['platformType'] as String? ?? 'webhook',
      config: configMap,
      isActive: (row['isActive'] as int?) == 1,
      createdAt: row['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toSqlite() => {
        if (id != null) 'id': id,
        'name': name,
        'platformType': platformType,
        'configJson': jsonEncode(config),
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt,
      };

  ExternalSource copyWithConfig(Map<String, dynamic> updatedConfig) {
    return ExternalSource(
      id: id,
      name: name,
      platformType: platformType,
      config: {...config, ...updatedConfig},
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}
