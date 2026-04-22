import 'package:flutter/foundation.dart';

/// État lisible côté UI pour l’abonnement Realtime `webhook_events`.
@immutable
class SupabaseRelayStatus {
  final bool configured;
  final SupabaseRelayPhase phase;
  final String headline;
  final String? detail;
  final DateTime? lastInsertAt;
  final int insertCount;

  const SupabaseRelayStatus({
    required this.configured,
    required this.phase,
    required this.headline,
    this.detail,
    this.lastInsertAt,
    this.insertCount = 0,
  });

  static const initial = SupabaseRelayStatus(
    configured: false,
    phase: SupabaseRelayPhase.off,
    headline: 'Realtime : pas encore démarré',
    detail: 'Lancez l’app après avoir enregistré l’URL et la clé dans Intégrations.',
  );

  SupabaseRelayStatus copyWith({
    bool? configured,
    SupabaseRelayPhase? phase,
    String? headline,
    String? detail,
    DateTime? lastInsertAt,
    int? insertCount,
    bool clearDetail = false,
  }) {
    return SupabaseRelayStatus(
      configured: configured ?? this.configured,
      phase: phase ?? this.phase,
      headline: headline ?? this.headline,
      detail: clearDetail ? null : (detail ?? this.detail),
      lastInsertAt: lastInsertAt ?? this.lastInsertAt,
      insertCount: insertCount ?? this.insertCount,
    );
  }
}

enum SupabaseRelayPhase {
  off,
  connecting,
  listening,
  error,
}
