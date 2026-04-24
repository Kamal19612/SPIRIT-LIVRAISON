import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../providers/auth_provider.dart';
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

  Future<void> init() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();
    _initialized = true;
  }

  /// Enregistre le token device côté Spring Boot:
  /// POST /api/webhooks/livraison/inscription
  Future<void> registerIfPossible(AuthProvider auth) async {
    if (!_initialized) return;
    if (!auth.isAuthenticated) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    try {
      await StoreApiBridge.instance.registerFcmToken(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (_) {
      // non bloquant
    }
  }

  /// Écoute les messages FCM en foreground et peut déclencher un refresh commandes.
  void listenForeground({required void Function(String type) onEvent}) {
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      final type = (msg.data['type'] ?? '').toString();
      if (type.isEmpty) return;
      onEvent(type);
    });
  }
}

Future<void> _showLocalNotificationFromMessage(RemoteMessage msg) async {
  final type = (msg.data['type'] ?? '').toString();
  final orderNumber = (msg.data['orderNumber'] ?? '').toString();

  // Préférer la notification fournie par FCM si dispo.
  final title = msg.notification?.title ?? '';
  final body = msg.notification?.body ?? '';

  if (type == 'new_delivery') {
    await NotificationService.instance.showNewOrderNotification(
      orderNumber.isNotEmpty ? orderNumber : '#',
    );
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
    // Admin only; on réutilise canal "delivery_orders" pour rester simple.
    await NotificationService.instance.showStatusNotification(
      title: title.isNotEmpty ? title : 'Nouvelle commande',
      body: body.isNotEmpty ? body : (orderNumber.isNotEmpty ? 'Commande #$orderNumber' : 'Nouvelle commande'),
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

