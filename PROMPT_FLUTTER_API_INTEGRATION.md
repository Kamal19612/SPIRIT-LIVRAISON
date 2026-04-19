# PROMPT — Intégration API & Base de données Flutter
### Sucre Store · Application Mobile Livreur ↔ Backend Spring Boot

---

> **Objectif :** Connecter l'application Flutter (LoginScreen + DashboardScreen)
> à la vraie base de données PostgreSQL du projet Sucre Store via l'API REST
> Spring Boot existante. L'app mobile doit partager **la même base de données**
> que l'application web, avec une base SQLite locale pour le mode hors-ligne
> et une synchronisation automatique au retour de la connexion.

---

## ARCHITECTURE GLOBALE

```
┌─────────────────────────────────────────────────────────┐
│              APPLICATION FLUTTER (Mobile)               │
│                                                         │
│  ┌──────────────────┐    ┌───────────────────────────┐  │
│  │  SQLite locale   │◄──►│   SyncManager (auto-sync) │  │
│  │  (sqflite)       │    │   au retour connexion      │  │
│  └──────────────────┘    └────────────┬──────────────┘  │
│                                       │                 │
│  ┌──────────────────────────────────────────────────┐   │
│  │         ApiClient (Dio + Intercepteurs JWT)       │   │
│  └──────────────────────────┬─────────────────────-─┘   │
└───────────────────────────── │ ──────────────────────────┘
                               │ HTTPS / HTTP
┌──────────────────────────────▼──────────────────────────┐
│        BACKEND SPRING BOOT  (port 8081)                 │
│        /api/auth/**  /api/delivery/**  /api/public/**   │
└──────────────────────────────┬──────────────────────────┘
                               │ JPA / Hibernate
┌──────────────────────────────▼──────────────────────────┐
│          PostgreSQL  — base "dbstore"                   │
│          Tables: orders, users, order_items, ...        │
└─────────────────────────────────────────────────────────┘
```

---

## INFORMATIONS BACKEND RÉELLES

| Paramètre        | Valeur                                      |
|------------------|---------------------------------------------|
| URL Dev (local)  | `http://172.18.0.3:8081`                   |
| URL Production   | `https://api.sucrestore.com`               |
| Base de données  | PostgreSQL `dbstore` sur `localhost:5432`  |
| Auth             | JWT Bearer Token (durée : 7 jours)         |
| Timeout API      | 10 000 ms                                   |

---

## ENDPOINTS API RÉELS

### Authentification

| Méthode | Endpoint           | Auth requise | Description                    |
|---------|--------------------|--------------|--------------------------------|
| POST    | `/api/auth/login`  | Non          | Connexion, retourne JWT        |
| POST    | `/api/auth/logout` | Oui          | Invalide la session côté serveur|

**Body login (JSON) :**
```json
{ "username": "livreur_01", "password": "motdepasse" }
```

