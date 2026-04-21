// Normalisation des payloads `order` pour plusieurs boutiques / backends.
//
// Chaque source externe peut définir `source_identifier` (champ JSON `source`
// du webhook) et `field_mapping` { canonique: "cle.che.partenaire" } pour
// aligner les JSON sur le modèle attendu par [Order.fromJson].

import '../database/local_database.dart';
import '../models/external_source_model.dart';

class WebhookOrderNormalizer {
  WebhookOrderNormalizer._();

  /// Source SQLite correspondant au champ `source` du webhook.
  static Future<ExternalSource?> resolveSource(String? sourceId) async {
    if (sourceId == null || sourceId.isEmpty) return null;
    final db = LocalDatabase.instance.db;
    final rows = await db.query(
      'external_sources',
      where: 'platformType = ? AND isActive = 1',
      whereArgs: ['webhook'],
    );
    for (final row in rows) {
      final s = ExternalSource.fromSqlite(row);
      if (s.sourceIdentifier == sourceId || s.name == sourceId) {
        return s;
      }
    }
    return null;
  }

  /// Copie + [field_mapping] + [sourcePlatform] par défaut.
  static Map<String, dynamic>? normalizeOrder(
    Map<String, dynamic>? order,
    ExternalSource? source,
  ) {
    if (order == null) return null;
    final out = Map<String, dynamic>.from(order);
    if (source != null && source.name.isNotEmpty) {
      out.putIfAbsent('sourcePlatform', () => source.name);
    }
    final m = source?.fieldMapping ?? const <String, String>{};
    for (final e in m.entries) {
      final remote = e.value;
      if (remote.isEmpty) continue;
      final v = deepGet(order, remote);
      if (v != null) {
        out[e.key] = v;
      }
    }
    return out;
  }

  static dynamic deepGet(Map<String, dynamic> map, String path) {
    dynamic current = map;
    for (final key in path.split('.')) {
      if (current is Map) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }
}
