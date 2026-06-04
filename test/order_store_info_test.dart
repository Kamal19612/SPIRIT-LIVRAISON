import 'package:flutter_test/flutter_test.dart';
import 'package:appstore/models/order_model.dart';
import 'package:appstore/models/order_store_info.dart';

void main() {
  group('OrderStoreInfo', () {
    test('fromJson parses Spring store payload', () {
      final s = OrderStoreInfo.fromJson({
        'id': 2,
        'name': 'Spirit Shop',
        'code': 'spirit',
        'phone': '+22670123456',
        'mapsUrl': 'https://maps.example/spirit',
      });
      expect(s.id, 2);
      expect(s.name, 'Spirit Shop');
      expect(s.code, 'spirit');
      expect(s.phone, '+22670123456');
      expect(s.mapsUrl, 'https://maps.example/spirit');
    });
  });

  group('Order.pickupInfo', () {
    test('prefers store over public settings', () {
      final order = Order.fromJson({
        'id': 10,
        'orderNumber': 'ORD-1',
        'customerName': 'A',
        'customerPhone': '1',
        'customerAddress': 'Addr',
        'subtotal': 1000,
        'tax': 0,
        'total': 1000,
        'status': 'CONFIRMED',
        'createdAt': '2026-01-01T12:00:00',
        'store': {
          'name': 'Boutique A',
          'code': 'sucre',
          'phone': '111',
          'mapsUrl': 'https://maps/a',
        },
      });
      final pickup = order.pickupInfo({
        'store_name': 'Fallback',
        'whatsapp_number': '999',
      });
      expect(pickup.name, 'Boutique A');
      expect(pickup.code, 'sucre');
      expect(pickup.phone, '111');
      expect(pickup.location, 'https://maps/a');
    });

    test('falls back to public settings when store missing', () {
      final order = Order.fromJson({
        'id': 11,
        'orderNumber': 'ORD-2',
        'customerName': 'B',
        'customerPhone': '2',
        'customerAddress': 'Addr',
        'subtotal': 500,
        'tax': 0,
        'total': 500,
        'status': 'CONFIRMED',
        'createdAt': '2026-01-01T12:00:00',
      });
      final pickup = order.pickupInfo({
        'store_name': 'Spirit',
        'whatsapp_number': '0700',
        'store_location': 'Ouagadougou',
      });
      expect(pickup.name, 'Spirit');
      expect(pickup.phone, '0700');
      expect(pickup.location, 'Ouagadougou');
    });
  });
}