**Réponse login (JSON) :**
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "username": "livreur_01",
  "roles": ["ROLE_DELIVERY_AGENT"]
}
```

> Le token JWT doit être envoyé dans chaque requête protégée :
> `Authorization: Bearer <token>`

---

### Commandes Livreur

Toutes ces routes nécessitent le rôle `ROLE_DELIVERY_AGENT` ou `ROLE_ADMIN`.

| Méthode | Endpoint                              | Description                          |
|---------|---------------------------------------|--------------------------------------|
| GET     | `/api/delivery/orders`                | Commandes disponibles (CONFIRMED, sans livreur) — paginé |
| GET     | `/api/delivery/orders/my-orders`      | Mes commandes prises en charge — paginé |
| PUT     | `/api/delivery/orders/{id}/claim`     | Accepter une commande                |
| POST    | `/api/delivery/orders/{id}/complete`  | Valider livraison avec code          |
| GET     | `/api/delivery/orders/sync?lastSync=` | Sync delta depuis une date ISO8601   |

**Body complete (JSON) :**
```json
{ "code": "123456" }
```

**Réponse paginée (GET orders) :**
```json
{
  "content": [ { ...order }, { ...order } ],
  "totalElements": 12,
  "totalPages": 1,
  "number": 0,
  "size": 20
}
```

**Objet Order complet :**
```json
{
  "id": 1,
  "orderNumber": "ORD-2024-0001",
  "confirmationCode": "847291",
  "customerName": "Jean Dupont",
  "customerPhone": "+224 620 000 000",
  "customerAddress": "Quartier Hamdallaye, Rue KA-123, Conakry",
  "customerNotes": "Sonner 2 fois",
  "customerLatitude": 9.5370,
  "customerLongitude": -13.6773,
  "deliveryType": "STANDARD",
  "scheduledTime": null,
  "deliveryCost": 2000,
  "distance": 4.5,
  "subtotal": 13000,
  "tax": 0,
  "total": 15000,
  "status": "CONFIRMED",
  "createdAt": "2024-01-15T14:32:00",
  "updatedAt": "2024-01-15T14:35:00",
  "deleted": false,
  "deliveryAgent": null,
  "items": [
    { "id": 1, "productName": "Gâteau chocolat", "quantity": 2, "unitPrice": 5000, "total": 10000 }
  ]
}
```

**Statuts possibles :**
`PENDING` → `CONFIRMED` → `SHIPPED` → `DELIVERED` / `CANCELLED`

---

### Paramètres publics

| Méthode | Endpoint               | Auth requise | Description               |
|---------|------------------------|--------------|---------------------------|
| GET     | `/api/public/settings` | Non          | Infos boutique (nom, adresse, téléphone) |

**Réponse settings :**
```json
{
  "store_name": "SUCRE STORE",
  "contact_address": "Kaloum, Centre Ville, Conakry",
  "whatsapp_number": "+226 XX XX XX XX",
  "store_location": "Kaloum Conakry"
}
```

---

## PACKAGES FLUTTER REQUIS

```yaml
dependencies:
  flutter:
    sdk: flutter

  # HTTP Client
  dio: ^5.4.0

  # Stockage sécurisé du JWT
  flutter_secure_storage: ^9.0.0

  # Base de données locale SQLite
  sqflite: ^2.3.0
  path: ^1.9.0

  # Détection réseau (online/offline)
  connectivity_plus: ^5.0.0

  # Gestion d'état simple
  provider: ^6.1.0
```

---

## STRUCTURE DES FICHIERS

```
lib/
├── main.dart
│
├── config/
│   └── app_config.dart          ← URLs, timeouts, constantes
│
├── models/
│   ├── order_model.dart         ← Classe Order + fromJson/toJson
│   └── user_model.dart          ← Classe User (username, roles, token)
│
├── services/
│   ├── api_client.dart          ← Dio + intercepteurs JWT
│   ├── auth_service.dart        ← login(), logout()
│   └── order_service.dart       ← fetchAvailable(), fetchMyOrders(), claim(), complete()
│
├── database/
│   ├── local_database.dart      ← initDatabase(), tables SQLite
│   └── orders_dao.dart          ← CRUD local orders + pending_actions
│
├── providers/
│   ├── auth_provider.dart       ← état auth (user, token, isAuthenticated)
│   └── orders_provider.dart     ← état commandes + sync
│
├── sync/
│   └── sync_manager.dart        ← auto-sync au retour connexion
│
├── screens/
│   ├── login_screen.dart
│   └── dashboard_screen.dart
│
└── widgets/
    ├── network_banner.dart
    └── order_card.dart
```

---

## IMPLÉMENTATION DÉTAILLÉE

### 1. `lib/config/app_config.dart`

```dart
class AppConfig {
  // Changer selon l'environnement
  static const bool isDebug = true;

  static String get baseUrl => isDebug
      ? 'http://172.18.0.3:8081'       // Dev : IP du serveur local
      : 'https://api.sucrestore.com';   // Production

