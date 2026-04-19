import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../database/app_config_dao.dart';
import 'notification_service.dart';
import 'webhook_event_handler.dart';

/// Abonnement Realtime sur `public.webhook_events` (inserts du WebhookRelay).
class SupabaseRelayService {
  SupabaseRelayService._();
  static final SupabaseRelayService instance = SupabaseRelayService._();

  RealtimeChannel? _channel;
  bool _started = false;

  Future<void> startIfConfigured() async {
    if (_started) return;

    var url = SupabaseEnv.url;
    var anonKey = SupabaseEnv.anonKey;

    if (anonKey.isEmpty) {
      anonKey = await AppConfigDao.instance.getValue('supabase_anon_key') ?? '';
    }
    final urlOverride = await AppConfigDao.instance.getValue('supabase_url');
    if (urlOverride != null && urlOverride.isNotEmpty) {
      url = urlOverride;
    }

    if (url.isEmpty || anonKey.isEmpty) {
      debugPrint(
        'SupabaseRelayService: Realtime désactivé — renseignez SUPABASE_URL et '
        'SUPABASE_ANON_KEY (--dart-define) ou app_config (supabase_url / supabase_anon_key).',
      );
      return;
    }

    await Supabase.initialize(url: url, anonKey: anonKey);

    final client = Supabase.instance.client;
    _channel = client.channel('public_webhook_events');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'webhook_events',
      callback: _handlePostgresInsert,
    );
    await _channel!.subscribe();

    _started = true;
    debugPrint('SupabaseRelayService: abonné aux INSERT sur webhook_events ($url)');
  }

  Future<void> stop() async {
    if (!_started) return;
    await _channel?.unsubscribe();
    _channel = null;
    _started = false;
  }

  Future<void> _handlePostgresInsert(PostgresChangePayload payload) async {
    try {
      final raw = payload.newRecord;
      final rec = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(raw);
      if (rec.isEmpty) return;

      final event = rec['event'] as String?;
      if (event == null || event.isEmpty) return;

      final rawPayload = rec['payload'];
      Map<String, dynamic>? orderMap;
      if (rawPayload is Map) {
        final nested = rawPayload['order'];
        if (nested is Map<String, dynamic>) {
          orderMap = nested;
        } else if (nested is Map) {
          orderMap = Map<String, dynamic>.from(nested);
        }
      }

      final createdAt = rec['created_at'];
      final bridge = <String, dynamic>{
        'event': event,
        'version': '1.0',
        if (createdAt != null) 'timestamp': createdAt.toString(),
        if (orderMap != null) 'order': orderMap,
      };

      await WebhookEventHandler.instance.handleWebhookEvent(bridge);

      if (rawPayload is Map) {
        final n = rawPayload['notification'];
        if (n is Map) {
          final body = n['body'] as String? ?? '';
          if (body.isEmpty) return;
          final orderNumber =
              orderMap?['orderNumber'] as String? ?? rec['order_number'] as String? ?? '—';
          await NotificationService.instance.showNewOrderNotification(
            orderNumber,
            webhookPayload: bridge,
          );
        }
      }
    } catch (e, st) {
      debugPrint('SupabaseRelayService: erreur traitement insert — $e\n$st');
    }
  }
}
