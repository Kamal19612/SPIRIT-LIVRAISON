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

**Sucre Store Livreur** — an offline-first Flutter delivery-driver app. Drivers can log in, claim orders, and complete deliveries; all actions queue locally when offline and sync when reconnected.

### Layer Diagram

```
Screens & Widgets  (lib/screens/, lib/widgets/)
        ↓
Providers          (lib/providers/)        ← ChangeNotifier, consumed via context.watch
        ↓
Services           (lib/services/)         ← stateless business logic
        ↓
DAO / SQLite       (lib/database/)         ← local cache + pending-action queue
        ↓
Remote API (Dio)   via ApiClient           ← Spring Boot at http://172.18.0.3:8081
```

### Key Files

| File | Role |
|------|------|
| `lib/main.dart` | Entry point — initializes DB, API client, restores auth session, sets up MultiProvider |
| `lib/config/app_config.dart` | Hardcoded API base URL, PostgreSQL creds (dev only) |
| `lib/providers/auth_provider.dart` | Login/logout state; drives route decisions |
| `lib/providers/orders_provider.dart` | Orders list, connectivity flag, background sync trigger |
| `lib/services/api_client.dart` | Dio instance with JWT interceptor; auto-logout on 401 |
| `lib/services/auth_service.dart` | Online login + offline SHA-256 hash fallback |
| `lib/services/order_service.dart` | Fetch, claim, complete — with offline pending-action fallback |
| `lib/database/local_database.dart` | SQLite schema: `orders`, `pending_actions`, `sync_meta` |
| `lib/database/orders_dao.dart` | All CRUD against SQLite |
| `lib/sync/sync_manager.dart` | Drains `pending_actions` table when back online |

### Offline Strategy

1. On startup, UI shows SQLite-cached orders immediately.
2. Background fetch from API updates the cache.
3. Any claim/complete action while offline is inserted into `pending_actions`.
4. `SyncManager.pushPending()` is called on reconnect (via `connectivity_plus` listener in `OrdersProvider`).
5. `NetworkBanner` widget reflects `_isOnline` from `OrdersProvider`.

### State Management

Uses the `provider` package (`ChangeNotifier`). `AuthProvider` and `OrdersProvider` are registered at the root in `main.dart` via `MultiProvider`. Screens use `context.watch` / `context.read`.

### Authentication

- JWT stored in `FlutterSecureStorage`.
- Session restored on app start (`AuthProvider.init()`).
- `ApiClient` injects the token into every request via a Dio interceptor.
- Offline login compares SHA-256 of the entered password against the stored hash.
