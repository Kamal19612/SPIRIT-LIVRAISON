import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../database/orders_dao.dart';
import '../models/backend_server_model.dart';
import '../models/order_model.dart';
import 'auth_service.dart';
import 'backend_admin_api.dart';
import 'store_api_bridge.dart';
import '../utils/api_auth_messages.dart';

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

  Future<({List<Order> orders, String? error})> _fetchAdminOrdersOnBackend(
    BackendServer backend, {
    int size = 200,
  }) async {
    final id = backend.id;
    if (id == null) return (orders: <Order>[], error: 'Serveur invalide.');

    final token = await StoreApiBridge.instance.getJwt(id);
    if (token == null) {
      return (orders: <Order>[], error: 'Session expirée sur ${backend.name}.');
    }

    final session = await StoreApiBridge.instance.resolveAdminSession(
      backendId: id,
      backend: backend,
      token: token,
    );
    final managerStoreId = await StoreApiBridge.instance.resolveManagerStoreId(
      backendId: id,
      backend: backend,
      token: token,
      session: session,
    );
    final url = BackendAdminApi.adminOrdersUrl(
      backend: backend,
      session: session,
      managerStoreId: managerStoreId,
      size: size,
    );
    if (url == null) {
      return (
        orders: <Order>[],
        error: 'Boutique introuvable sur ${backend.name} (vérifiez code ou ID boutique).',
      );
    }

    try {
      final res = await StoreApiBridge.instance.dio.get<dynamic>(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        ),
      );
      final code = res.statusCode ?? 0;
      _logStoreApi('GET', url, code, 'admin orders (${backend.name})');
      if (code == 200) {
        return (
          orders: _parseOrdersFromResponseData(res.data, backend: backend),
          error: null,
        );
      }
      if (isStoreApiAuthStatus(code)) {
        return (
          orders: <Order>[],
          error: storeApiAuthErrorMessage(
            statusCode: code,
            backendName: backend.name,
            context: 'admin',
          ),
        );
      }
      return (orders: <Order>[], error: 'Erreur $code sur ${backend.name}.');
    } catch (e) {
      return (orders: <Order>[], error: 'Impossible de joindre ${backend.name} ($e).');
    }
  }

  /// Commandes admin pour un seul serveur (sync SSE ciblée multi-backend).
  Future<List<Order>> fetchAdminOrdersForBackend(int backendId, {int size = 200}) async {
    final backends = await _sessionBackends();
    final backend = backends.where((b) => b.id == backendId).firstOrNull;
    if (backend == null) {
      throw Exception('Serveur #$backendId non connecté.');
    }
    final result = await _fetchAdminOrdersOnBackend(backend, size: size);
    if (result.error != null && result.orders.isEmpty) {
      throw Exception(result.error);
    }
    final list = List<Order>.from(result.orders);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Détail complet d'une commande admin (articles, client, livreur…).
  Future<Order> fetchAdminOrderDetail(Order order) async {
    if (await _useLocalOrders()) {
      final local = await OrdersDao.instance.getOrderById(order.id);
      return local ?? order;
    }

    final backendId = order.backendId;
    if (backendId == null) return order;

    final backends = await _sessionBackends();
    final backend = backends.where((b) => b.id == backendId).firstOrNull;
    if (backend == null) return order;

    final token = await StoreApiBridge.instance.getJwt(backendId);
    if (token == null) return order;

    final session = await StoreApiBridge.instance.resolveAdminSession(
      backendId: backendId,
      backend: backend,
      token: token,
    );
    final managerStoreId = await StoreApiBridge.instance.resolveManagerStoreId(
      backendId: backendId,
      backend: backend,
      token: token,
      session: session,
    );
    final storeId = order.store?.id ?? managerStoreId;
    if (storeId == null || storeId <= 0) return order;

    final url = BackendAdminApi.adminOrderDetailUrl(
      backend: backend,
      storeId: storeId,
      orderId: order.id,
    );
    if (url == null) return order;

    try {
      final res = await StoreApiBridge.instance.dio.get<dynamic>(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        ),
      );
      if ((res.statusCode ?? 0) == 200 && res.data is Map) {
        return Order.fromJson(
          Map<String, dynamic>.from(res.data as Map),
          backendId: backend.id,
          backendName: backend.name,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[StoreAPI] détail commande: $e');
    }
    return order;
  }

  Future<List<Order>> fetchAdminOrders({int size = 200}) async {
    final backends = await _sessionBackends();
    if (backends.isEmpty) {
      throw Exception('Aucun serveur connecté (JWT). Reconnectez-vous.');
    }

    final merged = <Order>[];
    var anySuccess = false;
    String? lastError;

    for (final backend in backends) {
      final result = await _fetchAdminOrdersOnBackend(backend, size: size);
      if (result.orders.isNotEmpty) {
        anySuccess = true;
        merged.addAll(result.orders);
      } else if (result.error != null) {
        lastError = result.error;
      } else {
        anySuccess = true;
      }
    }

    if (!anySuccess) {
      throw Exception(lastError ?? 'Impossible de charger les commandes admin.');
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<Map<String, dynamic>?> fetchAdminDashboardStats() async {
    final backends = await _sessionBackends();
    if (backends.isEmpty) return null;

    int totalOrders = 0;
    int confirmedOrders = 0;
    var anyStats = false;

    for (final backend in backends) {
      final token = await StoreApiBridge.instance.getJwt(backend.id!);
      if (token == null) continue;

      final session = await StoreApiBridge.instance.resolveAdminSession(
        backendId: backend.id!,
        backend: backend,
        token: token,
      );
      final managerStoreId = await StoreApiBridge.instance.resolveManagerStoreId(
        backendId: backend.id!,
        backend: backend,
        token: token,
        session: session,
      );
      final url = BackendAdminApi.adminStatsUrl(
        backend: backend,
        session: session,
        managerStoreId: managerStoreId,
      );
      if (url == null) continue;

      try {
        final res = await StoreApiBridge.instance.dio.get<dynamic>(
          url,
          options: Options(
            headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
          ),
        );
        if (res.statusCode == 200 && res.data is Map) {
          anyStats = true;
          final map = Map<String, dynamic>.from(res.data as Map);
          totalOrders += (map['totalOrders'] as num?)?.toInt() ?? 0;
          confirmedOrders += (map['confirmedOrders'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}
    }

    if (!anyStats) return null;
    return {
      'totalOrders': totalOrders,
      'confirmedOrders': confirmedOrders,
    };
  }

  Future<List<Order>> fetchAvailableOrders() async {
    if (await _useLocalOrders()) {
      return OrdersDao.instance.getAvailableOrders();
    }
    return _fetchDeliveryList('/api/delivery/orders');
  }

  Future<List<Order>> fetchMyOrders() async {
    if (await _useLocalOrders()) {
      final userId = await AuthService.instance.getCurrentUserId();
      if (userId == null) {
        throw Exception('Session expirée. Reconnectez-vous.');
      }
      return OrdersDao.instance.getMyOrders(userId);
    }
    return _fetchDeliveryList('/api/delivery/orders/my-orders');
  }

  /// Livraisons terminées par le livreur connecté (historique personnel).
  Future<List<Order>> fetchDeliveryHistory({int size = 200}) async {
    if (await _useLocalOrders()) {
      final userId = await AuthService.instance.getCurrentUserId();
      if (userId == null) {
        throw Exception('Session expirée. Reconnectez-vous.');
      }
      return OrdersDao.instance.getDeliveryHistory(userId);
    }
    return _fetchDeliveryList(
      '/api/delivery/orders/history',
      size: size,
      sort: 'updatedAt,desc',
    );
  }

  Future<bool> _useLocalOrders() async {
    if (await AuthService.instance.isLocalOnlySession()) return true;
    final backends = await _sessionBackends();
    return backends.isEmpty;
  }

  Future<List<Order>> _fetchDeliveryList(
    String path, {
    int size = 200,
    String? sort,
  }) async {
    final backends = await _sessionBackends();
    if (backends.isEmpty) {
      throw Exception('Aucun serveur connecté. Reconnectez-vous.');
    }

    final query = <String>[
      if (size > 0) 'size=$size',
      if (sort != null && sort.isNotEmpty) 'sort=$sort',
    ];
    final pathWithQuery = query.isEmpty ? path : '$path?${query.join('&')}';

    final merged = <Order>[];
    Object? lastError;

    for (final backend in backends) {
      final token = await StoreApiBridge.instance.getJwt(backend.id!);
      if (token == null) continue;
      try {
        final res = await StoreApiBridge.instance.dio.get<dynamic>(
          '${backend.origin}$pathWithQuery',
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

    merged.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt;
      final bDate = b.updatedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
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
    if (await _useLocalOrders()) {
      final userId = await AuthService.instance.getCurrentUserId();
      if (userId == null) {
        throw Exception('Session expirée. Reconnectez-vous.');
      }
      await OrdersDao.instance.claimOrderLocal(order.id, userId);
      final updated = await OrdersDao.instance.getOrderById(order.id);
      if (updated == null) {
        throw Exception('Commande introuvable.');
      }
      return updated;
    }

    final backend = await _backendForOrder(order);
    return StoreApiBridge.instance.claimDeliveryOrder(
      backend: backend,
      storeOrderId: order.id,
    );
  }

  Future<void> completeDelivery(Order order, String code) async {
    if (await _useLocalOrders()) {
      final expected = order.confirmationCode?.trim() ?? '';
      if (expected.isNotEmpty && expected != code.trim()) {
        throw Exception('Code de confirmation incorrect.');
      }
      await OrdersDao.instance.completeOrderLocal(order.id);
      return;
    }

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
