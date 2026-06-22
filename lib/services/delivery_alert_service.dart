import '../models/order_model.dart';
import 'notification_service.dart';

/// Alertes livreur pour nouvelles livraisons (SSE, FCM, polling local).
class DeliveryAlertService {
  DeliveryAlertService._();
  static final DeliveryAlertService instance = DeliveryAlertService._();

  static const _dedupeWindow = Duration(seconds: 45);
  final Map<String, DateTime> _recentAlerts = {};

  static String normalizeEventType(String type) =>
      type.trim().toLowerCase().replaceAll('-', '_');

  static bool isNewDeliveryEvent(String type) {
    final n = normalizeEventType(type);
    return n == 'new_delivery' || n == 'order_created';
  }

  /// Affiche une notification système (premier plan, arrière-plan ou veille).
  Future<void> alertNewDelivery({
    required String orderNumber,
    String? deliveryType,
  }) async {
    final key = orderNumber.isNotEmpty ? orderNumber : '#';
    final now = DateTime.now();
    final last = _recentAlerts[key];
    if (last != null && now.difference(last) < _dedupeWindow) return;
    _recentAlerts[key] = now;
    if (_recentAlerts.length > 50) {
      _recentAlerts.removeWhere(
        (_, t) => now.difference(t) > _dedupeWindow,
      );
    }

    await NotificationService.instance.showNewDeliveryNotification(
      orderNumber: key,
      deliveryType: deliveryType,
    );
  }

  Future<void> fromEventPayload(Map<String, dynamic> data) async {
    final orderNumber = data['orderNumber']?.toString() ??
        data['order_number']?.toString() ??
        data['id']?.toString() ??
        '#';
    final deliveryType =
        data['deliveryType']?.toString() ?? data['delivery_type']?.toString();
    await alertNewDelivery(orderNumber: orderNumber, deliveryType: deliveryType);
  }

  Future<void> fromOrder(Order order) async {
    await alertNewDelivery(
      orderNumber: order.orderNumber,
      deliveryType: order.deliveryType,
    );
  }
}
