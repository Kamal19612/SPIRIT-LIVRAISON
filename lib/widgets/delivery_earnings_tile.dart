import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../utils/delivery_earnings.dart';

/// Tuile historique avec gain livreur (deliveryCost).
class DeliveryEarningsTile extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final bool showTimeOnly;

  const DeliveryEarningsTile({
    super.key,
    required this.order,
    this.onTap,
    this.showTimeOnly = false,
  });

  static const _gray100 = Color(0xFFF3F4F6);
  static const _gray500 = Color(0xFF6B7280);
  static const _gray900 = Color(0xFF111827);
  static const _green600 = Color(0xFF16A34A);

  String _formatDateTime() {
    final at = orderDeliveredAt(order);
    if (at == null) return '—';
    if (showTimeOnly) return formatDeliveredTime(order);
    return '${at.day.toString().padLeft(2, '0')}/'
        '${at.month.toString().padLeft(2, '0')}/'
        '${at.year} · ${formatDeliveredTime(order)}';
  }

  String? _deliveryTypeLabel() {
    final t = (order.deliveryType ?? '').toUpperCase();
    if (t == 'EXPRESS') return '⚡ Express';
    if (t == 'PROGRAMMER') return '🕐 Programmée';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final gain = driverGain(order);
    final typeLabel = _deliveryTypeLabel();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gray100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _green600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_outlined, color: _green600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _gray900,
                          ),
                        ),
                        if (order.backendName != null && order.backendName!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _gray100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.backendName!,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: _gray500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.customerName,
                      style: const TextStyle(fontSize: 13, color: _gray500),
                    ),
                    if (order.customerAddress.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        order.customerAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _formatDateTime(),
                          style: const TextStyle(fontSize: 11, color: _gray500),
                        ),
                        if (typeLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(typeLabel, style: const TextStyle(fontSize: 10, color: _gray500)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatGainAmount(gain),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: gain > 0 ? primary : _gray500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'gain livraison',
                    style: TextStyle(fontSize: 10, color: _gray500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cmd. ${order.total.toStringAsFixed(0)} F',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
