import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Callback background (top-level — isolate séparé) ────────────────────────
// Appelé quand l'utilisateur tape sur une notification pendant que l'app est
// en arrière-plan ou fermée. Doit être une fonction top-level (pas de closure
// ni de méthode d'instance) car elle s'exécute dans un isolate différent.
@pragma('vm:entry-point')
void _onNotificationTapBackground(NotificationResponse response) {
  // En background isolate, on ne peut pas appeler de code UI ni accéder aux
  // providers. On se limite à logger. Le foreground handler (_onNotificationTap)
  // prend le relais quand l'app revient au premier plan.
  debugPrint(
    'NotificationService [background tap]: id=${response.id} '
    'payload=${response.payload}',
  );
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  int _notifId = 0;
  bool _initialized = false;

  Future<void> init() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Callback déclenché quand l'utilisateur tape sur une notification
      // (foreground ou depuis le tiroir de notifications).
      // Le serveur relais encode le payload webhook en JSON dans le champ payload.
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: _onNotificationTapBackground,
      );

      // Canal Android pour les nouvelles commandes
      const channel = AndroidNotificationChannel(
        'delivery_orders',
        'Nouvelles commandes',
        description: 'Notifications pour les nouvelles commandes de livraison',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Demande de permission Android 13+
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _initialized = true;
    } catch (_) {
      // Notifications non disponibles sur cette plateforme (ex: desktop)
    }
  }

  // ── Callback foreground ──────────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    // Intentionnel: pas de deep-linking pour le moment.
  }

  // ── Affichage d'une notification locale ──────────────────────────────────

  /// Affiche une notification locale "Nouvelle commande".
  /// [webhookPayload] : si fourni, sera encodé dans le payload de la notification
  /// afin que [_onNotificationTap] puisse déclencher le webhook handler au tap.
  ///
  /// [processWebhookPayload] : si `true` (défaut), applique [WebhookEventHandler]
  /// avant d'afficher (ex. relais FCM sans traitement amont). Mettre `false`
  /// quand le handler a déjà été appelé (ex. [SupabaseRelayService]).
  Future<void> showNewOrderNotification(
    String orderNumber, {
    Map<String, dynamic>? webhookPayload,
  }) async {
    if (!_initialized) return;
    try {
      final payloadStr = null;

      final androidDetails = AndroidNotificationDetails(
        'delivery_orders',
        'Nouvelles commandes',
        channelDescription: 'Notifications pour les nouvelles commandes',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'Nouvelle commande',
        styleInformation: BigTextStyleInformation(
          'Commande $orderNumber en attente de livreur',
        ),
      );
      const iosDetails = DarwinNotificationDetails();
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _plugin.show(
        _notifId++,
        'Nouvelle commande disponible !',
        'Commande $orderNumber en attente de livreur',
        details,
        payload: payloadStr,
      );
    } catch (_) {}
  }

  /// Affiche une notification de changement de statut (ORDER_CLAIMED, DELIVERED, etc.).
  Future<void> showStatusNotification({
    required String title,
    required String body,
    Map<String, dynamic>? webhookPayload,
  }) async {
    if (!_initialized) return;
    try {
      const payloadStr = null;

      const androidDetails = AndroidNotificationDetails(
        'delivery_orders',
        'Nouvelles commandes',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _plugin.show(_notifId++, title, body, details, payload: payloadStr);
    } catch (_) {}
  }
}
