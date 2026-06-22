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
        'Nouvelles livraisons',
        description: 'Alertes sonores pour les nouvelles livraisons disponibles',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const connectionChannel = AndroidNotificationChannel(
        'connection_active',
        'Connexion serveur',
        description: 'Maintien de la liaison avec le serveur en arrière-plan',
        importance: Importance.low,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(connectionChannel);

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

  /// Demande la permission Android 13+ (retourne false si refusée).
  Future<bool> ensurePermission() async {
    if (!_initialized) await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  // ── Callback foreground ──────────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    // Intentionnel: pas de deep-linking pour le moment.
  }

  // ── Affichage d'une notification locale ──────────────────────────────────

  String _deliveryTypeLabel(String? deliveryType) {
    final t = (deliveryType ?? '').toUpperCase();
    if (t == 'EXPRESS') return '⚡ Express';
    if (t == 'PROGRAMMER') return '🕐 Programmée';
    return '';
  }

  /// Nouvelle livraison disponible (SSE / FCM, aligné PWA).
  Future<void> showNewDeliveryNotification({
    required String orderNumber,
    String? deliveryType,
  }) async {
    if (!_initialized) return;
    final label = _deliveryTypeLabel(deliveryType);
    final body = label.isEmpty
        ? 'Commande #$orderNumber'
        : 'Commande #$orderNumber · $label';
    try {
      const androidDetails = AndroidNotificationDetails(
        'delivery_orders',
        'Nouvelles livraisons',
        channelDescription: 'Alertes pour les nouvelles livraisons disponibles',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ticker: 'Nouvelle livraison',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _plugin.show(
        _notifId++,
        '🚚 Nouvelle livraison disponible',
        body,
        details,
      );
    } catch (_) {}
  }

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
    bool highPriority = false,
  }) async {
    if (!_initialized) return;
    try {
      const payloadStr = null;

      final androidDetails = AndroidNotificationDetails(
        'delivery_orders',
        highPriority ? 'Nouvelles livraisons' : 'Nouvelles commandes',
        channelDescription: highPriority
            ? 'Alertes pour les nouvelles livraisons et commandes'
            : 'Notifications pour les nouvelles commandes',
        importance: highPriority ? Importance.max : Importance.defaultImportance,
        priority: highPriority ? Priority.high : Priority.defaultPriority,
        playSound: highPriority,
        enableVibration: highPriority,
      );
      const iosDetails = DarwinNotificationDetails();
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _plugin.show(_notifId++, title, body, details, payload: payloadStr);
    } catch (_) {}
  }

  static const int connectionNotificationId = 900001;

  /// Notification persistante : priorité processus Android pendant la veille.
  Future<void> showConnectionActiveNotification() async {
    if (!_initialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'connection_active',
        'Connexion serveur',
        channelDescription: 'Maintien de la liaison avec le serveur',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _plugin.show(
        connectionNotificationId,
        'Connexion active',
        'Synchronisation avec le serveur en cours',
        details,
      );
    } catch (_) {}
  }

  Future<void> hideConnectionActiveNotification() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(connectionNotificationId);
    } catch (_) {}
  }
}
