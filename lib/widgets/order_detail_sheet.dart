import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_model.dart';
import '../services/public_settings_service.dart';

/// Affiche les détails complets d'une commande (bottom sheet).
Future<void> showOrderDetailSheet(
  BuildContext context,
  Order order, {
  String mode = 'view',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _OrderDetailSheet(order: order, mode: mode),
  );
}

class _OrderDetailSheet extends StatefulWidget {
  final Order order;
  final String mode;

  const _OrderDetailSheet({required this.order, required this.mode});

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  Map<String, String> _settings = const {};

  static const _gray50 = Color(0xFFF9FAFB);
  static const _gray100 = Color(0xFFF3F4F6);
  static const _gray200 = Color(0xFFE5E7EB);
  static const _gray500 = Color(0xFF6B7280);
  static const _gray600 = Color(0xFF4B5563);
  static const _gray900 = Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final s = await PublicSettingsService.instance.fetchForOrder(
        backendId: widget.order.backendId,
        storeCode: widget.order.store?.code,
      );
      if (!mounted) return;
      setState(() => _settings = s);
    } catch (_) {}
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final d = '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
      final t = '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
      return '$d à $t';
    } catch (_) {
      return iso;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'CONFIRMED':
        return 'En attente';
      case 'REJECTED':
        return 'Rejetée';
      case 'SHIPPED':
        return 'En livraison';
      case 'CLAIMED':
        return 'Prise en charge';
      case 'DELIVERED':
        return 'Livrée';
      case 'CANCELLED':
        return 'Annulée';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return const Color(0xFFF59E0B);
      case 'REJECTED':
        return const Color(0xFFEF4444);
      case 'SHIPPED':
      case 'CLAIMED':
        return const Color(0xFF3B82F6);
      case 'DELIVERED':
        return const Color(0xFF10B981);
      default:
        return _gray500;
    }
  }

  String _deliveryTypeLabel(String? raw) {
    final type = (raw ?? '').toUpperCase();
    if (type == 'EXPRESS') return 'Livraison Express';
    if (type == 'PROGRAMMER') return 'Livraison Programmée';
    if (type == 'STANDARD') return 'Livraison Standard';
    return raw?.trim().isNotEmpty == true ? raw!.trim() : '—';
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception("Impossible d'ouvrir le lien");
  }

  Future<void> _callPhone(String phone) async {
    final p = phone.replaceAll(' ', '');
    if (p.isEmpty) return;
    await _launch(Uri(scheme: 'tel', path: p));
  }

  Future<void> _openCustomerMap() async {
    final o = widget.order;
    if (o.customerLatitude != null && o.customerLongitude != null) {
      await _launch(Uri.parse(
        'https://www.google.com/maps/search/?api=1&query='
        '${o.customerLatitude},${o.customerLongitude}',
      ));
      return;
    }
    final link = o.manualLocationLink?.trim();
    if (link != null && link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        await _launch(uri);
        return;
      }
    }
    if (o.customerAddress.trim().isNotEmpty) {
      await _launch(Uri.parse(
        'https://www.google.com/maps/search/?api=1&query='
        '${Uri.encodeComponent(o.customerAddress)}',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final primary = Theme.of(context).colorScheme.primary;
    final pickup = order.pickupInfo(_settings);
    final statusColor = _statusColor(order.status);
    final agent = order.deliveryAgent;
    final agentName = agent == null
        ? null
        : [
            agent['firstName']?.toString(),
            agent['lastName']?.toString(),
            agent['username']?.toString(),
          ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Commande #${order.orderNumber}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _gray900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(order.createdAt),
                            style: const TextStyle(fontSize: 12, color: _gray500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(order.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: _gray500),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _gray100),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    if (order.backendName != null && order.backendName!.isNotEmpty)
                      _section(
                        title: 'SERVEUR',
                        child: _infoRow(Icons.dns_outlined, order.backendName!),
                      ),
                    _section(
                      title: 'BOUTIQUE',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.store_outlined, pickup.name),
                          if (pickup.phone.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _actionChip(
                              icon: Icons.phone_outlined,
                              label: pickup.phone,
                              onTap: () => _callPhone(pickup.phone),
                            ),
                          ],
                          if (pickup.location.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              pickup.location,
                              style: const TextStyle(fontSize: 13, color: _gray600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _section(
                      title: 'CLIENT',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.person_outline, order.customerName),
                          const SizedBox(height: 8),
                          _actionChip(
                            icon: Icons.phone_outlined,
                            label: order.customerPhone,
                            onTap: () => _callPhone(order.customerPhone),
                          ),
                          const SizedBox(height: 10),
                          _infoRow(Icons.location_on_outlined, order.customerAddress),
                          if (order.customerAddress.trim().isNotEmpty ||
                              order.customerLatitude != null) ...[
                            const SizedBox(height: 8),
                            _actionChip(
                              icon: Icons.map_outlined,
                              label: 'Ouvrir dans Maps',
                              onTap: _openCustomerMap,
                            ),
                          ],
                          if (order.customerNotes?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                order.customerNotes!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _section(
                      title: 'LIVRAISON',
                      child: Column(
                        children: [
                          _detailLine('Type', _deliveryTypeLabel(order.deliveryType)),
                          if (order.scheduledTime?.trim().isNotEmpty == true)
                            _detailLine('Horaire prévu', order.scheduledTime!),
                          if (order.deliveryCost != null)
                            _detailLine(
                              'Frais livraison',
                              '${order.deliveryCost!.toStringAsFixed(0)} F',
                            ),
                          if (order.distanceKm != null)
                            _detailLine(
                              'Distance',
                              order.distanceKm! < 1
                                  ? '${(order.distanceKm! * 1000).toStringAsFixed(0)} m'
                                  : '${order.distanceKm!.toStringAsFixed(1)} km',
                            ),
                          if (agentName != null && agentName.isNotEmpty)
                            _detailLine('Livreur', agentName),
                        ],
                      ),
                    ),
                    _section(
                      title: 'ARTICLES',
                      child: order.items.isEmpty
                          ? const Text(
                              'Aucun article détaillé pour cette commande.',
                              style: TextStyle(fontSize: 13, color: _gray500),
                            )
                          : Column(
                              children: [
                                for (final item in order.items) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: _gray50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _gray100),
                                          ),
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: _gray900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.productName.isNotEmpty
                                                    ? item.productName
                                                    : 'Produit #${item.id}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: _gray900,
                                                ),
                                              ),
                                              if (item.unitPrice > 0)
                                                Text(
                                                  '${item.unitPrice.toStringAsFixed(0)} F × ${item.quantity}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: _gray500,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${(item.total > 0 ? item.total : item.unitPrice * item.quantity).toStringAsFixed(0)} F',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    _section(
                      title: 'MONTANTS',
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _gray50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _gray100),
                        ),
                        child: Column(
                          children: [
                            if (order.subtotal > 0)
                              _detailLine('Sous-total', '${order.subtotal.toStringAsFixed(0)} F'),
                            if (order.tax > 0)
                              _detailLine('Taxes', '${order.tax.toStringAsFixed(0)} F'),
                            if (order.deliveryCost != null && order.deliveryCost! > 0)
                              _detailLine(
                                'Livraison',
                                '${order.deliveryCost!.toStringAsFixed(0)} F',
                              ),
                            const Divider(height: 16, color: _gray200),
                            _detailLine(
                              'Total',
                              '${order.total.toStringAsFixed(0)} F',
                              valueStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _gray500,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _gray500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _gray900,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailLine(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: _gray500)),
          ),
          Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _gray900,
                ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
