import '../models/order_model.dart';
import '../models/user_model.dart';

/// Gain livreur = frais de livraison facturés au client.
double driverGain(Order order) => order.deliveryCost ?? 0.0;

String formatGainAmount(double amount) {
  if (amount <= 0) return 'Gratuit';
  return '${amount.toStringAsFixed(0)} F';
}

DateTime? parseOrderDateTime(String? iso) {
  if (iso == null || iso.trim().isEmpty) return null;
  try {
    return DateTime.parse(iso).toLocal();
  } catch (_) {
    return null;
  }
}

/// Date de fin de livraison (priorité updatedAt).
DateTime? orderDeliveredAt(Order order) =>
    parseOrderDateTime(order.updatedAt) ?? parseOrderDateTime(order.createdAt);

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isDeliveredOnDate(Order order, DateTime day) {
  if (order.status != 'DELIVERED') return false;
  final at = orderDeliveredAt(order);
  if (at == null) return false;
  return isSameCalendarDay(at, day);
}

bool isDeliveredBetween(Order order, DateTime from, DateTime to) {
  if (order.status != 'DELIVERED') return false;
  final at = orderDeliveredAt(order);
  if (at == null) return false;
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
  return !at.isBefore(start) && !at.isAfter(end);
}

String agentUsername(Order order) =>
    order.deliveryAgent?['username']?.toString().trim().toLowerCase() ?? '';

bool orderMatchesDriver(Order order, UserModel driver) {
  if (order.status != 'DELIVERED') return false;
  final agent = agentUsername(order);
  final driverLogin = driver.username.trim().toLowerCase();
  if (agent.isEmpty || driverLogin.isEmpty) return false;
  if (agent != driverLogin) return false;
  if (driver.backendId != null && order.backendId != null) {
    return order.backendId == driver.backendId;
  }
  return true;
}

List<Order> filterDeliveredOnDate(List<Order> orders, DateTime day) =>
    orders.where((o) => isDeliveredOnDate(o, day)).toList();

List<Order> ordersForDriverOnDate(
  List<Order> all,
  UserModel driver,
  DateTime day, {
  String? deliveryTypeFilter,
}) {
  final type = deliveryTypeFilter?.trim().toUpperCase();
  return all.where((o) {
    if (!orderMatchesDriver(o, driver)) return false;
    if (!isDeliveredOnDate(o, day)) return false;
    if (type != null && type.isNotEmpty && type != 'ALL') {
      final dt = (o.deliveryType ?? 'STANDARD').toUpperCase();
      return dt == type;
    }
    return true;
  }).toList()
    ..sort((a, b) {
      final da = orderDeliveredAt(a);
      final db = orderDeliveredAt(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
}

double sumGains(Iterable<Order> orders) =>
    orders.fold(0.0, (sum, o) => sum + driverGain(o));

String formatDeliveredTime(Order order) {
  final at = orderDeliveredAt(order);
  if (at == null) return '—';
  return '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

String formatDisplayDate(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(day.year, day.month, day.day);
  if (target == today) return "Aujourd'hui";
  if (target == today.subtract(const Duration(days: 1))) return 'Hier';
  return '${day.day.toString().padLeft(2, '0')}/'
      '${day.month.toString().padLeft(2, '0')}/'
      '${day.year}';
}