  static const int apiTimeout = 10000; // ms

  // Endpoints
  static const String login        = '/api/auth/login';
  static const String logout       = '/api/auth/logout';
  static const String settings     = '/api/public/settings';
  static const String delivOrders  = '/api/delivery/orders';
  static const String delivMyOrders= '/api/delivery/orders/my-orders';
  static const String delivSync    = '/api/delivery/orders/sync';
}
```

---

### 2. `lib/models/order_model.dart`

Crée une classe `Order` avec tous ces champs (types Dart) :

| Champ JSON          | Type Dart        |
|---------------------|------------------|
| id                  | int              |
| orderNumber         | String           |
| confirmationCode    | String?          |
| customerName        | String           |
| customerPhone       | String           |
| customerAddress     | String           |
| customerNotes       | String?          |
| customerLatitude    | double?          |
| customerLongitude   | double?          |
| deliveryType        | String?          |
| deliveryCost        | double?          |
| distance            | double?          |
| subtotal            | double           |
| tax                 | double           |
| total               | double           |
| status              | String           |
| createdAt           | String           |
| updatedAt           | String?          |
| deleted             | bool             |
| deliveryAgent       | Map?             |
| items               | List\<Map\>      |

Implémenter :
- `Order.fromJson(Map<String, dynamic> json)` — gérer `BigDecimal` du backend qui arrive comme `String` ou `num`
- `Map<String, dynamic> toJson()`
- `Order.fromSqlite(Map<String, dynamic> row)` — pour lecture SQLite locale

---

### 3. `lib/models/user_model.dart`

```dart
class UserModel {
  final String token;
  final String username;
  final List<String> roles;

