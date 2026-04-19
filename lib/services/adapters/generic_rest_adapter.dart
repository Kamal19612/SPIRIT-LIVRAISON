import 'package:dio/dio.dart';
import '../../models/external_source_model.dart';
import '../../models/order_model.dart';

/// Fetches and normalizes orders from any REST API without platform-specific code.
/// Uses auto-detection of JSON field names, with optional fieldMapping overrides.
class GenericRestAdapter {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  // ── Auto-detection candidate lists ─────────────────────────────────────────

  static const _candidatesOrderNumber = ['id', 'order_id', 'orderNumber',
      'order_number', 'ref', 'reference', 'ref_cmd', 'numero'];
  static const _candidatesCustomerName = ['customer_name', 'customerName',
      'client', 'name', 'full_name', 'nom', 'customer', 'buyer'];
  static const _candidatesCustomerPhone = ['phone', 'telephone', 'mobile',
      'customer_phone', 'customerPhone', 'tel', 'contact'];
  static const _candidatesCustomerAddress = ['address', 'delivery_address',
      'customerAddress', 'adresse', 'livraison', 'shipping_address', 'location'];
  static const _candidatesTotal = ['total', 'amount', 'price', 'montant',
      'total_price', 'order_total', 'grand_total'];
  static const _candidatesStatus = ['status', 'etat', 'state', 'order_status'];
  static const _candidatesLat = ['lat', 'latitude', 'customer_lat', 'delivery_lat'];
  static const _candidatesLng = ['lng', 'lon', 'longitude', 'customer_lng', 'delivery_lng'];

  // ── HTTP fetch ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchRawOrders(ExternalSource source) async {
    final options = Options(headers: {});

    switch (source.authType) {
      case 'bearer':
        options.headers!['Authorization'] = 'Bearer ${source.apiKey}';
        break;
      case 'api_key_header':
        options.headers!['X-API-Key'] = source.apiKey;
        break;
      case 'basic':
        // apiKey stored as "user:password" base64
        options.headers!['Authorization'] = 'Basic ${source.apiKey}';
        break;
      // 'query_param' and 'none' handled below
    }

    String url = source.url;
    if (source.authType == 'query_param' && source.apiKey.isNotEmpty) {
      final separator = url.contains('?') ? '&' : '?';
      url = '$url${separator}api_key=${Uri.encodeQueryComponent(source.apiKey)}';
    }

    final response = await _dio.get<dynamic>(url, options: options);
    final body = response.data;

    // Navigate to the list using dot-notation response path (e.g. "data.orders")
    dynamic data = body;
    if (source.responsePath.isNotEmpty) {
      for (final key in source.responsePath.split('.')) {
        if (data is Map) {
          data = data[key];
        } else {
          data = null;
          break;
        }
      }
    }

    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      // Single object wrapped — treat as one order
      return [data];
    }
    return [];
  }

  // ── Normalization ───────────────────────────────────────────────────────────

  Order normalizeOrder(
    Map<String, dynamic> raw,
    Map<String, String> fieldMapping,
    String sourceName,
  ) {
    String resolve(String canonical, List<String> candidates) {
      // 1) explicit mapping
      if (fieldMapping.containsKey(canonical)) {
        final key = fieldMapping[canonical]!;
        return _deepGet(raw, key)?.toString() ?? '';
      }
      // 2) auto-detect
      for (final key in candidates) {
        final val = raw[key];
        if (val != null && val.toString().isNotEmpty) return val.toString();
      }
      // 3) look inside nested objects (one level deep)
      for (final v in raw.values) {
        if (v is Map<String, dynamic>) {
          for (final key in candidates) {
            final nested = v[key];
            if (nested != null && nested.toString().isNotEmpty) return nested.toString();
          }
        }
      }
      return '';
    }

    double resolveDouble(String canonical, List<String> candidates) {
      final s = resolve(canonical, candidates);
      return double.tryParse(s) ?? 0.0;
    }

    final externalId = resolve('orderNumber', _candidatesOrderNumber);
    final orderNumber = '$sourceName-$externalId';

    // Deterministic int id: djb2 hash of orderNumber (always positive, fits int)
    int hash = 5381;
    for (final c in orderNumber.codeUnits) {
      hash = ((hash << 5) + hash + c) & 0x7FFFFFFF;
    }

    return Order(
      id: hash,
      orderNumber: orderNumber,
      customerName: resolve('customerName', _candidatesCustomerName),
      customerPhone: resolve('customerPhone', _candidatesCustomerPhone),
      customerAddress: resolve('customerAddress', _candidatesCustomerAddress),
      customerLatitude: () {
        final s = resolve('lat', _candidatesLat);
        return s.isEmpty ? null : double.tryParse(s);
      }(),
      customerLongitude: () {
        final s = resolve('lng', _candidatesLng);
        return s.isEmpty ? null : double.tryParse(s);
      }(),
      subtotal: resolveDouble('total', _candidatesTotal),
      tax: 0,
      total: resolveDouble('total', _candidatesTotal),
      status: _mapStatus(resolve('status', _candidatesStatus)),
      createdAt: DateTime.now().toIso8601String(),
      sourcePlatform: sourceName,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Navigate dot-notation path like "customer.name" inside a map.
  dynamic _deepGet(Map<String, dynamic> map, String path) {
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

  String _mapStatus(String raw) {
    final lower = raw.toLowerCase();
    if (['confirmed', 'pending', 'new', 'created', 'open'].any((s) => lower.contains(s))) {
      return 'CONFIRMED';
    }
    if (['shipped', 'in_transit', 'dispatched', 'en route'].any((s) => lower.contains(s))) {
      return 'SHIPPED';
    }
    if (['delivered', 'completed', 'done', 'livré'].any((s) => lower.contains(s))) {
      return 'DELIVERED';
    }
    if (['cancelled', 'canceled', 'annulé'].any((s) => lower.contains(s))) {
      return 'CANCELLED';
    }
    return 'CONFIRMED';
  }
}
