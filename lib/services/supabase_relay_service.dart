import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../database/app_config_dao.dart';
import '../utils/url_normalize.dart';
import 'notification_service.dart';
import 'supabase_relay_status.dart';
import 'webhook_constants.dart';
import 'webhook_event_handler.dart';

class _SupabaseConfig {
  const _SupabaseConfig({required this.url, required this.anonKey});
  final String url;
  final String anonKey;
}

/// Abonnement Realtime sur `public.webhook_events` (inserts du WebhookRelay).
class SupabaseRelayService {
  SupabaseRelayService._();
  static final SupabaseRelayService instance = SupabaseRelayService._();

  RealtimeChannel? _channel;
  bool _started = false;
  SupabaseClient? _client;
  String? _clientUrl;
  String? _clientAnonKey;

  /// Dernière état pour l’UI (diagnostic Intégrations).
  final ValueNotifier<SupabaseRelayStatus> status =
      ValueNotifier(SupabaseRelayStatus.initial);

  void _setStatus(SupabaseRelayStatus s) {
    status.value = s;
  }

  Future<_SupabaseConfig> _resolveConfig({
    String? urlOverride,
    String? anonKeyOverride,
  }) async {
    var url = normalizeHttpOrigin(SupabaseEnv.url) ?? SupabaseEnv.url;
    var anonKey = SupabaseEnv.anonKey;

    if (anonKeyOverride != null) {
      anonKey = anonKeyOverride;
    } else if (anonKey.isEmpty) {
      anonKey = await AppConfigDao.instance.getValue('supabase_anon_key') ?? '';
    }

    if (urlOverride != null) {
      final normalized = normalizeHttpOrigin(urlOverride) ?? '';
      if (normalized.isNotEmpty) url = normalized;
    } else {
      final urlOverrideRaw = await AppConfigDao.instance.getValue('supabase_url');
      final normalized = normalizeHttpOrigin(urlOverrideRaw ?? '');
      if (normalized != null && normalized.isNotEmpty) {
        url = normalized;
      }
    }

    return _SupabaseConfig(url: url, anonKey: anonKey.trim());
  }

