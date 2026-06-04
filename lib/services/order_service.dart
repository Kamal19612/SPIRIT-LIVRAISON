import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import 'store_api_bridge.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  /// Réponse [Page] Spring (`content`) ou liste brute.
  List<Order> _parseOrdersFromResponseData(dynamic data) {
    if (data is Map && data['content'] is List) {
      return (data['content'] as List)
          .whereType<Map>()
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  void _logStoreApi(String method, String url, int? status, Object? detail) {
    if (!kDebugMode) return;
    final s = status?.toString() ?? '?';
    debugPrint('[StoreAPI] $method $url → $s $detail');
  }

  /// Liste admin (toutes commandes) — [JwtResponse] rôle ADMIN / SUPER_ADMIN / MANAGER.
  Future<List<Order>> fetchAdminOrders({int size = 200}) async {
    final origin = await StoreApiBridge.instance.apiOrigin;
    final token = await StoreApiBridge.instance.jwt;
    if (origin == null || token == null) {
      throw Exception('API boutique non configurée / session absente (JWT).');
    }
    final url = '$origin/api/admin/orders?size=$size&sort=createdAt,desc';
    final res = await StoreApiBridge.instance.dio.get<dynamic>(
      url,
      options: Options(
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ),
    );
    final code = res.statusCode ?? 0;
    _logStoreApi('GET', url, code, 'orders');
    if (code == 200) {
      final list = _parseOrdersFromResponseData(res.data);
      if (kDebugMode) {
        debugPrint('[StoreAPI] admin orders count=${list.length}');
      }
      return list;
    }
    if (code == 401 || code == 403) {
      throw Exception('Accès refusé (rôle admin requis sur la boutique).');
    }
    String msg = 'Liste admin ($code)';
    final data = res.data;
    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    }
    throw Exception(msg);
  }

  /// Statistiques dashboard Spring (`/api/admin/dashboard/stats`).
  Future<Map<String, dynamic>?> fetchAdminDashboardStats() async {
    final origin = await StoreApiBridge.instance.apiOrigin;
    final token = await StoreApiBridge.instance.jwt;
    if (origin == null || token == null) {
      throw Exception('API boutique non configurée / session absente (JWT).');
    }
    final url = '$origin/api/admin/dashboard/stats';
    final res = await StoreApiBridge.instance.dio.get<dynamic>(
      url,
      options: Options(
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ),
    );
    final code = res.statusCode ?? 0;
    _logStoreApi('GET', url, code, 'stats');
    if (code == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    if (code == 401 || code == 403) {
      throw Exception('Accès refusé (statistiques admin).');
    }
    if (code >= 200 && code < 300) {
      return null;
    }
    String msg = 'Stats admin ($code)';
    final data = res.data;
    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    }
    throw Exception(msg);
  }

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
    return _parseOrdersFromResponseData(res.data);
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
    return _parseOrdersFromResponseData(res.data);
  }

  Future<Order> claimOrder(int orderId) async {
    return StoreApiBridge.instance.claimDeliveryOrder(orderId);
  }

  Future<void> completeDelivery(int orderId, String code) async {
    await StoreApiBridge.instance.completeDeliveryOnStore(orderId, code);
  }
}
