import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/driver_earnings_service.dart';
import '../../utils/delivery_earnings.dart';
import '../../widgets/delivery_earnings_tile.dart';
import '../../widgets/driver_earnings_summary_card.dart';
import '../../widgets/earnings_date_bar.dart';
import 'admin_order_detail.dart';

class AdminDriverEarningsScreen extends StatefulWidget {
  final UserModel driver;

  const AdminDriverEarningsScreen({super.key, required this.driver});

  @override
  State<AdminDriverEarningsScreen> createState() => _AdminDriverEarningsScreenState();
}

class _AdminDriverEarningsScreenState extends State<AdminDriverEarningsScreen> {
  late DateTime _selectedDate;
  String _deliveryTypeFilter = 'ALL';

  static const _typeFilters = [
    ('ALL', 'Tous types'),
    ('STANDARD', 'Standard'),
    ('EXPRESS', 'Express'),
    ('PROGRAMMER', 'Programmée'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final primary = Theme.of(context).colorScheme.primary;
    final driver = widget.driver;

    final summary = DriverEarningsService.instance.summarizeDriverDay(
      admin.orders,
      driver,
      _selectedDate,
      deliveryTypeFilter: _deliveryTypeFilter,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Livraisons & gains', style: TextStyle(fontSize: 16)),
            Text(
              driver.displayName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: admin.loadOrders,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (driver.backendName != null && driver.backendName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.cloud_outlined, size: 16, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      driver.backendName!,
                      style: TextStyle(fontSize: 12, color: primary),
                    ),
                  ],
                ),
              ),
            EarningsDateBar(
              selectedDate: _selectedDate,
              onDateChanged: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _typeFilters.map((f) {
                  final selected = _deliveryTypeFilter == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: selected,
                      onSelected: (_) => setState(() => _deliveryTypeFilter = f.$1),
                      selectedColor: primary.withValues(alpha: 0.15),
                      checkmarkColor: primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? primary : const Color(0xFF6B7280),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            DriverEarningsSummaryCard(
              deliveryCount: summary.deliveryCount,
              totalGain: summary.totalGain,
              subtitle: formatDisplayDate(_selectedDate),
            ),
            const SizedBox(height: 20),
            Text(
              'Livraisons du ${formatDisplayDate(_selectedDate)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            if (summary.orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: const Center(
                  child: Text(
                    'Aucune livraison pour ce livreur à cette date.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ),
              )
            else
              ...summary.orders.map(
                (order) => DeliveryEarningsTile(
                  order: order,
                  showTimeOnly: true,
                  onTap: () => showAdminOrderDetail(context, order),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
