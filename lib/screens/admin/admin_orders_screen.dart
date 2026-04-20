import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/admin_provider.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _filter = 'ALL';

  static const _filters = [
    ('ALL', 'Toutes'),
    ('CONFIRMED', 'En attente'),
    ('SHIPPED', 'En livraison'),
    ('DELIVERED', 'Livrées'),
  ];

  List<Order> _filtered(List<Order> orders) {
    if (_filter == 'ALL') return orders;
    return orders.where((o) => o.status == _filter).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED': return const Color(0xFFF59E0B);
      case 'SHIPPED':
      case 'CLAIMED':   return const Color(0xFF3B82F6);
      case 'DELIVERED': return const Color(0xFF10B981);
      default:          return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'CONFIRMED': return 'En attente';
      case 'SHIPPED':   return 'En livraison';
      case 'CLAIMED':   return 'Prise en charge';
      case 'DELIVERED': return 'Livrée';
      default:          return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final list  = _filtered(admin.orders);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ── Info synchronisation ─────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_sync_outlined,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Les commandes sont importées automatiquement (webhooks et intégrations). '
                    'Aucune saisie manuelle n\'est nécessaire.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Filtres ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final isActive = _filter == f.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        f.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Liste ──────────────────────────────────────────────────────
          Expanded(
            child: admin.isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune commande',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: admin.loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final order = list[i];
                            final color = _statusColor(order.status);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF3F4F6)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text(
                                            '#${order.orderNumber}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              order.sourcePlatform,
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ]),
                                        const SizedBox(height: 2),
                                        Text(
                                          order.customerName,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B7280)),
                                        ),
                                        Text(
                                          order.customerAddress,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF9CA3AF)),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _statusLabel(order.status),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: color,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${order.total.toStringAsFixed(0)} F',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
