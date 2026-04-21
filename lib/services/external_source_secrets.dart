import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/external_source_model.dart';

/// Stores sensitive per-source secrets (API keys) outside SQLite.
class ExternalSourceSecrets {
  ExternalSourceSecrets._();
  static final ExternalSourceSecrets instance = ExternalSourceSecrets._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  String _apiKeyKey(int sourceId) => 'external_source:$sourceId:api_key';

  /// Returns API key from secure storage if present, else null.
  Future<String?> getApiKey(int sourceId) async {
    final v = await _storage.read(key: _apiKeyKey(sourceId));
    if (v == null || v.trim().isEmpty) return null;
    return v;
  }

  Future<void> setApiKey(int sourceId, String apiKey) async {
    final v = apiKey.trim();
    if (v.isEmpty) {
      await clearApiKey(sourceId);
      return;
    }
    await _storage.write(key: _apiKeyKey(sourceId), value: v);
  }

  Future<void> clearApiKey(int sourceId) async {
    await _storage.delete(key: _apiKeyKey(sourceId));
  }

  /// Backward compatibility:
  /// if a source still has `config.api_key` in SQLite, migrate it to secure
  /// storage and return the migrated key.
  Future<String?> migrateApiKeyIfNeeded(ExternalSource source) async {
    final sourceId = source.id;
    if (sourceId == null) return null;

    final hasPlain = (source.config['api_key'] as String?)?.trim().isNotEmpty == true;
    if (!hasPlain) {
      return getApiKey(sourceId);
    }

    final plain = (source.config['api_key'] as String).trim();
    await setApiKey(sourceId, plain);
    return plain;
  }
}

