# Audit — Intégrations “sources externes” (SPIRIT-LIVRAISON)

Ce document explique **quels renseignements** sont nécessaires pour connecter l’app mobile à une autre application web (REST Polling ou Webhook), **où les saisir** dans l’app mobile, **où ils sont utilisés dans le code**, et **où les trouver** côté application partenaire.

> Important : ne colle jamais de secrets (service account Firebase, clés privées, tokens) dans un chat ou dans le repo. Les clés REST sont stockées en **secure storage** sur le mobile.

---

## TL;DR — Renseignements à récupérer pour connecter une app web

### A) REST Polling (l’app mobile “pull” l’API partenaire)
Tu dois récupérer (côté app web partenaire) :
- **`url`** : endpoint “liste des commandes”
- **`auth_type` + secret** : comment l’API s’authentifie (Bearer / X-API-Key / query param / Basic / none)
- **`response_path`** : où se trouve la liste dans le JSON (ex `data.orders`) si la réponse n’est pas un tableau direct
- **`id_field`** (**obligatoire**) : chemin vers un identifiant unique dans chaque commande (ex `id`, `order.id`, `ref_cmd`)
- **`since_param`** (recommandé) : nom du paramètre pour “commandes modifiées depuis …” (ex `updated_since`)
- **`page_param` + `limit_param` + `page_size`** : si l’API est paginée (ex `page` / `limit`)
- **`field_mapping`** (optionnel) : mapping vers les champs canoniques (`orderNumber`, `customerName`, `total`, etc.) si les noms diffèrent

### B) Webhook (l’app web “push” vers un serveur relais)
Tu dois récupérer / définir :
- **URL webhook** : l’endpoint public du relais (ex `https://relay.exemple.com/webhook`)
- **Secret webhook** (**obligatoire**) : secret HMAC partagé (généré par toi)
- **`source_identifier`** (**obligatoire**) : identifiant stable envoyé dans le champ `source` du payload (ex `shopify_abidjan`)
- **Format payload** : JSON contenant au minimum `event` + `order` (+ `source`) ou le format attendu par ton relais
- **Headers/signature** : comment le partenaire signe le webhook (ex `X-Webhook-Signature: sha256=...`)

---

## Valeurs à renseigner (exemples concrets)

Cette section te donne des **valeurs prêtes à remplir** pour le cas “Sucre Store (Spring) → WebhookRelay → Supabase → Mobile”, et un **template** pour REST polling.

### 0) Important (secrets)
- **Ne mets pas** de secrets dans le repo.
- Dans l’app mobile, la **clé REST** est stockée dans le **secure storage** du téléphone (pas dans SQLite).

---

### 1) Exemple réel — Webhook (Sucre Store → WebhookRelay)

#### À remplir dans l’app mobile (Nouvelle intégration → type `webhook`)
- **Nom plateforme** : `Sucre Store` (au choix)
- **Identifiant / `source_identifier`** (dans la source webhook mobile) :
  - **Valeur réelle** : celle que tu mets dans le backend Spring via `WEBHOOK_SOURCE_IDENTIFIER`
  - **Valeur conseillée** : `sucre_store`
- **Secret webhook** :
  - **Valeur réelle** : la variable d’environnement du backend Spring `WEBHOOK_SECRET`
  - Exemple (à changer) : `change_me_avec_un_secret_fort`

> Pourquoi : le backend Spring envoie `source` dans le payload (`WebhookPayload.source`) et le mobile associe la source via `source_identifier`.

#### À remplir côté backend Spring (STORE)
Fichier : `STORE/src/main/resources/application.yml`
- **URL du relais** (où le backend POST le webhook) :
  - **Valeur réelle par défaut** : `http://127.0.0.1:3001/webhook`
  - **Champ** : `app.webhook.relay-url` / env `WEBHOOK_RELAY_URL`
- **Secret HMAC** :
  - **Valeur réelle par défaut** : `change_me_avec_un_secret_fort` (fallback)
  - **Champ** : `app.webhook.secret` / env `WEBHOOK_SECRET`
