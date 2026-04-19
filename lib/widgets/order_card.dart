import 'package:flutter/material.dart';
import '../models/order_model.dart';

class OrderCard extends StatefulWidget {
  final Order order;
  final String mode; // 'available' | 'my-orders'
  final Future<void> Function(int id)? onClaim;
  final Future<void> Function(int id, String code)? onComplete;

  const OrderCard({
    super.key,
    required this.order,
    required this.mode,
    this.onClaim,
    this.onComplete,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  final TextEditingController _codeController = TextEditingController();
  bool    _isClaiming   = false;
  bool    _isCompleting = false;
  String? _codeError;

  static const Color _secondary  = Color(0xFF242021);
  static const Color _gray50     = Color(0xFFF9FAFB);
  static const Color _gray100    = Color(0xFFF3F4F6);
  static const Color _gray200    = Color(0xFFE5E7EB);
  static const Color _gray400    = Color(0xFF9CA3AF);
  static const Color _gray500    = Color(0xFF6B7280);
  static const Color _gray600    = Color(0xFF4B5563);
  static const Color _gray900    = Color(0xFF111827);
  static const Color _blue50     = Color(0xFFEFF6FF);
  static const Color _blue100    = Color(0xFFDBEAFE);
  static const Color _blue600    = Color(0xFF2563EB);
  static const Color _green600   = Color(0xFF16A34A);
  static const Color _errorColor = Color(0xFFDC2626);

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  Future<void> _handleClaim() async {
    if (_isClaiming || widget.onClaim == null) return;
    setState(() => _isClaiming = true);
    try {
      await widget.onClaim!(widget.order.id);
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  Future<void> _handleComplete() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Entrez le code client');
      return;
    }
    if (_isCompleting || widget.onComplete == null) return;
    setState(() { _isCompleting = true; _codeError = null; });
    try {
      await widget.onComplete!(widget.order.id, code);
    } catch (e) {
      if (mounted) {
        setState(() => _codeError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          _buildHeader(primary),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCustomerInfo(),
                if (widget.order.customerNotes?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _buildNotes(),
                ],
                const SizedBox(height: 14),
                if (widget.mode == 'available') _buildAcceptButton(primary),
                if (widget.mode == 'my-orders') _buildMyOrderActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color primary) {
    final order = widget.order;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _gray50,
        border: Border(bottom: BorderSide(color: _gray100)),
      ),
      child: Row(
        children: [
          // Numéro de commande
          _Chip(
            text: '#${order.orderNumber}',
            bg: Colors.white,
            border: _gray200,
            textColor: _gray900,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          const SizedBox(width: 6),
          // Heure
          _Chip(
            text: _formatTime(order.createdAt),
            bg: _gray100,
            border: Colors.transparent,
            textColor: _gray500,
            fontWeight: FontWeight.w500,
            fontSize: 11,
            icon: Icons.access_time_outlined,
          ),
          // Source plateforme
          const SizedBox(width: 6),
          _Chip(
            text: order.sourcePlatform,
            bg: _blue50,
            border: _blue100,
            textColor: _blue600,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
          const Spacer(),
          // Distance (si disponible)
          if (order.distanceKm != null)
            _Chip(
              text: order.distanceKm! < 1
                  ? '${(order.distanceKm! * 1000).toStringAsFixed(0)} m'
                  : '${order.distanceKm!.toStringAsFixed(1)} km',
              bg: primary.withValues(alpha: 0.1),
              border: Colors.transparent,
              textColor: primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              icon: Icons.near_me,
            ),
          if (order.distanceKm != null) const SizedBox(width: 8),
          // Montant
          Text(
            '${order.total.toStringAsFixed(0)} F',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    final order = widget.order;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _blue50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.location_on, size: 20, color: _blue600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.customerAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _gray900,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 13, color: _gray500),
                  const SizedBox(width: 4),
                  Text(
                    order.customerName,
                    style: const TextStyle(fontSize: 12, color: _gray500),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.phone_outlined, size: 13, color: _gray500),
                  const SizedBox(width: 4),
                  Text(
                    order.customerPhone,
                    style: const TextStyle(fontSize: 12, color: _gray500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotes() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notes, size: 14, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.order.customerNotes!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptButton(Color primary) {
    return GestureDetector(
      onTap: _isClaiming ? null : _handleClaim,
      child: Opacity(
        opacity: _isClaiming ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _secondary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isClaiming)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              else ...[
                const Text('Accepter la course',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyOrderActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _gray50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gray100),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.call, size: 20, color: _gray600),
                    SizedBox(height: 4),
                    Text('Appeler',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _gray600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _blue50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _blue100),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.navigation, size: 20, color: _blue600),
                    SizedBox(height: 4),
                    Text('Y aller',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _blue600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gray50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gray100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('VALIDATION LIVRAISON',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _gray400,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _codeError != null ? _errorColor : _gray200,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _secondary,
                              letterSpacing: 2,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Code (ex: 1234)',
                              hintStyle: TextStyle(
                                color: _gray400,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                              ),
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_codeError != null) ...[
                          const SizedBox(height: 4),
                          Text(_codeError!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: _errorColor,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isCompleting ? null : _handleComplete,
                    child: Opacity(
                      opacity: _isCompleting ? 0.6 : 1.0,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _green600,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _green600.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: _isCompleting
                            ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle,
                                size: 26, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;
  final Color textColor;
  final FontWeight fontWeight;
  final double fontSize;
  final IconData? icon;

  const _Chip({
    required this.text,
    required this.bg,
    required this.border,
    required this.textColor,
    required this.fontWeight,
    required this.fontSize,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: textColor)),
        ],
      ),
    );
  }
}
