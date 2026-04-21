import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../database/app_config_dao.dart';
import '../utils/url_normalize.dart';
import 'notification_service.dart';
import 'webhook_constants.dart';
import 'webhook_event_handler.dart';

/// Abonnement Realtime sur `public.webhook_events` (inserts du WebhookRelay).
class SupabaseRelayService {
  SupabaseRelayService._();
  static final SupabaseRelayService instance = SupabaseRelayService._();

  RealtimeChannel? _channel;
  bool _started = false;
  bool _initialized = false;

  Future<void> startIfConfigured() async {
    if (_started) return;

    var url = normalizeHttpOrigin(SupabaseEnv.url) ?? SupabaseEnv.url;
    var anonKey = SupabaseEnv.anonKey;

    if (anonKey.isEmpty) {
      anonKey = await AppConfigDao.instance.getValue('supabase_anon_key') ?? '';
    }
    final urlOverrideRaw = await AppConfigDao.instance.getValue('supabase_url');
    final urlOverride = normalizeHttpOrigin(urlOverrideRaw ?? '');
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

    if (!_initialized) {
      try {
        await Supabase.initialize(url: url, anonKey: anonKey);
        _initialized = true;
      } catch (e) {
        // Supabase peut déjà être initialisé (hot restart) : on continue.
        debugPrint('SupabaseRelayService: init déjà fait ou échec init — $e');
        _initialized = true;
      }
    }

    final client = Supabase.instance.client;
    _channel = client.channel('public_webhook_events');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'webhook_events',
      callback: _handlePostgresInsert,
    );
    _channel!.subscribe();

    _started = true;
    debugPrint('SupabaseRelayService: abonné aux INSERT sur webhook_events ($url)');
  }

  Future<void> stop() async {
    if (!_started) return;
    await _channel?.unsubscribe();
    _channel = null;
    _started = false;
  }

  /// Diagnostic : vérifie que l'app peut lire la table `webhook_events`.
  /// Retourne un message prêt à afficher dans l'UI.
  Future<String> testConnection() async {
    var url = normalizeHttpOrigin(SupabaseEnv.url) ?? SupabaseEnv.url;
    var anonKey = SupabaseEnv.anonKey;

    if (anonKey.isEmpty) {
      anonKey = await AppConfigDao.instance.getValue('supabase_anon_key') ?? '';
    }
    final urlOverrideRaw = await AppConfigDao.instance.getValue('supabase_url');
    final urlOverride = normalizeHttpOrigin(urlOverrideRaw ?? '');
    if (urlOverride != null && urlOverride.isNotEmpty) {
      url = urlOverride;
    }

    if (url.isEmpty || anonKey.isEmpty) {
      return 'Supabase non configuré (URL / ANON KEY manquantes).';
    }

    await startIfConfigured();

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('webhook_events')
          .select('id,event,order_number,created_at')
          .order('id', ascending: false)
          .limit(1);

      final rows = res as List;
      if (rows.isNotEmpty) {
        final row = Map<String, dynamic>.from(rows.first as Map);
        final event = row['event']?.toString() ?? '—';
        final order = row['order_number']?.toString() ?? '—';
        final ts = row['created_at']?.toString() ?? '';
        return 'OK: dernier event=$event (#$order) ${ts.isNotEmpty ? 'à $ts' : ''}';
      }
      return 'OK: connexion Supabase, mais table webhook_events vide.';
    } catch (e) {
      return 'ERREUR Supabase: $e';
    }
  }

  Future<void> _handlePostgresInsert(PostgresChangePayload payload) async {
    try {
      final rec = Map<String, dynamic>.from(payload.newRecord);
      if (rec.isEmpty) return;

      final event = rec['event'] as String?;
      if (event == null || event.isEmpty) return;

      final rawPayload = rec['payload'];
      Map<String, dynamic>? orderMap;
      String? payloadVersion;
      String? payloadSource;
      if (rawPayload is Map) {
        final nested = rawPayload['order'];
        if (nested is Map<String, dynamic>) {
          orderMap = nested;
        } else if (nested is Map) {
          orderMap = Map<String, dynamic>.from(nested);
        }
        final v = rawPayload['version'];
        if (v != null) payloadVersion = v.toString();
        final s = rawPayload['source'];
        if (s != null && s.toString().isNotEmpty) {
          payloadSource = s.toString();
        }
      }

      final createdAt = rec['created_at'];
      final bridge = <String, dynamic>{
        'event': event,
        'version': payloadVersion ?? WebhookConfig.supportedVersion,
        if (createdAt != null) 'timestamp': createdAt.toString(),
        if (payloadSource != null) 'source': payloadSource,
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
            processWebhookPayload: false,
          );
        }
      }
    } catch (e, st) {
      debugPrint('SupabaseRelayService: erreur traitement insert — $e\n$st');
    }
  }
}
