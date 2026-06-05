import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/backend_server_model.dart';
import '../models/order_model.dart';
import 'store_api_bridge.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  List<Order> _parseOrdersFromResponseData(
    dynamic data, {
    required BackendServer backend,
  }) {
    List<Map<String, dynamic>> rawMaps = [];
    if (data is Map && data['content'] is List) {
      rawMaps = (data['content'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else if (data is List) {
      rawMaps = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return rawMaps
        .map(
          (e) => Order.fromJson(
            e,
            backendId: backend.id,
            backendName: backend.name,
          ),
        )
        .toList();
  }

  void _logStoreApi(String method, String url, int? status, Object? detail) {
    if (!kDebugMode) return;
    final s = status?.toString() ?? '?';
    debugPrint('[StoreAPI] $method $url → $s $detail');
  }

  Future<List<BackendServer>> _sessionBackends() =>
      StoreApiBridge.instance.getAuthenticatedBackends();

  Future<List<Order>> fetchAdminOrders({int size = 200}) async {
    final backends = await _sessionBackends();
    if (backends.isEmpty) {
      throw Exception('Aucun serveur connecté (JWT).');
    }

    final merged = <Order>[];
    for (final backend in backends) {
      final token = await StoreApiBridge.instance.getJwt(backend.id!);
      if (token == null) continue;
      final url = '${backend.origin}/api/admin/orders?size=$size&sort=createdAt,desc';
      final res = await StoreApiBridge.instance.dio.get<dynamic>(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        ),
      );
      final code = res.statusCode ?? 0;
      _logStoreApi('GET', url, code, 'admin orders (${backend.name})');
      if (code == 200) {
        merged.addAll(_parseOrdersFromResponseData(res.data, backend: backend));
      } else if (code == 401 || code == 403) {
        if (kDebugMode) {
          debugPrint('[StoreAPI] admin refusé sur ${backend.name}');
        }
      }
    }

    if (merged.isEmpty) {
      throw Exception('Aucune commande admin (vérifiez rôle manager/admin).');
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<Map<String, dynamic>?> fetchAdminDashboardStats() async {
    final backends = await _sessionBackends();
    if (backends.isEmpty) return null;

    int totalOrders = 0;
    int confirmedOrders = 0;
    for (final backend in backends) {
      final token = await StoreApiBridge.instance.getJwt(backend.id!);
      if (token == null) continue;
      final url = '${backend.origin}/api/admin/dashboard/stats';
      try {
        final res = await StoreApiBridge.instance.dio.get<dynamic>(
          url,
          options: Options(
            headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
          ),
        );
        if (res.statusCode == 200 && res.data is Map) {
          final map = Map<String, dynamic>.from(res.data as Map);
          totalOrders += (map['totalOrders'] as num?)?.toInt() ?? 0;
          confirmedOrders += (map['confirmedOrders'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}
    }

    if (totalOrders == 0 && confirmedOrders == 0) return null;
    return {
      'totalOrders': totalOrders,
      'confirmedOrders': confirmedOrders,
    };
  }

  Future<List<Order>> fetchAvailableOrders() async {
    return _fetchDeliveryList('/api/delivery/orders');
  }

  Future<List<Order>> fetchMyOrders() async {
    return _fetchDeliveryList('/api/delivery/orders/my-orders');
  }

  Future<List<Order>> _fetchDeliveryList(String path) async {
    final backends = await _sessionBackends();
    if (backends.isEmpty) {
      throw Exception('Aucun serveur connecté. Reconnectez-vous.');
    }

    final merged = <Order>[];
    Object? lastError;

    for (final backend in backends) {
      final token = await StoreApiBridge.instance.getJwt(backend.id!);
      if (token == null) continue;
      try {
        final res = await StoreApiBridge.instance.dio.get<dynamic>(
          '${backend.origin}$path',
          options: Options(
            headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
          ),
        );
        if ((res.statusCode ?? 0) == 200) {
          merged.addAll(_parseOrdersFromResponseData(res.data, backend: backend));
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (merged.isEmpty && lastError != null) {
      throw Exception('Impossible de charger les commandes ($lastError)');
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<BackendServer> _backendForOrder(Order order) async {
    final id = order.backendId;
    if (id == null) {
      throw Exception('Commande sans serveur d’origine.');
    }
    final backends = await _sessionBackends();
    final backend = backends.where((b) => b.id == id).firstOrNull;
    if (backend == null) {
      throw Exception('Session expirée pour ce serveur.');
    }
    return backend;
  }

  Future<Order> claimOrder(Order order) async {
    final backend = await _backendForOrder(order);
    return StoreApiBridge.instance.claimDeliveryOrder(
      backend: backend,
      storeOrderId: order.id,
    );
  }

  Future<void> completeDelivery(Order order, String code) async {
    final backend = await _backendForOrder(order);
    await StoreApiBridge.instance.completeDeliveryOnStore(
      backend: backend,
      storeOrderId: order.id,
      code: code,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