  Future<SupabaseClient?> _ensureClient({
    String? urlOverride,
    String? anonKeyOverride,
  }) async {
    final cfg = await _resolveConfig(urlOverride: urlOverride, anonKeyOverride: anonKeyOverride);
    final url = cfg.url;
    final anonKey = cfg.anonKey;

    if (url.isEmpty || anonKey.isEmpty) return null;

    final unchanged = _client != null && _clientUrl == url && _clientAnonKey == anonKey;
    if (unchanged) return _client;

    // Les identifiants ont changé : on repart d'un client propre.
    await _channel?.unsubscribe();
    _channel = null;
    _started = false;

    if (kDebugMode) {
      debugPrint(
        'SupabaseRelayService: URL résolue pour SupabaseClient (longueur=${url.length}) — '
        'vérifiez dans Intégrations / SQLite app_config.supabase_url si ce n’est pas attendu.',
      );
      debugPrint('SupabaseRelayService: URL = $url');
    }

    // Défaut realtime_client : 10s — trop court si le proxy TLS / DNS est lent → timedOut puis retry.
    _client = SupabaseClient(
      url,
      anonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        timeout: Duration(seconds: 45),
      ),
    );
    _clientUrl = url;
    _clientAnonKey = anonKey;
    return _client;
  }

  /// Arrête le canal puis le rouvre (après changement de config ou dépannage).
  Future<void> restart() async {
    await stop();
    await startIfConfigured();
  }

  Future<void> startIfConfigured() async {
    if (_started) return;

    final client = await _ensureClient();
    if (client == null) {
      debugPrint(
        'SupabaseRelayService: Realtime désactivé — renseignez SUPABASE_URL et '
        'SUPABASE_ANON_KEY (--dart-define) ou app_config (supabase_url / supabase_anon_key).',
      );
      _setStatus(
        const SupabaseRelayStatus(
          configured: false,
          phase: SupabaseRelayPhase.off,
          headline: 'Realtime : non configuré',
          detail: 'Renseignez l’URL Supabase et la clé anon (JWT eyJ…) puis enregistrez.',
        ),
      );
      return;
    }

    _setStatus(
      SupabaseRelayStatus(
        configured: true,
        phase: SupabaseRelayPhase.connecting,
        headline: 'Realtime : connexion…',
        detail: 'Canal public.webhook_events (INSERT) — ${_clientUrl ?? ''}',
      ),
    );

    _channel = client.channel('public_webhook_events');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'webhook_events',
      callback: _handlePostgresInsert,
    );
    _channel!.subscribe(_onSubscribeStatus);

    _started = true;
    debugPrint('SupabaseRelayService: subscription demandée → webhook_events (${_clientUrl ?? ''})');
  }

  void _onSubscribeStatus(RealtimeSubscribeStatus subscribeStatus, Object? error) {
    switch (subscribeStatus) {
      case RealtimeSubscribeStatus.subscribed:
        _setStatus(
          SupabaseRelayStatus(
            configured: true,
            phase: SupabaseRelayPhase.listening,
            headline: 'Realtime : connecté — en écoute',
            detail:
                'Les INSERT sur public.webhook_events sont reçus ici. '
                'Si une commande ne monte pas, vérifiez que le relais insère bien une ligne '
                'et que la publication Realtime inclut cette table côté Supabase.',
            lastInsertAt: status.value.lastInsertAt,
            insertCount: status.value.insertCount,
          ),
        );
        debugPrint('SupabaseRelayService: RealtimeSubscribeStatus.subscribed');
        break;
      case RealtimeSubscribeStatus.channelError:
        final err = error?.toString() ?? 'erreur inconnue';
        _started = false;
        final ch = _channel;
        _channel = null;
        if (ch != null) {
          ch.unsubscribe();
        }
        final hint400 = err.contains('400') || err.contains('not upgraded to websocket');
        _setStatus(
          SupabaseRelayStatus(
            configured: true,
            phase: SupabaseRelayPhase.error,
            headline: 'Realtime : erreur d’abonnement',
            detail: hint400
                ? '$err\n\n'
                    'Si vous voyez HTTP 400 sur l’upgrade WebSocket : le reverse proxy devant '
                    'votre URL Supabase (Nginx, Caddy, Cloudflare…) doit transmettre Upgrade / '
                    'Connection et ne pas couper HTTP/2 de façon incompatible. Réf. : '
                    'supabase/volumes/proxy/nginx/supabase-nginx.conf.tpl et KONG_PROXY_LISTEN dans docker-compose.'
                : err,
            lastInsertAt: status.value.lastInsertAt,
            insertCount: status.value.insertCount,
          ),
        );
        debugPrint('SupabaseRelayService: channelError — $err');
        break;
      case RealtimeSubscribeStatus.timedOut:
        _started = false;
        final ch2 = _channel;
        _channel = null;
        if (ch2 != null) {
          ch2.unsubscribe();
        }
        _setStatus(
          SupabaseRelayStatus(
            configured: true,
            phase: SupabaseRelayPhase.error,
            headline: 'Realtime : délai dépassé',
            detail: 'Kong / le proxy n’a pas répondu assez vite à la poignée de main WebSocket '
                '(réseau lent, ou TLS bloqué). Réessayez « Rafraîchir l’abonnement » ; le délai côté app est 45s.',
            lastInsertAt: status.value.lastInsertAt,
            insertCount: status.value.insertCount,
          ),
        );
        debugPrint('SupabaseRelayService: timedOut');
        break;
      case RealtimeSubscribeStatus.closed:
        _setStatus(
          SupabaseRelayStatus(
            configured: true,
            phase: SupabaseRelayPhase.off,
            headline: 'Realtime : canal fermé',
            detail: 'L’abonnement s’est arrêté. Touchez « Rafraîchir l’abonnement » pour relancer.',
            lastInsertAt: status.value.lastInsertAt,
            insertCount: status.value.insertCount,
          ),
        );
        _started = false;
        _channel = null;
        debugPrint('SupabaseRelayService: closed');
        break;
    }
  }

  Future<void> stop() async {
    try {
      await _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
    _started = false;
    if (_clientUrl != null && _clientUrl!.isNotEmpty) {
      _setStatus(
        SupabaseRelayStatus(
          configured: true,
          phase: SupabaseRelayPhase.off,
          headline: 'Realtime : arrêté',
          detail: 'Abonnement fermé. Ré-enregistrez la config ou touchez « Rafraîchir l’abonnement ».',
          lastInsertAt: status.value.lastInsertAt,
          insertCount: status.value.insertCount,
        ),
      );
    }
  }

  /// Diagnostic : vérifie que l'app peut lire la table `webhook_events`.
  /// Retourne un message prêt à afficher dans l'UI.
  Future<String> testConnection({String? urlOverride, String? anonKeyOverride}) async {
    final client = await _ensureClient(urlOverride: urlOverride, anonKeyOverride: anonKeyOverride);
    if (client == null) return 'Supabase non configuré (URL / ANON KEY manquantes).';

    try {
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
      };
      if (createdAt != null) bridge['timestamp'] = createdAt.toString();
      if (payloadSource != null) bridge['source'] = payloadSource;
      if (orderMap != null) bridge['order'] = orderMap;

      await WebhookEventHandler.instance.handleWebhookEvent(bridge);

      final prev = status.value;
      final orderHint =
          orderMap?['orderNumber']?.toString() ?? rec['order_number']?.toString() ?? '—';
      _setStatus(
        SupabaseRelayStatus(
          configured: prev.configured,
          phase: SupabaseRelayPhase.listening,
          headline: 'Realtime : connecté — événements reçus',
          detail: 'Dernier message : $event · commande #$orderHint',
          lastInsertAt: DateTime.now(),
          insertCount: prev.insertCount + 1,
        ),
      );

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
