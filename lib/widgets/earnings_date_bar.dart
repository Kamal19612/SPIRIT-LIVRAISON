import 'package:flutter/material.dart';

import '../utils/delivery_earnings.dart';

/// Sélecteur de date réutilisable (admin livreur + historique livreur).
class EarningsDateBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const EarningsDateBar({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.firstDate,
    this.lastDate,
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate ?? DateTime(now.year - 2),
      lastDate: lastDate ?? now,
      helpText: 'Choisir une date',
      cancelText: 'Annuler',
      confirmText: 'OK',
    );
    if (picked != null) {
      onDateChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _shiftDay(int delta) {
    final next = selectedDate.add(Duration(days: delta));
    final now = DateTime.now();
    final last = lastDate ?? DateTime(now.year, now.month, now.day);
    final first = firstDate ?? DateTime(now.year - 2);
    if (next.isAfter(last) || next.isBefore(first)) return;
    onDateChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = isSameCalendarDay(selectedDate, today);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftDay(-1),
            icon: const Icon(Icons.chevron_left, size: 22),
            color: const Color(0xFF6B7280),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: InkWell(
              onTap: () => _pickDate(context),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      formatDisplayDate(selectedDate),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: isToday ? null : () => _shiftDay(1),
            icon: const Icon(Icons.chevron_right, size: 22),
            color: const Color(0xFF6B7280),
            visualDensity: VisualDensity.compact,
          ),
          if (!isToday)
            TextButton(
              onPressed: () => onDateChanged(today),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                "Auj.",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
