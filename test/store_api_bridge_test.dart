import 'package:flutter_test/flutter_test.dart';

import 'package:appstore/services/store_api_bridge.dart';

void main() {
  group('normalizeStoreApiOrigin', () {
    test('trims and strips trailing slashes', () {
      expect(normalizeStoreApiOrigin(' https://api.test/ '), 'https://api.test');
      expect(normalizeStoreApiOrigin('https://api.test///'), 'https://api.test');
    });

    test('removes internal whitespace (bad paste after scheme)', () {
      expect(
        normalizeStoreApiOrigin('http:// 5.189.133.248:8000/'),
        'http://5.189.133.248:8000',
      );
    });

    test('prefixes scheme when host:port only', () {
      expect(
        normalizeStoreApiOrigin('5.189.133.248:8000'),
        'http://5.189.133.248:8000',
      );
    });

    test('returns null for blank', () {
      expect(normalizeStoreApiOrigin(''), isNull);
      expect(normalizeStoreApiOrigin('   '), isNull);
    });
  });
}
