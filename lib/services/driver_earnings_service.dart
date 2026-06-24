import '../models/driver_earnings_day.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../utils/delivery_earnings.dart';

class DriverEarningsService {
  DriverEarningsService._();
  static final DriverEarningsService instance = DriverEarningsService._();

  static const _weekdayFr = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];

  DriverEarningsDay summarizeDay(List<Order> orders, DateTime day) {
    final list = filterDeliveredOnDate(orders, day);
    return DriverEarningsDay(
      date: DateTime(day.year, day.month, day.day),
      orders: list,
      totalGain: sumGains(list),
      deliveryCount: list.length,
    );
  }

  DriverEarningsDay summarizeDriverDay(
    List<Order> allOrders,
    UserModel driver,
    DateTime day, {
    String? deliveryTypeFilter,
  }) {
    final list = ordersForDriverOnDate(
      allOrders,
      driver,
      day,
      deliveryTypeFilter: deliveryTypeFilter,
    );
    return DriverEarningsDay(
      date: DateTime(day.year, day.month, day.day),
      orders: list,
      totalGain: sumGains(list),
      deliveryCount: list.length,
    );
  }

  /// Top livreurs par gains sur [days] derniers jours (toutes commandes DELIVERED).
  List<DriverEarningsSlice> topDriversByGain(
    List<Order> orders, {
    int days = 7,
    int limit = 8,
  }) {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days - 1));
    final start = DateTime(from.year, from.month, from.day);

    final delivered = orders.where((o) {
      if (o.status != 'DELIVERED') return false;
      final at = orderDeliveredAt(o);
      if (at == null) return false;
      return !at.isBefore(start);
    });

    final byKey = <String, ({String label, double gain, int count})>{};

    for (final o in delivered) {
      final agent = o.deliveryAgent;
      if (agent == null) continue;
      final username = agent['username']?.toString().trim() ?? '';
      if (username.isEmpty) continue;
      final backend = o.backendName?.trim() ?? '';
      final key = '${o.backendId ?? 0}:$username';
      final label = backend.isNotEmpty ? '$username ($backend)' : username;
      final prev = byKey[key];
      final gain = driverGain(o);
      byKey[key] = (
        label: label,
        gain: (prev?.gain ?? 0) + gain,
        count: (prev?.count ?? 0) + 1,
      );
    }

    final slices = byKey.values
        .map(
          (e) => DriverEarningsSlice(
            label: e.label,
            gain: e.gain,
            deliveryCount: e.count,
          ),
        )
        .toList()
      ..sort((a, b) => b.gain.compareTo(a.gain));

    if (slices.length <= limit) return slices;
    return slices.sublist(0, limit);
  }

  /// Gains livreurs agrégés par jour sur [days] derniers jours.
  List<DailyEarningsPoint> dailyGainTrend(
    List<Order> orders, {
    int days = 7,
  }) {
    final now = DateTime.now();
    final points = <DailyEarningsPoint>[];

    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final list = filterDeliveredOnDate(orders, day);
      final wd = day.weekday - 1;
      points.add(
        DailyEarningsPoint(
          date: day,
          shortLabel: _weekdayFr[wd.clamp(0, 6)],
          gain: sumGains(list),
          deliveryCount: list.length,
        ),
      );
    }
    return points;
  }

  double totalGainLastDays(List<Order> orders, {int days = 7}) {
    final trend = dailyGainTrend(orders, days: days);
    return trend.fold(0.0, (s, p) => s + p.gain);
  }
}
