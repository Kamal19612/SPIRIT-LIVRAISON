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

  void _showAddOrderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddOrderSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final list  = _filtered(admin.orders);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOrderDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle commande'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Bottom Sheet : Créer une commande ───────────────────────────────────────

class _AddOrderSheet extends StatefulWidget {
  const _AddOrderSheet();

  @override
  State<_AddOrderSheet> createState() => _AddOrderSheetState();
}

class _AddOrderSheetState extends State<_AddOrderSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _addrCtrl   = TextEditingController();
  final _latCtrl    = TextEditingController();
  final _lngCtrl    = TextEditingController();
  final _totalCtrl  = TextEditingController();
  final _codeCtrl   = TextEditingController();
  bool _isSaving    = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _addrCtrl.dispose();
    _latCtrl.dispose(); _lngCtrl.dispose();
    _totalCtrl.dispose(); _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _error = null; });
    try {
      await context.read<AdminProvider>().createOrder(
        customerName:      _nameCtrl.text.trim(),
        customerPhone:     _phoneCtrl.text.trim(),
        customerAddress:   _addrCtrl.text.trim(),
        customerLatitude:  double.tryParse(_latCtrl.text.trim()),
        customerLongitude: double.tryParse(_lngCtrl.text.trim()),
        total:             double.parse(_totalCtrl.text.trim().replaceAll(',', '.')),
        confirmationCode:  _codeCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nouvelle commande',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                ),
              _Field(ctrl: _nameCtrl,  label: 'Nom client *',     hint: 'Jean Dupont'),
              _Field(ctrl: _phoneCtrl, label: 'Téléphone *',      hint: '+224 6XX XXX XXX'),
              _Field(ctrl: _addrCtrl,  label: 'Adresse livraison *', hint: 'Kaloum, Conakry'),
              Row(children: [
                Expanded(child: _Field(ctrl: _latCtrl, label: 'Latitude', hint: '9.5370', keyboardType: TextInputType.number, required: false)),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _lngCtrl, label: 'Longitude', hint: '-13.677', keyboardType: TextInputType.number, required: false)),
              ]),
              _Field(ctrl: _totalCtrl, label: 'Montant total (F) *', hint: '50000', keyboardType: TextInputType.number),
              _Field(ctrl: _codeCtrl,  label: 'Code de validation', hint: '1234 (optionnel)', required: false),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer la commande',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final bool required;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null
            : null,
      ),
    );
  }
}
