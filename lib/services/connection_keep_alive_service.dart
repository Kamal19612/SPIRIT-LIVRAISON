import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'auth_service.dart';
import 'notification_service.dart';
import 'store_api_bridge.dart';
import 'store_sse_service.dart';

/// Maintient la liaison serveur (SSE + FCM) pendant la veille si Internet est disponible.
class ConnectionKeepAliveService {
  ConnectionKeepAliveService._();
  static final ConnectionKeepAliveService instance = ConnectionKeepAliveService._();

  static const _heartbeatInterval = Duration(seconds: 45);

  Timer? _heartbeatTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _running = false;
  Future<void> Function()? _onHeartbeat;

  bool get isRunning => _running;

  void setHeartbeatCallback(Future<void> Function()? callback) {
    _onHeartbeat = callback;
  }

  Future<bool> _shouldRun() async {
    if (await AuthService.instance.isLocalOnlySession()) return false;
    final backends = await StoreApiBridge.instance.getAuthenticatedBackends();
    return backends.isNotEmpty;
  }

  /// Démarre ou arrête selon la session courante (appel après login / init / logout).
  Future<void> syncWithSession() async {
    if (await _shouldRun()) {
      await start();
    } else {
      await stop();
    }
  }

  Future<void> start() async {
    if (_running) return;
    if (!await _shouldRun()) return;

    _running = true;

    try {
      await WakelockPlus.enable();
    } catch (e) {
      if (kDebugMode) debugPrint('[KeepAlive] wakelock: $e');
    }

    await NotificationService.instance.showConnectionActiveNotification();

    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!online) return;
      unawaited(_reconnectStreams());
    });

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      unawaited(_pulse());
    });

    await _reconnectStreams();
  }

  Future<void> stop() async {
    _running = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _onHeartbeat = null;

    try {
      if (await WakelockPlus.enabled) {
        await WakelockPlus.disable();
      }
    } catch (_) {}

    await NotificationService.instance.hideConnectionActiveNotification();
  }

  void onAppLifecycleChange(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_pulse());
    }
  }

  Future<void> _pulse() async {
    if (!_running) return;
    final results = await Connectivity().checkConnectivity();
    final online = results.any((r) => r != ConnectivityResult.none);
    if (!online) return;

    await _reconnectStreams();

    final heartbeat = _onHeartbeat;
    if (heartbeat != null) {
      try {
        await heartbeat();
      } catch (e) {
        if (kDebugMode) debugPrint('[KeepAlive] heartbeat: $e');
      }
    }
  }

  Future<void> _reconnectStreams() async {
    await StoreSseService.instance.reconnectIfActive(StoreSseStream.admin);
    await StoreSseService.instance.reconnectIfActive(StoreSseStream.delivery);
  }
}
