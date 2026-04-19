import '../database/orders_dao.dart';
import '../models/order_model.dart';
import 'auth_service.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  OrdersDao get _dao => OrdersDao.instance;

  Future<List<Order>> fetchAvailableOrders() async =>
      _dao.getAvailableOrders();

  Future<List<Order>> fetchMyOrders() async {
    final userId = await AuthService.instance.getCurrentUserId();
    return _dao.getMyOrders(userId ?? 0);
  }

  Future<void> claimOrder(int orderId) async {
    final userId = await AuthService.instance.getCurrentUserId();
    await _dao.claimOrderLocal(orderId, userId);
  }

  Future<void> completeDelivery(int orderId, String code) async {
    final order = await _dao.getOrderById(orderId);

    // Vérifie le code de confirmation si défini
    if (order != null &&
        order.confirmationCode != null &&
        order.confirmationCode!.isNotEmpty &&
        order.confirmationCode != code) {
      throw Exception('Code de validation incorrect');
    }

    await _dao.completeOrderLocal(orderId);
  }
}
