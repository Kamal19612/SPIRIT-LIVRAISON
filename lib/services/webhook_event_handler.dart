// Gestionnaire des événements webhook reçus par l'application mobile.
//
// Ce module définit la réaction à chaque type d'événement :
//   ORDER_CONFIRMED   → insérer la commande dans SQLite (si absente)
//   ORDER_CLAIMED     → mettre à jour le statut (prise par un livreur)
//   ORDER_IN_DELIVERY → statut SHIPPED dans SQLite
//   ORDER_DELIVERED   → marquer la livraison comme terminée
//   ORDER_CANCELLED   → statut CANCELLED dans SQLite
//   WEBHOOK_TEST      → confirmer la réception dans les logs
//
// Architecture :
//   Backend Spring → Serveur relais → Push notification → App mobile
//                                                        → WebhookEventHandler.handleWebhookEvent()
//
// Le serveur relais (Node.js externe) reçoit le POST du backend,
// vérifie la signature, et envoie le payload via flutter_local_notifications / FCM.
// L'app mobile reçoit la notification et appelle handleWebhookEvent().

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../database/orders_dao.dart';
import '../models/external_source_model.dart';
import '../models/order_model.dart';
import 'webhook_constants.dart';
import 'webhook_signature_verifier.dart';

// ── Type callback ─────────────────────────────────────────────────────────────

typedef WebhookCallback = void Function(
  Map<String, dynamic>? order,
  Map<String, dynamic> meta,
);

// ── Singleton ChangeNotifier ──────────────────────────────────────────────────

class WebhookEventHandler extends ChangeNotifier {
  WebhookEventHandler._();
  static final WebhookEventHandler instance = WebhookEventHandler._();

  // Registre des listeners par type d'événement.
  // Format : Map<eventType, Set<callback>>
  // Permet à plusieurs composants de s'abonner au même événement.
  final Map<String, Set<WebhookCallback>> _listeners = {};

  String? _lastEvent;
  Map<String, dynamic>? _lastOrder;

  /// Dernier type d'événement reçu (utile pour que les screens réagissent via addListener).
  String? get lastEvent => _lastEvent;

  /// Payload order du dernier événement reçu.
  Map<String, dynamic>? get lastOrder => _lastOrder;

  // ── Abonnement / Désabonnement ────────────────────────────────────────────

  /// S'abonne à un type d'événement webhook.
  ///
  /// [eventType] Une valeur de [WebhookEvents] (ou `*` pour tous les événements).
  /// [callback]  Appelé avec (order, meta) quand l'événement arrive.
  ///
  /// Retourne une fonction de désabonnement à appeler dans dispose().
  ///
  /// ```dart
  /// final unsub = WebhookEventHandler.instance.subscribe(
  ///   WebhookEvents.orderConfirmed,
  ///   (order, meta) => ordersProvider.refresh(),
  /// );
  /// // Dans dispose() :
  /// unsub();
  /// ```
  VoidCallback subscribe(String eventType, WebhookCallback callback) {
    _listeners.putIfAbsent(eventType, () => {}).add(callback);
    return () => _unsubscribe(eventType, callback);
  }

  void _unsubscribe(String eventType, WebhookCallback callback) {
    _listeners[eventType]?.remove(callback);
  }

  /// Vide tous les listeners (ex: lors du logout).
  void clearAllListeners() {
    _listeners.clear();
  }

  // ── Point d'entrée principal ──────────────────────────────────────────────

  /// Traite un payload webhook reçu (depuis une push notification ou SSE).
  ///
  /// [rawPayload] Payload JSON reçu — objet Map ou String JSON.
  Future<void> handleWebhookEvent(dynamic rawPayload) async {
    try {
      final parsed = WebhookSignatureVerifier.parseWebhookPayload(rawPayload);

      if (!parsed.valid) {
        debugPrint('WebhookEventHandler: payload rejeté (structure invalide)');
        return;
      }

      debugPrint(
        'WebhookEventHandler: événement reçu: ${parsed.event} '
        '| order#${parsed.order?['orderNumber']} '
        '| ts=${parsed.timestamp}',
      );

      final meta = <String, dynamic>{
        'event':   parsed.event,
        'version': parsed.version,
        if (parsed.timestamp != null) 'timestamp': parsed.timestamp,
      };

      _lastEvent = parsed.event;
      _lastOrder = parsed.order;

      // 1. Dispatcher aux listeners abonnés
      _dispatchEvent(parsed.event, parsed.order, meta);

      // 2. Actions DB par défaut
      await _handleByEventType(parsed.event, parsed.order);

      // 3. Mettre à jour les stats de la source (received_count, last_received_at)
      if (parsed.source != null) {
        await _updateSourceReceivedStats(parsed.source!);
      }

      // 4. Notifier les screens Flutter (addListener pattern)
      notifyListeners();
    } catch (e) {
      debugPrint('WebhookEventHandler: erreur traitement — $e');
    }
  }