- **Activation** :
  - **Valeur réelle par défaut** : `true`
  - **Champ** : `app.webhook.enabled` / env `WEBHOOK_ENABLED`
- **Source identifier** :
  - **Valeur réelle** : vide par défaut (fallback)
  - **Champ** : `app.webhook.source-identifier` / env `WEBHOOK_SOURCE_IDENTIFIER`

#### À remplir côté WebhookRelay (Node)
Fichier : `WebhookRelay/.env` (voir `WebhookRelay/.env.example`)
- **WEBHOOK_SECRET** : doit être **identique** au `WEBHOOK_SECRET` du backend Spring
- **SUPABASE_URL** : URL du projet Supabase
- **SUPABASE_SERVICE_KEY** : clé `service_role` Supabase (secret)
- **ALLOWED_IPS** : optionnel (IP(s) autorisées à appeler le relais)

#### Signature / header attendu (valeurs réelles)
Le relais vérifie (code : `WebhookRelay/webhook/verifySignature.js`) :
- Header : `X-Webhook-Signature: sha256=<hex>`
- Signature : `HMAC-SHA256(body_json, WEBHOOK_SECRET)` encodée en **hex**

---

### 2) Template à remplir — REST Polling (API partenaire → mobile)

Dans l’app mobile (Configurer la source REST), tu peux partir de ces valeurs :

- **URL de l’API** (`url`) :
  - Exemple : `https://api.partenaire.com/orders`
- **Authentification** (`auth_type`) :
  - `none` si public
  - `bearer` si token OAuth/JWT
  - `api_key_header` si clé API header
  - `query_param` si clé en query param (le code utilise `api_key` comme nom)
  - `basic` si Basic Auth (base64)
- **Clé/Token** :
  - valeur fournie par l’app partenaire (secure storage sur le mobile)
- **Chemin vers la liste** (`response_path`) :
  - vide si la réponse est `[...]`
  - ex `data.orders` si `{ "data": { "orders": [...] } }`
- **Champ ID (obligatoire)** (`id_field`) :
  - par défaut : `id`
  - sinon : `order.id` / `ref_cmd` / etc. selon le JSON réel
- **Paramètre since (optionnel)** (`since_param`) :
  - ex `updated_since` / `from` / `since` (selon l’API)
- **Pagination (optionnel)** :
  - `page_param` : `page`
  - `limit_param` : `limit` (ou `per_page`)
  - `page_size` : `50`
- **Mapping (optionnel)** (`field_mapping`) :
  - laisser vide si les noms des champs matchent déjà
  - sinon mapper au minimum :
    - `orderNumber`
    - `customerName`
    - `customerPhone`
    - `customerAddress`
    - `total`
    - `status`
    - `lat`
    - `lng`

> À noter : pour REST polling, les “valeurs réelles” de `response_path`, `id_field`, `since_param`, pagination dépendent entièrement de l’API partenaire. Elles se déterminent uniquement en regardant **une réponse JSON réelle** de son endpoint commandes.

---

## 1) Architecture (ce que fait l’app)

### 1.1 REST Polling (pull)
Tu ajoutes une source `rest_polling` dans l’admin mobile → l’app fait des `GET` périodiques → normalise → insère dans SQLite `orders` (anti-doublons).

- **UI** : `lib/screens/admin/admin_settings_screen.dart`
  - Ajout source : `_AddSourceSheet`
  - Configuration REST : `_RestPollingConfigSheet`
- **Stockage** : SQLite table `external_sources` (config JSON)
  - CRUD : `lib/providers/admin_provider.dart`
- **Polling** : `lib/services/polling_service.dart`
- **HTTP + parsing JSON** : `lib/services/adapters/generic_rest_adapter.dart`
- **Secrets (clé API)** : `lib/services/external_source_secrets.dart`

