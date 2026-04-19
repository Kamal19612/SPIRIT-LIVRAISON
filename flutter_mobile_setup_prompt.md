# Prompt — Configuration de l'application mobile Flutter (Sucre Store)

```
Tu vas m'aider à configurer mon application mobile Flutter pour qu'elle 
reçoive les événements de commande en temps réel depuis le backend Sucre Store.

═══════════════════════════════════════════════════════════════
ARCHITECTURE EN PLACE (côté serveur — ne pas modifier)
═══════════════════════════════════════════════════════════════

Flux : Spring Boot → WebhookRelay (Node.js) → Supabase INSERT → Flutter (WebSocket)

Le backend Spring Boot envoie un webhook HMAC-SHA256 au WebhookRelay (Node.js)
dès qu'une commande change de statut. Le relay insère un événement dans la table
Supabase `webhook_events`. L'app Flutter doit écouter cette table via 
Supabase Realtime (WebSocket) et afficher les nouvelles courses disponibles.

═══════════════════════════════════════════════════════════════
CONNEXION SUPABASE (self-hosted sur le même serveur)
═══════════════════════════════════════════════════════════════

Supabase URL publique : http://5.189.133.248:8000
Anon Key (clé publique, à utiliser côté Flutter) :
  eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzc1ODQ2MzQ0LCJleHAiOjIwOTEyMDYzNDR9.FENP9n2K3QjYlOVMGSeix9XuqPo9ooE3KAo7oYZKFIs

Ne jamais utiliser la SERVICE_ROLE_KEY côté Flutter.

═══════════════════════════════════════════════════════════════
TABLE SUPABASE — webhook_events
═══════════════════════════════════════════════════════════════

CREATE TABLE public.webhook_events (
  id           BIGSERIAL    PRIMARY KEY,
  event        TEXT         NOT NULL,
  order_id     BIGINT,
  order_number TEXT,
  payload      JSONB,
  created_at   TIMESTAMPTZ  DEFAULT NOW()
);

La table a :
- REPLICA IDENTITY FULL → activé (nécessaire pour Realtime)
- RLS activé avec politique SELECT publique (l'anon key peut lire)
- Publication Supabase Realtime activée sur cette table

═══════════════════════════════════════════════════════════════
ÉVÉNEMENTS (champ `event` dans la table)
═══════════════════════════════════════════════════════════════

ORDER_CONFIRMED    → nouvelle course disponible (livreur peut l'accepter)
ORDER_CLAIMED      → course prise par un autre livreur
ORDER_IN_DELIVERY  → commande en cours de livraison
ORDER_DELIVERED    → commande livrée
ORDER_CANCELLED    → commande annulée
WEBHOOK_TEST       → test de connexion (ignorer côté UI)

═══════════════════════════════════════════════════════════════
STRUCTURE DU PAYLOAD (champ `payload` en JSONB)
═══════════════════════════════════════════════════════════════

{
  "order": {
    "id": 42,
    "orderNumber": "CMD-20240410-0042",
    "confirmationCode": "ABC123",

    // Client
    "customerName": "Aminata Traoré",
    "customerPhone": "22670000000",
    "customerAddress": "Secteur 15, Ouagadougou",
    "customerNotes": "Appeler avant d'arriver",
    "customerLatitude": 12.3456,       // null si non fourni
    "customerLongitude": -1.5678,      // null si non fourni
    "manualLocationLink": "https://maps.google.com/...", // null si GPS fourni

    // Livraison
    "deliveryType": "STANDARD",        // STANDARD | EXPRESS | PROGRAMMER
    "scheduledTime": "14:30",          // null sauf PROGRAMMER
    "deliveryCost": 500,
    "distance": 3.2,                   // km

    // Montants
    "subtotal": 5000,
    "total": 5500,

    // Statut
    "status": "CONFIRMED",             // PENDING | CONFIRMED | DELIVERED | CANCELLED
    "createdAt": "2024-04-10T10:30:00",
    "updatedAt": "2024-04-10T10:35:00",

    // Articles
    "items": [
      {
        "productId": 7,
        "productName": "Gâteau au chocolat",
        "quantity": 2,
        "unitPrice": 1500,
        "totalPrice": 3000
      }
    ]
  },
  "notification": {
    "title": "Nouvelle course disponible",
    "body": "#CMD-20240410-0042 · Standard · 5 500 F"
  }
}

═══════════════════════════════════════════════════════════════
CE QUE L'APP FLUTTER DOIT FAIRE
═══════════════════════════════════════════════════════════════

1. DÉPENDANCE pubspec.yaml :
   supabase_flutter: ^2.x.x

2. INITIALISATION (main.dart) :
   await Supabase.initialize(
     url: 'http://5.189.133.248:8000',
     anonKey: '<anon_key_ci-dessus>',
   );

3. ÉCOUTE REALTIME (dans le widget/service livreur) :
   - S'abonner aux INSERT sur la table `webhook_events`
   - Filtrer sur event = 'ORDER_CONFIRMED' pour afficher les nouvelles courses
   - Pour ORDER_CLAIMED : retirer la course de la liste si elle n'a pas été 
     acceptée par ce livreur (course prise par quelqu'un d'autre)

4. GESTION DES RÔLES :
   Les livreurs n'ont pas de compte Supabase Auth. 
   Ils utilisent l'anon key directement (lecture seule via RLS publique).
   L'authentification livreur est gérée par le backend Spring Boot (JWT).

5. AFFICHAGE D'UNE COURSE (champs prioritaires) :
   - Numéro de commande : orderNumber
   - Adresse : customerAddress (ou lien Google Maps si manualLocationLink présent)
   - GPS : customerLatitude / customerLongitude (si disponibles → afficher carte)
   - Type de livraison : deliveryType
   - Heure programmée : scheduledTime (si PROGRAMMER)
   - Montant total : total (en FCFA)
   - Frais de livraison : deliveryCost
   - Distance estimée : distance (en km)
   - Client : customerName + customerPhone (pour appeler)
   - Articles : items[] avec noms, quantités, prix

6. NETTOYAGE :
   Les anciens événements restent dans la table indéfiniment pour l'instant.
   Ne pas implémenter de purge côté Flutter.

═══════════════════════════════════════════════════════════════
CONTRAINTES IMPORTANTES
═══════════════════════════════════════════════════════════════

- Le Supabase est self-hosted (pas supabase.co) → l'URL est l'IP du serveur
- Le serveur n'a pas de nom de domaine HTTPS pour l'instant → HTTP seulement
  (Android nécessite network_security_config.xml pour autoriser HTTP en clair)
- Un seul livreur actif pour l'instant → pas de système d'assignation complexe
- L'app mobile est Flutter (pas React Native)
```
