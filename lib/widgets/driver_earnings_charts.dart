import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/driver_earnings_day.dart';
import '../models/order_model.dart';
import '../services/driver_earnings_service.dart';
import '../utils/delivery_earnings.dart';

/// Barres horizontales — top livreurs par gains (7 jours).
class DriverEarningsBarChart extends StatelessWidget {
  final List<DriverEarningsSlice> slices;

  const DriverEarningsBarChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (slices.isEmpty) {
      return _emptyCard(
        icon: Icons.bar_chart,
        message: 'Aucun gain livreur sur les 7 derniers jours',
      );
    }

    final maxGain = slices.map((s) => s.gain).reduce((a, b) => a > b ? a : b);
    final maxY = maxGain <= 0 ? 1.0 : maxGain;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top livreurs (7 jours)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gains = frais de livraison',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          ...slices.map((s) {
            final ratio = maxY > 0 ? (s.gain / maxY).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatGainAmount(s.gain),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF3F4F6),
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.deliveryCount} livraison${s.deliveryCount > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Courbe des gains livreurs agrégés par jour (7 jours).
class DriverEarningsTrendChart extends StatelessWidget {
  final List<DailyEarningsPoint> points;

  const DriverEarningsTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final hasData = points.any((p) => p.gain > 0 || p.deliveryCount > 0);
    if (!hasData) {
      return _emptyCard(
        icon: Icons.show_chart,
        message: 'Aucune livraison terminée sur la période',
      );
    }

    final maxGain = points.map((p) => p.gain).fold(0.0, (a, b) => a > b ? a : b);
    final maxY = maxGain <= 0 ? 1.0 : maxGain * 1.2;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gains livreurs par jour',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(
            'Total 7j : ${formatGainAmount(points.fold(0.0, (s, p) => s + p.gain))}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFF3F4F6),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || (maxY - value).abs() < 0.01) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= points.length) return const SizedBox.shrink();
                        return Text(
                          points[i].shortLabel,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].gain),
                    ],
                    isCurved: true,
                    color: primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 4,
                        color: primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 300),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF3F4F6)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

Widget _emptyCard({required IconData icon, required String message}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: _cardDecoration(),
    child: Column(
      children: [
        Icon(icon, size: 40, color: const Color(0xFFD1D5DB)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
      ],
    ),
  );
}

/// Widget combiné pour le dashboard admin.
class AdminDriverEarningsCharts extends StatelessWidget {
  final List<Order> orders;

  const AdminDriverEarningsCharts({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final svc = DriverEarningsService.instance;
    final top = svc.topDriversByGain(orders, days: 7);
    final trend = svc.dailyGainTrend(orders, days: 7);

    return Column(
      children: [
        DriverEarningsTrendChart(points: trend),
        const SizedBox(height: 16),
        DriverEarningsBarChart(slices: top),
      ],
    );
  }
}