### 1.2 Webhook (push + temps réel)
Une application web **ne peut pas pousser directement vers un téléphone**. Le webhook doit arriver sur un **serveur relais** (ex: `WebhookRelay` / Supabase Edge Function) qui écrit un événement (`webhook_events`) puis le mobile le reçoit (Realtime).

Dans le mobile, le webhook sert surtout de “signal temps réel”. Le mapping multi-sources est géré par :
- `lib/services/webhook_order_normalizer.dart`

---

## 2) Où saisir les infos dans l’app (admin mobile)

### 2.1 Ajouter une source
Dans l’onglet **Intégrations** :
- Bouton **Nouvelle intégration**
- Choisir type :
  - **Webhook**
  - **REST Polling**

Code : `lib/screens/admin/admin_settings_screen.dart` (`_AddSourceSheet`)

### 2.2 Configurer une source REST
Toujours dans l’onglet **Intégrations** :
- Ouvrir la source REST → **Configurer**

Code : `lib/screens/admin/admin_settings_screen.dart` (`_RestPollingConfigSheet`)

---

## 3) Champs REST Polling à renseigner (obligatoires vs optionnels)

Tous ces champs sont stockés dans `external_sources.configJson` (sauf la clé API) et consommés par `PollingService` / `GenericRestAdapter`.

### 3.1 URL (obligatoire)
- **Champ UI** : “URL de l’API”
- **Clé config** : `url`
- **Utilisation code** : `GenericRestAdapter.fetchRawOrders()` fait un `GET` sur cette URL.

**Où trouver cette info (côté app web partenaire)**
- Documentation API (“List orders endpoint”)
- OU inspecter leur front (DevTools → Network) et repérer l’appel qui liste les commandes.

---

### 3.2 Authentification + clé/token (optionnel selon API)
- **Champ UI** : “Authentification” + “Clé/Token”
- **Clés config** :
  - `auth_type` = `none | bearer | api_key_header | query_param | basic`
  - la **clé** n’est pas dans SQLite : elle est stockée en secure storage.
- **Utilisation code** : `GenericRestAdapter.fetchRawOrders(...)`

**Ce que fait l’app selon `auth_type`**
- `none` : aucun header
- `bearer` : `Authorization: Bearer <token>`
- `api_key_header` : `X-API-Key: <key>`
- `query_param` : ajoute `?api_key=<key>` (nom du paramètre fixé à `api_key`)
- `basic` : `Authorization: Basic <base64(user:password)>`

**Où trouver**
- Portail développeur / backoffice de l’app partenaire (section API Keys)
- Postman/curl fourni par leur doc

---

### 3.3 Response path (optionnel)
Permet de trouver la liste dans une réponse JSON “enveloppée”.

- **Champ UI** : “Chemin vers la liste (dot notation)”
- **Clé config** : `response_path`
- **Utilisation code** : `GenericRestAdapter.fetchRawOrders()` parcourt `data = data[key]` pour chaque segment.

**Comment le choisir**
- Si la réponse est un tableau direct : `[...]` → **laisser vide**
- Sinon, tu mets le chemin :
  - `{ "data": { "orders": [ ... ] } }` → `data.orders`
  - `{ "results": [ ... ] }` → `results`

**Où trouver**
- Dans la réponse JSON du endpoint (via Postman/curl).

---

### 3.4 Champ ID (obligatoire) — anti-collisions
C’est la pièce la plus importante pour éviter les doublons et collisions.

- **Champ UI** : “Champ ID (obligatoire)”
- **Clé config** : `id_field`
- **Utilisation code** :
  - `PollingService` appelle `normalizeOrder(..., source.idFieldPath)`
  - `GenericRestAdapter.normalizeOrder()` lit ce champ pour fabriquer un identifiant externe stable.

**Ce que tu dois choisir**
Un champ unique/stable par commande dans l’objet JSON brut.

Exemples :
- Si la commande contient `{ "id": 123 }` → `id`
- Si `{ "order": { "id": 123 } }` → `order.id`
- Si `{ "ref_cmd": "A-99" }` → `ref_cmd`