  bool get isDeliveryAgent => roles.contains('ROLE_DELIVERY_AGENT');
  bool get isAdmin =>
      roles.contains('ROLE_ADMIN') || roles.contains('ROLE_SUPER_ADMIN');
  bool get hasDeliveryAccess => isDeliveryAgent || isAdmin;
}
```

---

### 4. `lib/services/api_client.dart` — Dio avec intercepteurs JWT

Configurer une instance Dio avec :

**Intercepteur requête :**
- Lire le token depuis `flutter_secure_storage` (clé : `"jwt_token"`)
- Si token présent : ajouter `Authorization: Bearer <token>` dans les headers
- Si token absent : laisser passer (routes publiques)

**Intercepteur réponse :**
- Si code `401` : effacer token en storage + naviguer vers LoginScreen
- Si code `409` : commande déjà assignée → message `"Cette commande a déjà été prise"`
- Si pas de réponse (erreur réseau) : throw `Exception("Pas de connexion internet")`
- Timeout (DioException `connectTimeout` / `receiveTimeout`) : throw `Exception("Serveur injoignable")`

**Configuration Dio :**
```
connectTimeout : Duration(milliseconds: 10000)
receiveTimeout : Duration(milliseconds: 10000)
headers : { 'Content-Type': 'application/json' }
```

---

### 5. `lib/services/auth_service.dart`

**`Future<UserModel> login(String username, String password)`**
1. `POST /api/auth/login` body `{ "username": username, "password": password }`
2. Extraire `token`, `username`, `roles` de la réponse
3. Sauvegarder dans `flutter_secure_storage` :
   - clé `"jwt_token"` → valeur `token`
   - clé `"username"` → valeur `username`
   - clé `"roles"` → valeur `roles.join(",")` (string séparé virgule)
4. Retourner `UserModel`
5. Si statut `401` → throw `Exception("Identifiants incorrects")`
6. Si `roles` ne contient ni `ROLE_DELIVERY_AGENT` ni `ROLE_ADMIN` → throw `Exception("Accès réservé aux livreurs")`

**`Future<void> logout()`**
1. Appeler `POST /api/auth/logout` (best effort, ignorer erreur réseau)
2. Effacer toutes les clés du storage sécurisé
3. Effacer la base SQLite locale (table orders + pending_actions)

**`Future<UserModel?> tryRestoreSession()`**
- Lire `jwt_token`, `username`, `roles` depuis le storage sécurisé
- Si token présent → retourner `UserModel` reconstruit
- Sinon → retourner `null`

---

### 6. `lib/services/order_service.dart`

**`Future<List<Order>> fetchAvailableOrders(bool isOnline)`**
- Si online : `GET /api/delivery/orders`
  - Parser `data["content"] ?? data` → `List<Order>`
  - Appeler `ordersDao.saveOrders(orders)` (cache local)
  - Retourner la liste
- Si offline : `ordersDao.getAvailableOrders()` depuis SQLite

**`Future<List<Order>> fetchMyOrders(bool isOnline)`**
- Si online : `GET /api/delivery/orders/my-orders`
  - Même pattern que ci-dessus
- Si offline : `ordersDao.getMyOrders()` depuis SQLite

**`Future<Order> claimOrder(int orderId, bool isOnline)`**
- Si online : `PUT /api/delivery/orders/$orderId/claim`
  - Retourner `Order.fromJson(data)`
- Si offline :
  - `ordersDao.claimOrderLocal(orderId)`
  - `ordersDao.savePendingAction("CLAIM", orderId, {})`
  - Retourner objet partiel

**`Future<Order> completeDelivery(int orderId, String code, bool isOnline)`**
- Si online : `POST /api/delivery/orders/$orderId/complete` body `{ "code": code }`
  - Si code `400` → throw `Exception("Code de validation incorrect")`
- Si offline :
  - `ordersDao.completeOrderLocal(orderId)`
  - `ordersDao.savePendingAction("COMPLETE", orderId, { "code": code })`

**`Future<Map<String, String>> fetchSettings()`**
- `GET /api/public/settings` (sans auth)
- Retourner la map clé/valeur

---

### 7. `lib/database/local_database.dart` — SQLite

Créer 3 tables :

```sql
-- Table des commandes
CREATE TABLE IF NOT EXISTS orders (
  id               INTEGER PRIMARY KEY,
  orderNumber      TEXT NOT NULL,
  customerName     TEXT,
  customerAddress  TEXT,
  customerPhone    TEXT,
  total            REAL DEFAULT 0,
  status           TEXT DEFAULT 'CONFIRMED',
  createdAt        TEXT,
  deliveryAgentId  INTEGER,
  syncStatus       TEXT DEFAULT 'synced'
);

-- Table des actions en attente (offline queue)
CREATE TABLE IF NOT EXISTS pending_actions (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  action_type TEXT NOT NULL,
  order_id    INTEGER,
  payload     TEXT,
  created_at  TEXT DEFAULT (datetime('now')),
  retries     INTEGER DEFAULT 0
);

-- Métadonnées de synchronisation
CREATE TABLE IF NOT EXISTS sync_meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);
```

---

### 8. `lib/database/orders_dao.dart` — CRUD SQLite

Implémenter ces méthodes :

**`saveOrders(List<Order> orders)`**
- Transaction atomique
- `DELETE FROM orders WHERE syncStatus = 'synced'` (ne pas toucher les pending)
- `INSERT OR REPLACE INTO orders (...)` pour chaque order

**`getAvailableOrders()`**
- `SELECT * FROM orders WHERE status = 'CONFIRMED' AND deliveryAgentId IS NULL ORDER BY createdAt DESC`
- Mapper vers `List<Order>`

**`getMyOrders()`**
- `SELECT * FROM orders WHERE status IN ('SHIPPED', 'CLAIMED') ORDER BY createdAt DESC`
- Mapper vers `List<Order>`

**`claimOrderLocal(int orderId)`**
- `UPDATE orders SET status = 'SHIPPED', syncStatus = 'pending' WHERE id = ?`

**`completeOrderLocal(int orderId)`**
- `UPDATE orders SET status = 'DELIVERED', syncStatus = 'pending' WHERE id = ?`

**`savePendingAction(String type, int orderId, Map payload)`**
- `INSERT INTO pending_actions (action_type, order_id, payload) VALUES (?, ?, ?)`
- `payload` sérialisé en JSON string

**`getPendingActions()`**
- `SELECT * FROM pending_actions ORDER BY created_at ASC`

**`deletePendingAction(int id)`**
- `DELETE FROM pending_actions WHERE id = ?`

**`setLastSyncTime(DateTime time)`** / **`getLastSyncTime()`**
- `INSERT OR REPLACE INTO sync_meta (key, value) VALUES ('last_sync', ?)`
- Lire/écrire le timestamp ISO8601

---

### 9. `lib/sync/sync_manager.dart` — Synchronisation automatique

Classe ou mixin utilisable dans `OrdersProvider` :

```
ALGORITHME SYNC (déclenché au retour en ligne) :

