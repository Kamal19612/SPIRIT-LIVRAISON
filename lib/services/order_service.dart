import 'package:dio/dio.dart';

import '../models/order_model.dart';
import 'store_api_bridge.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  Future<List<Order>> fetchAvailableOrders() async {
    final origin = await StoreApiBridge.instance.apiOrigin;
    final token = await StoreApiBridge.instance.jwt;
    if (origin == null || token == null) {
      throw Exception('API boutique non configurée / session absente (JWT).');
    }
    final res = await StoreApiBridge.instance.dio.get<dynamic>(
      '$origin/api/delivery/orders',
      options: Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}),
    );
    final data = res.data;
    final content = (data is Map && data['content'] is List) ? data['content'] as List : (data is List ? data : const []);
    return content
        .whereType<Map>()
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Order>> fetchMyOrders() async {
    final origin = await StoreApiBridge.instance.apiOrigin;
    final token = await StoreApiBridge.instance.jwt;
    if (origin == null || token == null) {
      throw Exception('API boutique non configurée / session absente (JWT).');
    }
    final res = await StoreApiBridge.instance.dio.get<dynamic>(
      '$origin/api/delivery/orders/my-orders',
      options: Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'}),
    );
    final data = res.data;
    final content = (data is Map && data['content'] is List) ? data['content'] as List : (data is List ? data : const []);
    return content
        .whereType<Map>()
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> claimOrder(int orderId) async {
    await StoreApiBridge.instance.claimDeliveryOrder(orderId);
  }

  Future<void> completeDelivery(int orderId, String code) async {
    await StoreApiBridge.instance.completeDeliveryOnStore(orderId, code);
  }
}
