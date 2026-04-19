// Constantes du système webhook côté mobile.
// Ces valeurs sont le miroir exact des enums Java (WebhookEventType.java).
// Toute modification d'un côté doit être répercutée de l'autre.

// ── Types d'événements ────────────────────────────────────────────────────────

class WebhookEvents {
  /// Commande confirmée → apparaît dans "Disponibles"
  static const orderConfirmed  = 'ORDER_CONFIRMED';

  /// Commande acceptée par un livreur → disparaît de "Disponibles"
  static const orderClaimed    = 'ORDER_CLAIMED';

  /// Commande en route (livreur assigné)
  static const orderInDelivery = 'ORDER_IN_DELIVERY';

  /// Livraison validée avec code client
  static const orderDelivered  = 'ORDER_DELIVERED';

  /// Commande annulée
  static const orderCancelled  = 'ORDER_CANCELLED';

  /// Ping de test envoyé depuis le panneau admin
  static const webhookTest     = 'WEBHOOK_TEST';

  /// Wildcard : s'abonner à tous les événements
  static const wildcard        = '*';

  static const all = [
    orderConfirmed, orderClaimed, orderInDelivery,
    orderDelivered, orderCancelled, webhookTest,
  ];
}

// ── Headers de sécurité ───────────────────────────────────────────────────────

class WebhookHeaders {
  /// Signature HMAC-SHA256 : `sha256=<hex>`
  static const signature = 'x-webhook-signature';

  /// Type d'événement redondant dans le header
  static const event     = 'x-webhook-event';

  /// Version du format payload
  static const version   = 'x-webhook-version';
}

// ── Configuration ─────────────────────────────────────────────────────────────

class WebhookConfig {
  /// Version courante du format payload (doit correspondre au backend)
  static const supportedVersion = '1.0';
}