1. pushPendingActions()
   └── Lire pending_actions depuis SQLite
   └── Pour chaque action :
       ├── CLAIM   → PUT /api/delivery/orders/{id}/claim
       ├── COMPLETE → POST /api/delivery/orders/{id}/complete  { code }
       └── Si succès → deletePendingAction(id)
       └── Si erreur → incrémenter retries, continuer (ne pas bloquer)

2. pullOrdersFromServer()
   └── GET /api/delivery/orders         (disponibles)
   └── GET /api/delivery/orders/my-orders (mes courses)
   └── Fusionner les 2 listes (dédupliquer par id)
   └── saveOrders(all)
   └── setLastSyncTime(DateTime.now())

3. Notifier les providers → UI se rafraîchit automatiquement
```

**Déclenchement :**
- Utiliser `connectivity_plus` pour écouter les changements réseau
- Quand `ConnectivityResult != none` ET état précédent était `none` → déclencher sync
- Ne pas déclencher si une sync est déjà en cours (flag `_isSyncing`)

---

### 10. `lib/providers/auth_provider.dart`

State géré :
- `UserModel? user`
- `bool isLoading`
- `String? errorMessage`
- `bool get isAuthenticated => user != null`

Méthodes :
- `init()` → appeler `authService.tryRestoreSession()` au démarrage
- `login(username, password)` → appeler service, notifier
- `logout()` → appeler service, reset state

---

### 11. `lib/providers/orders_provider.dart`

State géré :
- `List<Order> availableOrders`
- `List<Order> myOrders`
- `bool isLoading`
- `bool isRefreshing`
- `bool isOnline`
- `Map<String, String> shopSettings`
- `String? error`

Méthodes :
- `init()` → charger settings + surveiller réseau + premier chargement
- `loadOrders(String tab)` → charger selon onglet actif
- `refresh()` → forcer rechargement
- `claimOrder(int id)` → appel service + retirer de availableOrders
- `completeDelivery(int id, String code)` → appel service + retirer de myOrders
- `_onConnectivityChanged(result)` → mise à jour `isOnline` + déclencher sync si retour en ligne

---

### 12. `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.init();  // Initialiser SQLite
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
      ],
      child: const SucreStoreApp(),
    ),
  );
}
```

`MaterialApp` :
- `initialRoute` : toujours `/login`
- Dans `LoginScreen` : lire `authProvider.isAuthenticated` au build,
  si `true` → `Navigator.pushReplacementNamed(context, '/dashboard')`
- Routes : `/login` → `LoginScreen`, `/dashboard` → `DashboardScreen`

---

## CONNEXION UI → PROVIDERS

### LoginScreen

Remplacer le mock par :
```dart
final auth = Provider.of<AuthProvider>(context, listen: false);

