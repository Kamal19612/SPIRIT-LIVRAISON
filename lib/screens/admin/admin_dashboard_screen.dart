import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/order_model.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static const Color _gray100 = Color(0xFFF3F4F6);
  static const Color _gray500 = Color(0xFF6B7280);
  static const Color _gray900 = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final primary = Theme.of(context).colorScheme.primary;

    if (admin.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final recent = admin.orders.take(5).toList();

    return RefreshIndicator(
      onRefresh: admin.loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stats ──────────────────────────────────────────────────────
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
          const SizedBox(height: 24),

          // ── Commandes récentes ─────────────────────────────────────────
          const Text(
            'Commandes récentes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _gray900,
            ),
          ),
          const SizedBox(height: 12),

          if (recent.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gray100),
              ),
              child: const Center(
                child: Text(
                  'Aucune commande pour le moment',
                  style: TextStyle(color: _gray500, fontSize: 14),
                ),
              ),
            )
          else
            ...recent.map((order) => _RecentOrderTile(order: order)),
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

class _RecentOrderTile extends StatelessWidget {
  final Order order;
  const _RecentOrderTile({required this.order});

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return const Color(0xFFF59E0B);
      case 'SHIPPED':
      case 'CLAIMED':
        return const Color(0xFF3B82F6);
      case 'DELIVERED':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'CONFIRMED':  return 'En attente';
      case 'SHIPPED':    return 'En livraison';
      case 'CLAIMED':    return 'Prise en charge';
      case 'DELIVERED':  return 'Livrée';
      default:           return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.orderNumber}  •  ${order.customerName}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827)),
                ),
                const SizedBox(height: 2),
                Text(
                  order.customerAddress,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(order.status),
                  style: TextStyle(
                      fontSize: 10, color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.total.toStringAsFixed(0)} F',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
