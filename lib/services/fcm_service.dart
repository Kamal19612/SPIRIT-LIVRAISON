import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../providers/auth_provider.dart';
import 'delivery_alert_service.dart';
import 'notification_service.dart';
import 'store_api_bridge.dart';

/// Handler FCM background (app en arrière-plan / fermée).
/// Doit être top-level pour fonctionner.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // Init notifications locales (Android/iOS).
  try {
    await NotificationService.instance.init();
  } catch (_) {}

  await _showLocalNotificationFromMessage(message);
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  Future<void> init() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await NotificationService.instance.ensurePermission();
    _initialized = true;
    // Renouvellement de token (rotation FCM) → re-sync backend
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      unawaited(_registerTokenToBackend(t));
    });
  }

  Future<void> _registerTokenToBackend(String fcmToken) async {
    final backends = await StoreApiBridge.instance.getAuthenticatedBackends();
    for (final backend in backends) {
      try {
        await StoreApiBridge.instance.registerFcmToken(
          backend: backend,
          token: fcmToken,
          platform: Platform.isIOS ? 'ios' : 'android',
        );
      } catch (_) {
        // non bloquant par serveur
      }
    }
  }

  /// Enregistre le token device côté Spring Boot
  /// (`/api/delivery/devices/register` puis alias `/api/webhooks/livraison/inscription`).
  Future<void> registerIfPossible(AuthProvider auth) async {
    if (!_initialized) return;
    if (!auth.isAuthenticated) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _registerTokenToBackend(token);
  }

  /// Écoute les messages FCM en foreground (une seule souscription).
  void listenForeground({
    required void Function(String type, Map<String, dynamic> data) onEvent,
  }) {
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final type = (msg.data['type'] ?? '').toString();
      if (type.isNotEmpty) {
        onEvent(type, Map<String, dynamic>.from(msg.data));
      }
      // Toujours afficher une notification locale (premier plan) : le callback
      // UI peut ne pas déclencher d'alerte (ex. admin) ou arriver après le refresh.
      await _showLocalNotificationFromMessage(msg);
    });
  }
}

Future<void> _showLocalNotificationFromMessage(RemoteMessage msg) async {
  final type = (msg.data['type'] ?? '').toString();
  final orderNumber = (msg.data['orderNumber'] ?? '').toString();

  // Préférer la notification fournie par FCM si dispo.
  final title = msg.notification?.title ?? '';
  final body = msg.notification?.body ?? '';

  if (DeliveryAlertService.isNewDeliveryEvent(type)) {
    await DeliveryAlertService.instance.fromEventPayload(msg.data);
    return;
  }

  if (type == 'order_status') {
    final t = title.isNotEmpty ? title : 'Statut mis à jour';
    final b = body.isNotEmpty
        ? body
        : (orderNumber.isNotEmpty ? 'Commande #$orderNumber → ${msg.data['status'] ?? ''}' : 'Statut mis à jour');
    await NotificationService.instance.showStatusNotification(title: t, body: b);
    return;
  }

  if (type == 'new_order') {
    final t = title.isNotEmpty ? title : '🛒 Nouvelle commande';
    final b = body.isNotEmpty
        ? body
        : (orderNumber.isNotEmpty ? 'Commande #$orderNumber' : 'Nouvelle commande reçue');
    await NotificationService.instance.showStatusNotification(
      title: t,
      body: b,
      highPriority: true,
    );
    return;
  }

  if (type == 'staff_changed') {
    await NotificationService.instance.showStatusNotification(
      title: title.isNotEmpty ? title : 'Équipe mise à jour',
      body: body.isNotEmpty ? body : 'Liste des livreurs actualisée',
    );
    return;
  }

  // Fallback générique.
  if (title.isNotEmpty || body.isNotEmpty) {
    await NotificationService.instance.showStatusNotification(
      title: title.isNotEmpty ? title : 'Notification',
      body: body.isNotEmpty ? body : 'Mise à jour',
    );
  }
}

