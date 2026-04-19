// Vérification de la signature HMAC-SHA256 des webhooks entrants.
//
// Le backend signe chaque payload avec :
//   HMAC-SHA256(corps JSON, secret_partagé)
//
// Et envoie le header :
//   X-Webhook-Signature: sha256=<hex>
//
// Ce module reçoit la signature + le corps + le secret et vérifie
// que le message n'a pas été falsifié ou altéré en transit.
//
// NOTE : L'app mobile ne reçoit PAS les webhooks directement (pas de serveur HTTP
// embarqué). Ce vérificateur est utilisé par le serveur relais (Node.js / Firebase
// Function) qui reçoit les webhooks du backend Spring Boot et les transfère à
// l'app via flutter_local_notifications ou FCM.
// Sur l'app mobile, parseWebhookPayload() est le point d'entrée principal.

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Résultat du parsing d'un payload webhook.
class WebhookPayloadResult {
  final bool valid;
  final String event;
  final String version;
  final String? timestamp;
  final Map<String, dynamic>? order;

  /// Identifiant de la source externe (champ `source` du payload).
  /// Permet de retrouver la [ExternalSource] correspondante en DB.
  final String? source;

  const WebhookPayloadResult({
    required this.valid,
    this.event = '',
    this.version = '1.0',
    this.timestamp,
    this.order,
    this.source,
  });
}

class WebhookSignatureVerifier {
  // ── HMAC-SHA256 ──────────────────────────────────────────────────────────────

  /// Calcule la signature HMAC-SHA256 d'un corps JSON avec un secret partagé.
  /// Retourne la signature en hex (sans préfixe `sha256=`).
  ///
  /// Équivalent synchrone de `computeHmacSha256` (SubtleCrypto → dart:crypto).
  static String computeHmacSha256(String body, String secret) {
    final key   = utf8.encode(secret);
    final bytes = utf8.encode(body);
    return Hmac(sha256, key).convert(bytes).toString();
  }

  /// Vérifie que la signature du webhook est valide.
  ///
  /// [body]              Corps JSON brut reçu (String).
  /// [receivedSignature] Header X-Webhook-Signature (ex: `sha256=abc123`).
  /// [secret]            Secret partagé configuré dans la source.
  static bool verifyWebhookSignature(
    String body,
    String receivedSignature,
    String secret,
  ) {
    if (!receivedSignature.startsWith('sha256=')) return false;

    final receivedHex = receivedSignature.substring(7); // retire "sha256="
    final expectedHex = computeHmacSha256(body, secret);

    // Comparaison en temps constant pour éviter les timing attacks
    return _constantTimeEqual(receivedHex, expectedHex);
  }

  // ── Parsing payload ──────────────────────────────────────────────────────────

  /// Extrait et valide les métadonnées d'un payload webhook.
  ///
  /// Format attendu :
  /// ```json
  /// {
  ///   "event": "ORDER_CONFIRMED",
  ///   "version": "1.0",
  ///   "timestamp": "2024-01-01T00:00:00Z",
  ///   "order": { ... }
  /// }
  /// ```
  static WebhookPayloadResult parseWebhookPayload(dynamic payload) {
    if (payload == null) {
      return const WebhookPayloadResult(valid: false);
    }

    Map<String, dynamic> map;
    if (payload is String) {
      try {
        map = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        return const WebhookPayloadResult(valid: false);
      }
    } else if (payload is Map<String, dynamic>) {
      map = payload;
    } else {
      return const WebhookPayloadResult(valid: false);
    }

    final event      = map['event']     as String?;
    final version    = map['version']   as String? ?? '1.0';
    final timestamp  = map['timestamp'] as String?;
    final order      = map['order']     as Map<String, dynamic>?;
    final source     = map['source']    as String?; // identifiant source relais

    // event est obligatoire ; order peut être null pour WEBHOOK_TEST
    if (event == null || event.isEmpty) {
      return const WebhookPayloadResult(valid: false);
    }

    return WebhookPayloadResult(
      valid:     true,
      event:     event,
      version:   version,
      timestamp: timestamp,
      order:     order,
      source:    source,
    );
  }

  // ── Comparaison en temps constant ────────────────────────────────────────────

  /// Évite les attaques par timing : ne s'arrête pas au premier caractère différent.
  static bool _constantTimeEqual(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
