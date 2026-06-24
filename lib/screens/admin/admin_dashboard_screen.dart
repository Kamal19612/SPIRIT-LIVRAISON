import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../services/driver_earnings_service.dart';
import '../../utils/delivery_earnings.dart';
import '../../widgets/driver_earnings_charts.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static const Color _gray500 = Color(0xFF6B7280);
  static const Color _gray900 = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final weekGain = DriverEarningsService.instance.totalGainLastDays(admin.orders, days: 7);

    if (admin.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: admin.loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (admin.error != null || admin.driversError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        if (admin.error != null) admin.error!,
                        if (admin.driversError != null) admin.driversError!,
                      ].join('\n'),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              _StatCard(
                label: 'Commandes',
                value: '${admin.totalOrders}',
                icon: Icons.receipt_long,
                color: primary,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'En attente',
                value: '${admin.pendingOrders}',
                icon: Icons.hourglass_top,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Livreurs actifs',
                value: '${admin.activeDrivers}',
                icon: Icons.delivery_dining,
                color: const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.payments_outlined, color: primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatGainAmount(weekGain),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                      const Text(
                        'Gains livreurs (7 derniers jours)',
                        style: TextStyle(fontSize: 11, color: _gray500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Performance livreurs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _gray900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Basé sur les frais de livraison des commandes livrées',
            style: TextStyle(fontSize: 12, color: _gray500),
          ),
          const SizedBox(height: 12),

          AdminDriverEarningsCharts(orders: admin.orders),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            ),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