// onTap "Se connecter"
await auth.login(usernameController.text, passwordController.text);
if (auth.isAuthenticated) {
  Navigator.pushReplacementNamed(context, '/dashboard');
} else {
  setState(() => error = auth.errorMessage);
}
```

---

### DashboardScreen

```dart
final orders = Provider.of<OrdersProvider>(context);
final auth   = Provider.of<AuthProvider>(context, listen: false);

// Header : afficher auth.user?.username
// isOnline : orders.isOnline → NetworkBanner
// Onglet Disponibles : orders.availableOrders
// Onglet Mes Courses : orders.myOrders
// shopInfo : orders.shopSettings

// Refresh button
onTap: () => orders.refresh()

// Logout
onTap: () async {
  await auth.logout();
  Navigator.pushReplacementNamed(context, '/login');
}
```

---

### OrderCard

```dart
// Accepter la course
onClaim: (id) => orders.claimOrder(id)

// Valider livraison
onComplete: (id, code) => orders.completeDelivery(id, code)
```

---

## GESTION ERREURS RÉSEAU — RÈGLES UI

| Situation               | Comportement attendu                                      |
|-------------------------|-----------------------------------------------------------|
| Serveur injoignable     | `NetworkBanner` visible + charger depuis SQLite locale    |
| Token expiré (401)      | Effacer token + rediriger vers LoginScreen automatiquement|
| Commande déjà prise (409)| Snackbar `"Cette commande vient d'être prise par un autre livreur"` |
| Code invalide (400)     | Message rouge sous le champ code : `"Code incorrect"`     |
| Retour en ligne         | Sync automatique + disparition NetworkBanner              |
| Timeout                 | Message `"Connexion trop lente, réessayez"`               |

---

## FLUX COMPLET — MODE HORS-LIGNE

```
Livreur sans connexion :
  1. Ouvre l'app → load depuis SQLite (dernière sync connue)
  2. NetworkBanner s'affiche (orange)
  3. Accepte une course → sauvegardé localement en "pending"
     SQLite: status='SHIPPED', syncStatus='pending'
     pending_actions: { action_type:'CLAIM', order_id: 5 }
  4. Valide livraison → sauvegardé localement en "pending"
     SQLite: status='DELIVERED', syncStatus='pending'
     pending_actions: { action_type:'COMPLETE', order_id: 5, code:'123456' }

Connexion rétablie (auto) :
  5. SyncManager détecte retour online
  6. pushPendingActions():
     → PUT /api/delivery/orders/5/claim
     → POST /api/delivery/orders/5/complete { code: "123456" }
     → Supprime actions de la queue SQLite
  7. pullOrdersFromServer():
     → Récupère état frais depuis PostgreSQL
     → Met à jour SQLite
  8. UI rafraîchit automatiquement via Provider notify
  9. NetworkBanner disparaît
```

---

## CONTRAINTES IMPÉRATIVES

1. **Jamais de token JWT en clair** — utiliser exclusivement `flutter_secure_storage`
2. **Toujours gérer le cas offline** — chaque appel API a un fallback SQLite
3. **Une seule sync à la fois** — flag `_isSyncing` pour éviter les doublons
4. **Conserver les `pending_actions`** lors du `saveOrders` — ne supprimer que les `syncStatus='synced'`
5. **Le `confirmationCode`** de la commande est côté client (lecture seule). Le livreur entre le **code que le client lui communique verbalement**. Ces deux codes doivent correspondre côté serveur.
6. **Le backend retourne les montants en `BigDecimal`** (peut arriver comme String ou double) — parser avec `double.tryParse(value.toString()) ?? 0.0`
7. Code 100% compilable Flutter 3.x stable, sans erreur

---

## RAPPEL — DESIGN SYSTEM

Conserver exactement les couleurs, spacing et composants décrits dans
`PROMPT_FLUTTER_LIVRAISON.md`. Ce prompt ne remplace pas le design,
il ajoute uniquement la couche données/réseau par-dessus.

---

*Sucre Store · Prompt API Integration généré le 09/04/2026*
