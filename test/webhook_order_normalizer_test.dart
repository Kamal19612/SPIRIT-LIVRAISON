import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:appstore/models/external_source_model.dart';
import 'package:appstore/services/webhook_order_normalizer.dart';

ExternalSource _sourceWithMapping(Map<String, String> mapping) {
  return ExternalSource.fromSqlite({
    'id': 1,
    'name': 'BoutiqueTest',
    'platformType': 'webhook',
    'configJson': jsonEncode({'field_mapping': mapping}),
    'isActive': 1,
    'createdAt': '2020-01-01',
  });
}

void main() {
  group('WebhookOrderNormalizer.deepGet', () {
    test('supports dot paths', () {
      final m = {
        'client': {'nom': 'Alice'},
      };
      expect(
        WebhookOrderNormalizer.deepGet(m, 'client.nom'),
        'Alice',
      );
    });
  });

  group('WebhookOrderNormalizer.normalizeOrder', () {
    test('applies field_mapping and sourcePlatform default', () {
      final raw = {
        'ref': 'X-1',
        'customerName': 'Bob',
      };
      final src = _sourceWithMapping({'orderNumber': 'ref'});
      final out = WebhookOrderNormalizer.normalizeOrder(raw, src)!;
      expect(out['orderNumber'], 'X-1');
      expect(out['customerName'], 'Bob');
      expect(out['sourcePlatform'], 'BoutiqueTest');
    });
  });
}
