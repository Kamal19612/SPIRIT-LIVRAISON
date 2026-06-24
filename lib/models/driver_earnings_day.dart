import 'order_model.dart';

class DriverEarningsDay {
  final DateTime date;
  final List<Order> orders;
  final double totalGain;
  final int deliveryCount;

  const DriverEarningsDay({
    required this.date,
    required this.orders,
    required this.totalGain,
    required this.deliveryCount,
  });
}

class DriverEarningsSlice {
  final String label;
  final double gain;
  final int deliveryCount;

  const DriverEarningsSlice({
    required this.label,
    required this.gain,
    required this.deliveryCount,
  });
}

class DailyEarningsPoint {
  final DateTime date;
  final String shortLabel;
  final double gain;
  final int deliveryCount;

  const DailyEarningsPoint({
    required this.date,
    required this.shortLabel,
    required this.gain,
    required this.deliveryCount,
  });
}
