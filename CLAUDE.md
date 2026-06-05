# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Lint / static analysis
flutter test             # Run test suite
flutter test test/widget_test.dart  # Run a single test file
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android APK
flutter build web        # Build web version
```

## Architecture

**Store Livreur** — Flutter app with two modules:

- **Livreur (`/dashboard`)** — aligné sur la PWA STORE-ALL : JWT Spring multi-backend, `/api/delivery/*`, `order.store`, polling 5s, SSE `/api/notifications/stream/delivery`, FCM, bascule « Mes courses » après claim.
- **Admin (`/admin`)** — autonome (SQLite, livreurs locaux) ; commandes admin agrégées depuis les backends connectés.
- **Compte admin local (bootstrap SQLite)** : `admin` / `Pass_word.(1)@!` — créé ou réinitialisé au démarrage (`LocalDatabase.ensureDefaultLocalAdmin`). Connexion locale si aucun backend configuré, ou repli si API injoignable.
- **Backends** : liste SQLite `backends` (Admin → Paramètres → Intégrations). Une entrée par serveur STORE-ALL. Login JWT sur chaque serveur actif ; commandes fusionnées dans le dashboard livreur.

### Layer Diagram

```
Screens & Widgets  (lib/screens/, lib/widgets/)
        ↓
Providers          (lib/providers/)        ← ChangeNotifier, consumed via context.watch
        ↓
Services           (lib/services/)         ← stateless business logic
        ↓
DAO / SQLite       (lib/database/)         ← backends, users, local cache
        ↓
Remote API (Dio)   via StoreApiBridge      ← Spring Boot, JWT par backend
```

### Key Files

| File | Role |
|------|------|
| `lib/main.dart` | Entry point — initializes DB, restores auth session, sets up MultiProvider |
| `lib/database/backends_dao.dart` | CRUD serveurs backend (URL, nom, code boutique) |
| `lib/services/store_api_bridge.dart` | JWT par backend, claim/complete, FCM |
| `lib/services/auth_service.dart` | Login multi-backend + repli SQLite local |
| `lib/services/order_service.dart` | Agrégation commandes depuis tous les backends connectés |
| `lib/screens/admin/admin_integrations_tab.dart` | UI configuration serveurs |
| `lib/providers/orders_provider.dart` | Liste commandes, claim/complete (clé `backendId:id`) |
| `lib/services/delivery_sse_service.dart` | SSE par backend connecté |

### Multi-backend

1. Admin ajoute N serveurs (`name`, `origin`, `storeCode` optionnel).
2. Livreur login → `POST /api/auth/login` sur chaque serveur actif (mêmes identifiants).
3. JWT stockés : `backend_jwt_{id}` ; liste : `auth_backend_ids`.
4. `Order.backendId` + `Order.backendName` taguent chaque commande.
5. Claim/complete routés vers le bon serveur.

### Authentication

- JWT stocké par backend dans `FlutterSecureStorage`.
- Session restaurée si profil utilisateur + au moins un JWT backend valide.
- Offline login compare SHA-256 du mot de passe contre hash SQLite (admin/livreurs locaux).

### State Management

Uses the `provider` package (`ChangeNotifier`). `AuthProvider` and `OrdersProvider` are registered at the root in `main.dart` via `MultiProvider`. Screens use `context.watch` / `context.read`.
