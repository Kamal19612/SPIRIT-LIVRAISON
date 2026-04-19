# AUDIT PROJET APPSTORE - Sucre Store Livreur

**Date** : 14 Avril 2026  
**Plateforme** : Flutter (Multiplateforme - Desktop, Android, iOS, Web)  
**Architecture** : Offline-First avec State Management Provider

---

## 📋 TABLE DES MATIÈRES

1. [Point d'entrée](#1-point-dentrée)
2. [Configuration](#2-configuration)
3. [State Management](#3-state-management-providers)
4. [Services métier](#4-services-logique-métier-stateless)
5. [Base de données](#5-base-de-données-sqlite)
6. [Modèles de données](#6-modèles-de-données)
7. [Widgets UI](#7-widgets-ui)
8. [Screens](#8-screens)
9. [Services avancés](#9-services-avancés)
10. [Synthèse architecture](#-synthèse-de-larchitecture)
11. [Points forts & Attention](#-points-forts-et-attention)

---

## 1. Point d'entrée

### `lib/main.dart`

**Rôle** : Point d'entrée unique de l'application  
**Criticité** : 🔴 **CRITIQUE**

**Responsabilités** :
- Initialise le binding Flutter
- Configure la base de données SQLite via `LocalDatabase.instance.init()`
- Initialise le service de notifications `NotificationService.instance.init()`
- Restaure la session utilisateur depuis `AuthProvider.init()`
- Configure le `MultiProvider` qui expose les providers globaux à toute l'app
- Définit les 3 routes principales :
  - `/login` → `LoginScreen`
  - `/dashboard` → `DashboardScreen`
  - `/admin` → `AdminShell`
- Applique la configuration UI (thème, label app)

**Providers initialisés** :
- `AuthProvider` (valeur restaurée)
- `AppConfigProvider` (valeur restaurée)
- `PollingService` (valeur restaurée et start())
- `OrdersProvider` (nouveau)
- `AdminProvider` (nouveau)
- `LocationService` (nouveau)

**État** : ✅ Bien structuré, initialization complète

---

## 2. Configuration

### `lib/config/app_config.dart`

**Rôle** : Constantes centralisées de l'application  
**Criticité** : 🟡 **BASSE**

**Contient** :
```
dbName     = 'delivery_manager.db'
dbVersion  = 3
defaultAppName      = 'Delivery Manager'
defaultLogoUrl      = ''
defaultPrimaryColor = '#F5AD41'
```

**Utilisation** : Référencé par `LocalDatabase` et `AppConfigProvider`

### `lib/config/navigation.dart`

**Rôle** : Navigation globale hors contexte  
**Criticité** : 🟡 **MOYENNE**

**Contient** :
```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
```

**Permet** : Navigation depuis services/exceptions sans `BuildContext`

---

## 3. State Management (Providers)

### `lib/providers/auth_provider.dart`

**Rôle** : Gère l'état d'authentification global  
**Criticité** : 🔴 **CRITIQUE**  
**Type** : `ChangeNotifier`

**État stocké** :
- `_user` : `UserModel?` - Utilisateur actuel (null = déconnecté)
- `_isLoading` : Indicateur login/logout en cours
- `_isInitializing` : Indicateur restauration session au startup
- `_errorMessage` : Message d'erreur d'authentification

**Getter publiques** :
- `user` → L'utilisateur connecté
- `isAuthenticated` → `user != null`
- `isLoading`, `isInitializing`, `errorMessage`

**Méthodes clés** :
- `init()` : Restaure la session au démarrage via `AuthService.tryRestoreSession()`
- `login(username, password)` : Appelle `AuthService.login()` et stocke le user
- `logout()` : Appelle `AuthService.logout()` et vide `_user`

**Flux de routing** :
```
AuthProvider.isAuthenticated == false  → /login
AuthProvider.isAuthenticated == true   → /dashboard (ou /admin si ADMIN role)
```

**Importance** : **CRITIQUE** - Contrôle l'accès complet à l'application

---

### `lib/providers/orders_provider.dart`

**Rôle** : Gère les commandes (disponibles, mes commandes, localisation, distance)  
**Criticité** : 🔴 **CRITIQUE**  
**Type** : `ChangeNotifier`

**État stocké** :
- `_availableOrders` : Commandes à réclamer (status=CONFIRMED, no agent)
- `_myOrders` : Commandes assignées à moi (status=SHIPPED ou CLAIMED)
- `_isLoading` : Chargement initial
- `_isRefreshing` : Refresh en cours
- `_error` : Messages d'erreur
- `_driverLat`, `_driverLng` : Position actuelle du livreur

**Getters publiques** :
- `availableOrders`
- `myOrders`
- `isLoading`, `isRefreshing`, `error`

**Méthodes clés** :
1. `init()` : Charge les commandes au démarrage
   - `OrderService.fetchAvailableOrders()` → retrie par distance
   - `OrderService.fetchMyOrders()` → récupère mes commandes

2. `loadOrders(String tab)` : Charge spécifiquement un onglet

3. `updateDriverLocation(lat, lng)` :
   - Met à jour `_driverLat`, `_driverLng`
   - **Recalcule distance** pour chaque commande via Haversine
   - **Retrie** les disponibles par distance croissante

4. `_haversine(lat1, lon1, lat2, lon2)` → double (km) :
   - Formule grande-cercle
   - Rayon Terre = 6371 km

5. `_sortByDistance(List<Order>)` → List<Order> triée

6. `claimOrder(int orderId)` → via `OrderService.claimOrder()`

7. `completeDelivery(int orderId, String code)` :
   - Vérifie le code de confirmation
   - Appelle `OrderService.completeDelivery()`

**Importance** : **CRITIQUE** - Cœur métier de l'app livreur

---

### `lib/providers/app_config_provider.dart`

**Rôle** : Gère la configuration dynamique de l'app (branding)  
**Criticité** : 🟡 **MOYENNE**  
**Type** : `ChangeNotifier`

**État stocké** :
- `_appName` : Nom app (ex: "Sucre Store")
- `_logoUrl` : URL du logo
- `_primaryColor` : Couleur primaire (Color object)
- `_contactPhone` : Téléphone de support
- `_contactAddress` : Adresse de support

**Source** : `AppConfigService.getAll()` (depuis SQLite)

**Méthodes clés** :
- `init()` : Charge config depuis BD
- `save(...)` : Persiste nouvelle config
- `_parseColor(hex)` : Parse hex #RRGGBB → Color

**Importance** : **MOYENNE** - Personnalisation UI dynamique

---

## 4. Services (Logique métier stateless)

### `lib/services/auth_service.dart`

**Rôle** : Points d'accès unique pour l'authentification  
**Criticité** : 🔴 **CRITIQUE**  
**Pattern** : Singleton (`instance`)

**Stockage sécurisé** : `FlutterSecureStorage`

**Méthodes clés** :

1. `login(username, password)` → `UserModel` :
   - Récupère l'utilisateur depuis table `users` (SQLite)
   - Valide mot de passe via SHA-256 hash
   - Valide rôle ∈ [DELIVERY_AGENT, ADMIN, SUPER_ADMIN]
   - Stocke: `user_id`, `username`, `role` en SecureStorage
   - Retourne `UserModel(id, username, role)`
   - 🔒 **Mode offline** : Pas d'appel API, simple hash local

2. `logout()` → void :
   - `_storage.deleteAll()` - Vide SecureStorage complet

3. `tryRestoreSession()` → `UserModel?` :
   - Lit `user_id`, `username`, `role` depuis SecureStorage
   - Reconstruit et retourne `UserModel` si trouvé
   - Retourne null si aucun stockage

4. `getCurrentUserId()` → `int?` :
   - Retourne l'ID du livreur connecté actuellement

**Sécurité** :
- ✅ Hash SHA-256 (non-réversible)
- ✅ Stockage sécurisé (FlutterSecureStorage = Keychain/Keystore)
- ✅ Validation rôle
- ✅ Authentification offline possible

**Importance** : **CRITIQUE** - Accès unique à l'authentification

---

### `lib/services/order_service.dart`

**Rôle** : Logique métier des commandes  
**Criticité** : 🔴 **CRITIQUE**  
**Pattern** : Singleton

**Données** : Via `OrdersDao.instance` (SQLite)

**Méthodes clés** :

1. `fetchAvailableOrders()` → `List<Order>` :
   - `_dao.getAvailableOrders()`
   - SELECT * FROM orders WHERE status='CONFIRMED' AND deliveryAgentId IS NULL

2. `fetchMyOrders()` → `List<Order>` :
   - Récupère userId actuel
   - `_dao.getMyOrders(userId)`

3. `claimOrder(orderId)` → void :
   - Récupère userId
   - `_dao.claimOrderLocal(orderId, userId)`
   - UPDATE → status='SHIPPED', deliveryAgentId=userId

4. `completeDelivery(orderId, code)` → void :
   - Charge la commande
   - **Valide** confirmationCode (si défini)
   - `_dao.completeOrderLocal(orderId)`
   - UPDATE → status='DELIVERED'
   - ✅ Vérification code de confirmation obligatoire

**Importance** : **CRITIQUE** - Métier livreur

---

### `lib/services/app_config_service.dart`

**Rôle** : Interface config app ↔ BD  
**Criticité** : 🟡 **MOYENNE**

**Méthodes** :
- `getAll()` → Map<String, String> : Récupère config depuis table `app_config`
- `save(Map)` → void : Persiste config

---

### `lib/services/notification_service.dart`

**Rôle** : Notifications locales + webhook parsing  
**Criticité** : 🟢 **HAUTE** (alertes livreur)  
**Pattern** : Singleton

**Dépendance** : `flutter_local_notifications`

**Initialisation** :
- Crée canal Android "delivery_orders" importance=HIGH
- Demande permissions Android 13+
- Enregistre callbacks

**Callbacks** :

1. `_onNotificationTap(NotificationResponse)` (foreground) :
   - Parse `payload` JSON (webhook data)
   - Appelle `WebhookEventHandler` pour traiter

2. `_onNotificationTapBackground(NotificationResponse)` (background, isolate séparé) :
   - Fonction **top-level** (required pour background)
   - Ne peut pas accéder aux providers UI
   - Simplement log

**Méthode** :
- `show(id, title, body, payload)` : Affiche notification

**Importance** : **HAUTE** - Alertes en temps réel du livreur

---

### `lib/services/polling_service.dart`

**Rôle** : Sync périodique des sources externes REST  
**Criticité** : 🟢 **HAUTE** (rafraîchissement offline)  
**Pattern** : Singleton + ChangeNotifier + Timer

**Fonctionnement** :
- `Timer.periodic(2 minutes)` → `_pollAll()`
- Chaque source REST : appel via `GenericRestAdapter`
- Nouvelles commandes → SQLite + notification

**État** (ChangeNotifier) :
```dart
Map<int, SourceState> _states
  ├─ status : idle / syncing / ok / error
  ├─ errorMessage
  └─ newOrdersCount
```

**Lifecycle** :
- `start()` : Lance timer + poll initial (5s)
- `stop()` : Arrête timer
- `dispose()` : Cleanup

**Importance** : **HAUTE** - Rafraîchit commandes en arrière-plan

---

### `lib/services/location_service.dart`

**Rôle** : Géolocalisation du livreur en temps réel  
**Criticité** : 🟡 **MOYENNE**

**Source** : Package `geolocator`

**Utilisation** : `OrdersProvider.updateDriverLocation()` pour trier par distance

---

### `lib/services/webhook_event_handler.dart`

**Rôle** : Parse + traite webhooks (nouvelles commandes)  
**Criticité** : 🟢 **HAUTE** (intégration multi-plateforme)

**Flux** :
1. Webhook arrive (notification)
2. Payload JSON parsé
3. `Order` reconstruit
4. Inséré en SQLite
5. Notification affichée

---

### `lib/services/webhook_signature_verifier.dart`

**Rôle** : Sécurité webhooks  
**Criticité** : 🟢 **HAUTE**

**Validation** : Vérifie signature HMAC-SHA256 du webhook
- Empêche les faux webhooks

---

### `lib/services/adapters/generic_rest_adapter.dart`

**Rôle** : Adapter générique pour APIs externes  
**Criticité** : 🟡 **MOYENNE**

**Permet** : Intégration multi-source via adapter abstrait

---

## 5. Base de données (SQLite)

### `lib/database/local_database.dart`

**Rôle** : Initialisation + schéma SQLite  
**Criticité** : 🔴 **CRITIQUE**  
**Pattern** : Singleton

**Fichier** : `delivery_manager.db` v3

**Plateforme** : Mode FFI pour desktop (Windows/Linux/macOS)

**Initialisation** :
- `init()` : Crée DB + tables si nouvelle
- `onCreate()` : Migration 0 → 3
- `onUpgrade()` : Schemas version précédentes

**Tables créées** :

1. **users**
   ```sql
   id (PK) | username (UNIQUE) | password (SHA-256) | role | active | fcm_token | created_at
   ```

2. **orders**
   ```sql
   id (PK) | orderNumber | confirmationCode | customerName | customerAddress
   customerPhone | customerNotes | customerLat | customerLng
   total | status (CONFIRMED/SHIPPED/DELIVERED) | sourcePlatform
   syncStatus | createdAt | updatedAt | deliveryAgentId
   ```

3. **driver_locations**
   ```sql
   id (PK) | driver_id (UNIQUE) | lat | lng | updated_at
   ```

4. **app_config**
   ```sql
   key (PK) | value
   ```

**Importance** : **CRITIQUE** - Base de toutes les données persistantes

---

### `lib/database/orders_dao.dart`

**Rôle** : Data Access Object (DAO) pour commandes  
**Criticité** : 🔴 **CRITIQUE**  
**Pattern** : Singleton

**Méthodes LECTURE** :

1. `getAvailableOrders()` → List<Order> :
   - SELECT * FROM orders WHERE status='CONFIRMED' AND deliveryAgentId IS NULL

2. `getMyOrders(userId)` → List<Order> :
   - SELECT * FROM orders WHERE status IN ('SHIPPED','CLAIMED') AND deliveryAgentId=userId

3. `getAllOrders()` → List<Order> :
   - SELECT * (debug/admin)

4. `getOrderById(orderId)` → Order?

5. `getOrderByNumber(orderNumber)` → Order?

6. `getOrderCounts()` → Map<status, count>

**Méthodes ÉCRITURE** :

1. `insertOrder(Order)` → int (id) :
   - INSERT avec REPLACE conflict

2. `saveOrders(List<Order>)` → void :
   - Transaction : insère multiple

3. `claimOrderLocal(orderId, userId)` → void :
   - UPDATE status='SHIPPED', deliveryAgentId=userId

4. `completeOrderLocal(orderId)` → void :
   - UPDATE status='DELIVERED'

**Sérialisation** :
- `Order.fromSqlite(Map)` : Désérialise depuis SQLite
- `_toRow(Order)` : Sérialise en Map

**Importance** : **CRITIQUE** - Accès unique aux commandes

---

### `lib/database/drivers_dao.dart`

**Rôle** : DAO pour gestion livreurs  
**Criticité** : 🟡 **MOYENNE** - Admin only

---

### `lib/database/app_config_dao.dart`

**Rôle** : DAO pour config app  
**Criticité** : 🟡 **BASSE**

---

## 6. Modèles de données

### `lib/models/order_model.dart`

**Rôle** : Modèle central Order + OrderItem  
**Criticité** : 🟢 **HAUTE** - Objet central métier

**Classes** :

**OrderItem** (article dans une commande)
```dart
id, productName, quantity, unitPrice, total
fromJson() | toJson()
```

**Order** (commande livreur)
```dart
// Identifiants
id, orderNumber, confirmationCode

// Client
customerName, customerPhone, customerAddress, customerNotes
customerLatitude, customerLongitude

// Localisation calculée
distanceKm (calculé depuis livreur, nullable)

// Métier
deliveryType
deliveryCost
subtotal, tax, total

// Statut
status (CONFIRMED / SHIPPED / DELIVERED)
deliveryAgentId (int? livreur assigné)

// Timing
createdAt, updatedAt

// Source
sourcePlatform (manual/api/webhook)

// Items
items (List<OrderItem>)

// Sérialisation
fromJson() | toJson() | fromSqlite() | toMap()
copyWith()  (pour immutabilité)
```

**Importance** : **HAUTE** - Objet métier central

---

### `lib/models/user_model.dart`

**Rôle** : Modèle utilisateur/livreur  
**Criticité** : 🟢 **HAUTE**

```dart
id, username, role (DELIVERY_AGENT / ADMIN / SUPER_ADMIN)
```

---

### `lib/models/external_source_model.dart`

**Rôle** : Définition sources REST externes  
**Criticité** : 🟡 **MOYENNE**

```dart
id, name, baseUrl, apiKey, webhook_secret
isActive
```

---

## 7. Widgets UI

### `lib/widgets/network_banner.dart`

**Rôle** : Banneau indiquant mode hors-ligne  
**Criticité** : 🟡 **MOYENNE** - UX clarity

**Affichage** :
- Si `isOnline==false` → Banneau orange en haut
- Message : "🡪 Hors-ligne"
- Sous-texte : "Vos actions seront synchronisées à la reconnexion"

**Importance** : Feedback utilisateur offline

---

### `lib/widgets/order_card.dart`

**Rôle** : Affiche une commande (disponible ou assignée)  
**Criticité** : 🟡 **MOYENNE**

**Affiche** :
- Numéro commande
- Client + adresse
- Distance (si calculé)
- Total + livreur
- Bouton action (Réclamer / Complétée)

---

## 8. Screens

### `lib/screens/login_screen.dart`

**Rôle** : Écran de connexion  
**Criticité** : 🟢 **HAUTE** - Première UI

**Champs** :
- Username
- Password

**Logique** :
- Appelle `AuthProvider.login(username, password)`
- Navigue vers `/dashboard` si succès
- Affiche erreur sinon

**Mode offline** : ✅ Possible (hash local)

---

### `lib/screens/dashboard_screen.dart`

**Rôle** : Tableau de bord livreur  
**Criticité** : 🔴 **CRITIQUE** - Cœur métier

**Onglets** (TabBar) :
1. **Disponibles** : Commandes à réclamer
   - Triées par distance (si localisation ON)
   - Bouton "Réclamer"

2. **Mes commandes** : Mes assignations actuelles
   - Bouton "Complétée" (+ validation code si requis)

3. **Historique** : Commandes livrées

**Fonctionnalités** :
- LocationService qui maj `OrdersProvider` → recalcul distances
- Pull-to-refresh
- NetworkBanner (hors-ligne)
- Badge compteurs par onglet

**Importance** : **CRITIQUE** - Interface métier principale

---

### `lib/screens/admin/admin_shell.dart`

**Rôle** : Interface admin (config + gestion)  
**Criticité** : 🟡 **MOYENNE** - Super-admin only

**Sections** :
- Config app (branding, couleur, logo, contact)
- Gestion livreurs
- Gestion commandes (view, cancel)
- Sources externes

---

## 📊 Synthèse de l'architecture

```
┌─────────────────────────────────────────────────────┐
│              LOGIN_SCREEN                           │
│  (username + password via AuthProvider.login)       │
└────────────────┬────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────┐
│       AUTH_PROVIDER → AUTH_SERVICE                   │
│       Valide dans table users (SQLite)              │
│       Stocke JWT/ID en FlutterSecureStorage         │
└────────────────┬────────────────────────────────────┘
                 ↓
         [Session restaurée]
                 ↓
┌─────────────────────────────────────────────────────┐
│            DASHBOARD_SCREEN                         │
│            [watch ORDERS_PROVIDER]                   │
└────────────────┬────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────┐
│       ORDERS_PROVIDER (ChangeNotifier)              │
│       ├─ availableOrders (trié par distance)       │
│       ├─ myOrders                                   │
│       └─ updateDriverLocation() [LocationService]  │
└────────────────┬────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────┐
│       ORDER_SERVICE (Singleton)                     │
│       ├─ fetchAvailableOrders()                    │
│       ├─ fetchMyOrders()                           │
│       ├─ claimOrder()                              │
│       └─ completeDelivery()                        │
└────────────────┬────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────┐
│       ORDERS_DAO (Singleton)                        │
│       ├─ getAvailableOrders()                      │
│       ├─ getMyOrders(userId)                       │
│       ├─ claimOrderLocal()                         │
│       └─ completeOrderLocal()                      │
└────────────────┬────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────────┐
│    LOCAL_DATABASE (SQLite)                          │
│    ├─ users table                                   │
│    ├─ orders table                                  │
│    ├─ driver_locations                             │
│    └─ app_config                                    │
└─────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────┐
│        POLLING_SERVICE (Timer 2 min)                │
│        ├─ GenericRestAdapter (sources REST)         │
│        ├─ Insert nouveaux orders → SQLite           │
│        └─ WebhookEventHandler + Notifications       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│    WEBHOOK_EVENT_HANDLER + NOTIFICATIONS            │
│    ├─ Parse JSON webhook                           │
│    ├─ Vérifie signature HMAC                       │
│    └─ Affiche notification + insert Order          │
└─────────────────────────────────────────────────────┘
```

---

## 📊 Flux offline-first

```
1. USER ACTION (claim/complete) → OFFLINE
   ├─ Stocké en pending_actions (SQLite)
   └─ UI feedback optionniste

2. RECONNEXION DÉTECTÉE
   └─ SyncManager.pushPending()

3. SYNC (API call)
   ├─ Succès → DELETE pending_actions
   └─ Erreur → Retry exponential (next check)

4. BACKGROUND REFRESH (via PollingService)
   ├─ 2 min timer
   ├─ Fetch sources REST
   └─ Prépare nouvelles commandes
```

---

## ✅ Points forts de l'architecture

1. **Offline-first** ✅
   - Toutes les opérations queu localement en SQLite
   - Synchronisation au reconnecte
   - Support mode avion total

2. **Singleton services** ✅
   - Pas de fuites mémoire
   - Accès centralisé + cohérent

3. **State Management simple** ✅
   - ChangeNotifier + provider package
   - Pas de boilerplate Redux/Bloc excessive

4. **Sécurité** ✅
   - Hash SHA-256 (non-réversible)
   - FlutterSecureStorage (Keychain/Keystore)
   - Webhook signature HMAC
   - Validation rôle utilisateur

5. **Multi-plateforme** ✅
   - Support Desktop (Windows/Linux/macOS) via sqflite FFI
   - Android/iOS/Web support

6. **Notifications background** ✅
   - Top-level isolate handler
   - Webhooks intégrés

7. **Géolocalisation** ✅
   - Tri automatique par distance (Haversine)
   - Localisation temps réel livreur

---

## ⚠️ Points à vérifier / compléter

1. **ApiClient manquant** ⚠️
   - Mentionné dans CLAUDE.md
   - Doit implémenter Dio + JWT interceptor
   - Requis pour API calls en ligne

2. **SyncManager vide** ⚠️
   - Dossier `/sync/` exists mais vide
   - Doit implémenter `pushPending()` pour drain pending_actions
   - Requis pour offline-sync

3. **Admin Provider faiblement documenté** ⚠️
   - `lib/providers/admin_provider.dart` existe mais non audité
   - Devrait gérer config app, livreurs, sources

4. **Tests unitaires manquants** ⚠️
   - `test/` contient seulement widget_test.dart
   - Services critiques sans tests

5. **Table pending_actions manquante** ⚠️
   - Mentionnée dans CLAUDE.md
   - Devrait être dans schema LocalDatabase._onCreate()

6. **Assignment_service faiblement utilisé** ⚠️
   - Peut être optimisé pour assignment auto

7. **Validation formulaires** ⚠️
   - Besoin formvalidation robuste login/config

---

## 📋 Résumé des fichiers essentiels

| Fichier | Role | Criticité |
|---------|------|-----------|
| `main.dart` | Entry point | 🔴 CRITIQUE |
| `auth_provider.dart` | Auth state | 🔴 CRITIQUE |
| `orders_provider.dart` | Orders state | 🔴 CRITIQUE |
| `auth_service.dart` | Auth logic | 🔴 CRITIQUE |
| `order_service.dart` | Orders logic | 🔴 CRITIQUE |
| `local_database.dart` | DB init | 🔴 CRITIQUE |
| `orders_dao.dart` | Orders CRUD | 🔴 CRITIQUE |
| `order_model.dart` | Order model | 🟢 HAUTE |
| `dashboard_screen.dart` | Main UI | 🟢 HAUTE |
| `notification_service.dart` | Notifications | 🟢 HAUTE |
| `polling_service.dart` | Background sync | 🟢 HAUTE |
| `app_config_provider.dart` | Config state | 🟡 MOYENNE |
| `location_service.dart` | Geoloc | 🟡 MOYENNE |
| `login_screen.dart` | Login UI | 🟡 MOYENNE |
| `webhook_event_handler.dart` | Webhooks | 🟡 MOYENNE |
| `app_config.dart` | Constants | 🟡 BASSE |

---

**Audit réalisé** : 14 Avril 2026  
**Version projet** : Working (offline-first, en développement)

