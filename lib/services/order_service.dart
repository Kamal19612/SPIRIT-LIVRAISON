import '../models/order_model.dart';
import 'supabase_app_client.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  Future<List<Order>> fetchAvailableOrders() async =>
      _fetchFromRpc('delivery_available_orders');

  Future<List<Order>> fetchMyOrders() async {
    return _fetchFromRpc('delivery_my_orders');
  }

  Future<void> claimOrder(int orderId) async {
    final client = await SupabaseAppClient.instance.client();
    await client.rpc('delivery_claim_order', params: {'p_order_id': orderId});
  }

  Future<void> completeDelivery(int orderId, String code) async {
    final client = await SupabaseAppClient.instance.client();
    await client.rpc(
      'delivery_complete_order',
      params: {'p_order_id': orderId, 'p_code': code.trim()},
    );
  }

  Future<List<Order>> _fetchFromRpc(String fn) async {
    final client = await SupabaseAppClient.instance.client();
    final res = await client.rpc(fn);
    if (res is! List) return [];
    return res
        .whereType<Map>()
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
