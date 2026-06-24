import 'package:flutter_test/flutter_test.dart';
import 'package:appstore/models/order_model.dart';
import 'package:appstore/models/user_model.dart';
import 'package:appstore/services/driver_earnings_service.dart';
import 'package:appstore/utils/delivery_earnings.dart';

void main() {
  group('Order.fromJson earnings fields', () {
    test('parses deliveryCost and deliveryAgent from Spring payload', () {
      final order = Order.fromJson(
        {
          'id': 42,
          'orderNumber': 'ORD-2026-0042',
          'customerName': 'Client Test',
          'customerPhone': '70000000',
          'customerAddress': 'Ouaga',
          'subtotal': 15000,
          'tax': 0,
          'total': 16000,
          'deliveryCost': 1000,
          'deliveryType': 'EXPRESS',
          'status': 'DELIVERED',
          'createdAt': '2026-06-20T10:00:00',
          'updatedAt': '2026-06-20T11:30:00',
          'deliveryAgent': {
            'id': 4,
            'username': 'livreur',
            'role': 'DELIVERY_AGENT',
          },
          'store': {'id': 2, 'name': 'SPIRIT STORE', 'code': 'spirit'},
        },
        backendId: 1,
        backendName: 'Local',
      );

      expect(order.deliveryCost, 1000);
      expect(order.deliveryAgent?['username'], 'livreur');
      expect(driverGain(order), 1000);
    });

    test('parses deliveryCost as string (BigDecimal JSON)', () {
      final order = Order.fromJson({
        'id': 1,
        'orderNumber': 'ORD-1',
        'customerName': 'A',
        'customerPhone': '1',
        'customerAddress': 'X',
        'subtotal': 100,
        'tax': 0,
        'total': 1500,
        'deliveryCost': '500',
        'status': 'DELIVERED',
        'createdAt': '2026-06-24T08:00:00',
        'updatedAt': '2026-06-24T09:00:00',
        'deliveryAgent': {'username': 'livreur'},
      });
      expect(order.deliveryCost, 500);
    });
  });

  group('DriverEarningsService', () {
    final driver = const UserModel(
      id: 4,
      username: 'livreur',
      role: 'DELIVERY_AGENT',
      backendId: 1,
      backendName: 'Store',
    );

    Order delivered({
      required String updatedAt,
      double cost = 1000,
      String type = 'STANDARD',
    }) =>
        Order.fromJson(
          {
            'id': 10,
            'orderNumber': 'ORD-X',
            'customerName': 'C',
            'customerPhone': '1',
            'customerAddress': 'A',
            'subtotal': 5000,
            'tax': 0,
            'total': 6000,
            'deliveryCost': cost,
            'deliveryType': type,
            'status': 'DELIVERED',
            'createdAt': updatedAt,
            'updatedAt': updatedAt,
            'deliveryAgent': {'id': 4, 'username': 'livreur'},
          },
          backendId: 1,
        );

    test('summarizeDriverDay filters by driver, date and type', () {
      final orders = [
        delivered(updatedAt: '2026-06-24T14:00:00', cost: 1500, type: 'EXPRESS'),
        delivered(updatedAt: '2026-06-24T16:00:00', cost: 500),
        delivered(updatedAt: '2026-06-23T12:00:00', cost: 2000),
        Order.fromJson(
          {
            'id': 11,
            'orderNumber': 'ORD-Y',
            'customerName': 'C',
            'customerPhone': '1',
            'customerAddress': 'A',
            'subtotal': 1000,
            'tax': 0,
            'total': 1000,
            'deliveryCost': 800,
            'status': 'DELIVERED',
            'createdAt': '2026-06-24T10:00:00',
            'updatedAt': '2026-06-24T10:00:00',
            'deliveryAgent': {'username': 'autre'},
          },
          backendId: 1,
        ),
      ];

      final day = DateTime(2026, 6, 24);
      final summary = DriverEarningsService.instance.summarizeDriverDay(
        orders,
        driver,
        day,
      );
      expect(summary.deliveryCount, 2);
      expect(summary.totalGain, 2000);

      final expressOnly = DriverEarningsService.instance.summarizeDriverDay(
        orders,
        driver,
        day,
        deliveryTypeFilter: 'EXPRESS',
      );
      expect(expressOnly.deliveryCount, 1);
      expect(expressOnly.totalGain, 1500);
    });

    test('topDriversByGain aggregates last 7 days', () {
      final now = DateTime.now();
      final todayIso = now.toIso8601String();
      final orders = [
        delivered(updatedAt: todayIso, cost: 1000),
        Order.fromJson(
          {
            'id': 12,
            'orderNumber': 'ORD-Z',
            'customerName': 'C',
            'customerPhone': '1',
            'customerAddress': 'A',
            'subtotal': 1000,
            'tax': 0,
            'total': 2000,
            'deliveryCost': 3000,
            'status': 'DELIVERED',
            'createdAt': todayIso,
            'updatedAt': todayIso,
            'deliveryAgent': {'username': 'livreur2'},
          },
          backendId: 2,
          backendName: 'B2',
        ),
      ];

      final top = DriverEarningsService.instance.topDriversByGain(orders, days: 7);
      expect(top.length, 2);
      expect(top.first.gain, 3000);
    });
  });

  group('OrderService page response parsing', () {
    test('parses Spring Page content array', () {
      final data = {
        'content': [
          {
            'id': 1,
            'orderNumber': 'ORD-1',
            'customerName': 'A',
            'customerPhone': '1',
            'customerAddress': 'X',
            'subtotal': 100,
            'tax': 0,
            'total': 1100,
            'deliveryCost': 1000,
            'status': 'DELIVERED',
            'createdAt': '2026-06-24T08:00:00',
            'updatedAt': '2026-06-24T09:00:00',
            'deliveryAgent': {'username': 'livreur'},
          },
        ],
      };
      final list = (data['content'] as List)
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      expect(list.single.deliveryCost, 1000);
      expect(list.single.deliveryAgent?['username'], 'livreur');
    });
  });
}