**Où trouver**
- Dans l’objet “order” retourné par l’API partenaire.

---

### 3.5 Sync incrémentale “since” (optionnel mais recommandé)
Réduit les téléchargements et accélère la sync.

- **Champ UI** : “Paramètre since (optionnel)”
- **Clé config** : `since_param`
- **Utilisation code** :
  - `PollingService` parse `last_sync_at`
  - `GenericRestAdapter.fetchRawOrders(... since: ...)` ajoute `?{since_param}=<ISO UTC>`

**Où trouver**
- Dans la doc API partenaire (paramètres de filtrage), ex:
  - `updated_since`
  - `from`
  - `since`

---

### 3.6 Pagination page/limit (optionnel)
Si l’API n’envoie pas toutes les commandes d’un coup.

- **Champs UI** : “Paramètre page”, “Paramètre limit”, “Taille de page”
- **Clés config** :
  - `page_param`
  - `limit_param`
  - `page_size`
- **Utilisation code** : `GenericRestAdapter.fetchRawOrders()` boucle sur les pages tant que la page est pleine (avec garde-fou max 20 pages).

**Où trouver**
- Dans la doc API partenaire (pagination)
  - `page` / `limit`
  - ou `page` / `per_page`

---

### 3.7 Field mapping (optionnel)
Permet d’aligner les champs d’une API partenaire sur le modèle attendu par l’app.

- **Champ UI** : “Correspondance des champs”
- **Clé config** : `field_mapping` (JSON)
- **Utilisation code** : `GenericRestAdapter.normalizeOrder()` + `_deepGet(...)`

**Champs canoniques utilisés par l’app**
- `orderNumber`
- `customerName`
- `customerPhone`
- `customerAddress`
- `total`
- `status`
- `lat`
- `lng`

**Où trouver**
- Dans l’objet “order” JSON brut (souvent des champs nested).

---

## 4) Checklist “brancher une nouvelle app web” (REST)

1. Récupérer **un exemple JSON** réel de la réponse `GET /orders` (Postman/curl).
2. Identifier :
   - `url`
   - `response_path` (vide si tableau direct)
   - `id_field` (champ unique stable)
   - auth (type + clé)
   - `since_param` si disponible
   - pagination si nécessaire
3. Configurer la source dans l’admin mobile.
4. Forcer un poll (“sync manuel”) et vérifier :
   - nouvelles commandes insérées
   - pas de doublons
   - `last_sync_at` se met à jour
   - `last_error` reste vide

---

## 5) Où voir les erreurs / debug

### 5.1 Erreurs de sync par source
`PollingService` écrit :
- `last_error` dans `external_sources.configJson`
- `last_sync_at`
- `synced_count`

### 5.2 Logs
Sur mobile/debug, regarder les logs Flutter + les exceptions Dio (timeout, 401, etc.).

---

## 6) Sécurité (à respecter)

### 6.1 Clés API REST
- Sont stockées via `flutter_secure_storage` : `lib/services/external_source_secrets.dart`
- Ne doivent pas rester en clair dans SQLite (`configJson`).

### 6.2 Clés privées Firebase / Service account
Ne doivent jamais être committées ni collées dans l’app mobile.

---

## 7) Si tu me donnes un exemple d’API partenaire…
Pour que je te donne une config “copier-coller” exacte, fournis :
- l’URL de l’endpoint
- un exemple de réponse JSON (anonymisé)
- quels headers/token sont requis
- si l’API a `since` et pagination (nom des paramètres)

---

## Annexe — Champs attendus côté mobile (canonique)

Le modèle mobile sait afficher au minimum :
- `orderNumber`
- `customerName`
- `customerPhone`
- `customerAddress`
- `total`
- `status`
- `lat`
- `lng`

Si l’API partenaire utilise d’autres noms (ou du nested), utilise `field_mapping` en dot-notation.