  // ── Dispatcher ────────────────────────────────────────────────────────────

  void _dispatchEvent(
    String eventType,
    Map<String, dynamic>? order,
    Map<String, dynamic> meta,
  ) {
    // Listeners spécifiques à cet événement
    final specific = _listeners[eventType];
    if (specific != null) {
      for (final cb in List.from(specific)) {
        try {
          cb(order, meta);
        } catch (e) {
          debugPrint('WebhookEventHandler: erreur listener $eventType — $e');
        }
      }
    }

    // Listeners globaux (abonnés à '*')
    final global = _listeners[WebhookEvents.wildcard];
    if (global != null) {
      for (final cb in List.from(global)) {
        try {
          cb(order, meta);
        } catch (e) {
          debugPrint('WebhookEventHandler: erreur listener global — $e');
        }
      }
    }
  }

  // ── Actions DB par défaut par type d'événement ────────────────────────────

  Future<void> _handleByEventType(
    String event,
    Map<String, dynamic>? order,
  ) async {
    switch (event) {

      case WebhookEvents.orderConfirmed:
        // Nouvelle commande disponible → insérer dans SQLite si absente
        if (order != null) {
          try {
            final model    = Order.fromJson(order);
            final existing = await OrdersDao.instance.getOrderByNumber(model.orderNumber);
            if (existing == null) {
              await OrdersDao.instance.insertOrder(model);
            }
          } catch (e) {
            debugPrint('WebhookEventHandler [ORDER_CONFIRMED] erreur DB: $e');
          }
        }
        break;

      case WebhookEvents.orderClaimed:
        // Un autre livreur a accepté → mettre à jour le statut
        if (order != null) {
          final orderId = (order['id'] as num?)?.toInt();
          final agentId = order['deliveryAgent'] is Map
              ? ((order['deliveryAgent'] as Map)['id'] as num?)?.toInt()
              : null;
          if (orderId != null) {
            try {
              await OrdersDao.instance.claimOrderLocal(orderId, agentId);
            } catch (e) {
              debugPrint('WebhookEventHandler [ORDER_CLAIMED] erreur DB: $e');
            }
          }
        }
        break;

      case WebhookEvents.orderInDelivery:
        // Commande en route → statut SHIPPED
        if (order != null) {
          final orderId = (order['id'] as num?)?.toInt();
          if (orderId != null) {
            try {
              await OrdersDao.instance.updateOrderStatus(orderId, 'SHIPPED');
            } catch (e) {
              debugPrint('WebhookEventHandler [ORDER_IN_DELIVERY] erreur DB: $e');
            }
          }
        }
        break;

      case WebhookEvents.orderDelivered:
        // Livraison validée → statut DELIVERED
        if (order != null) {
          final orderId = (order['id'] as num?)?.toInt();
          if (orderId != null) {
            try {
              await OrdersDao.instance.completeOrderLocal(orderId);
            } catch (e) {
              debugPrint('WebhookEventHandler [ORDER_DELIVERED] erreur DB: $e');
            }
          }
        }
        break;

      case WebhookEvents.orderCancelled:
        // Commande annulée → retirer de toutes les listes
        if (order != null) {
          final orderId = (order['id'] as num?)?.toInt();
          if (orderId != null) {
            try {
              await OrdersDao.instance.updateOrderStatus(orderId, 'CANCELLED');
            } catch (e) {
              debugPrint('WebhookEventHandler [ORDER_CANCELLED] erreur DB: $e');
            }
          }
        }
        break;

      case WebhookEvents.webhookTest:
        // Ping de test — connexion opérationnelle
        debugPrint('WebhookEventHandler [WEBHOOK_TEST]: connexion webhook opérationnelle ✓');
        break;

      default:
        debugPrint("WebhookEventHandler: type d'événement inconnu: $event");
    }
  }

  // ── Stats de la source webhook ────────────────────────────────────────────

  /// Incrémente `received_count` et met à jour `last_received_at` pour la
  /// source dont le `source_identifier` correspond à [sourceIdentifier].
  Future<void> _updateSourceReceivedStats(String sourceIdentifier) async {
    try {
      final db = LocalDatabase.instance.db;

      // Chercher la source par name ou source_identifier
      final rows = await db.query('external_sources',
          where: "platformType = 'webhook'");

      for (final row in rows) {
        final src = ExternalSource.fromSqlite(row);
        if (src.sourceIdentifier == sourceIdentifier || src.name == sourceIdentifier) {
          final newConfig = {
            ...src.config,
            'received_count':   src.receivedCount + 1,
            'last_received_at': DateTime.now().toIso8601String(),
          };
          await db.update(
            'external_sources',
            {'configJson': jsonEncode(newConfig)},
            where: 'id = ?',
            whereArgs: [src.id],
          );
          break;
        }
      }
    } catch (e) {
      debugPrint('WebhookEventHandler [stats]: erreur mise à jour — $e');
    }
  }
}
