import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../database/orders_dao.dart';
import '../models/external_source_model.dart';
import '../services/adapters/generic_rest_adapter.dart';
import '../services/assignment_service.dart';
import '../services/notification_service.dart';
import '../services/external_source_secrets.dart';

enum SourceSyncStatus { idle, syncing, ok, error }

class SourceState {
  final SourceSyncStatus status;
  final String? errorMessage;
  final int newOrdersCount;

  const SourceState({
    this.status = SourceSyncStatus.idle,
    this.errorMessage,
    this.newOrdersCount = 0,
  });
}

class PollingService extends ChangeNotifier {
  Timer? _timer;
  final Map<int, SourceState> _states = {};
  final _adapter = GenericRestAdapter();
  bool _running = false;

  Map<int, SourceState> get states => Map.unmodifiable(_states);

  SourceState stateFor(int sourceId) =>
      _states[sourceId] ?? const SourceState();

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _pollAll());
    // Trigger an initial poll soon after start
    Timer(const Duration(seconds: 5), _pollAll);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  // ── Poll all active REST sources ────────────────────────────────────────────

  Future<void> _pollAll() async {
    final rows = await LocalDatabase.instance.db.query(
      'external_sources',
      where: "isActive = 1 AND platformType = 'rest_polling'",
    );
    final sources = rows.map(ExternalSource.fromSqlite).toList();
    for (final source in sources) {
      await _pollSingleSource(source);
    }
  }

  // ── Manual sync trigger (called from UI) ────────────────────────────────────

  Future<void> pollSource(ExternalSource source) async {
    await _pollSingleSource(source);
  }

  // ── Core sync logic ─────────────────────────────────────────────────────────

  Future<void> _pollSingleSource(ExternalSource source) async {
    if (source.id == null) return;
    final id = source.id!;

    _states[id] = const SourceState(status: SourceSyncStatus.syncing);
    notifyListeners();

    int newCount = 0;
    String? errorMsg;

    try {
      final since = () {
        final v = source.lastSyncAt.trim();
        if (v.isEmpty) return null;
        return DateTime.tryParse(v);
      }();

      // Use secure storage for API key (and migrate legacy config.api_key if needed).
      final apiKey = await ExternalSourceSecrets.instance.migrateApiKeyIfNeeded(source);
      if ((source.config['api_key'] as String?)?.trim().isNotEmpty == true) {
        // Best-effort cleanup: remove plaintext key from SQLite.
        await _updateSourceConfig(source, {'api_key': ''});
      }

      final rawOrders = await _adapter.fetchRawOrders(
        source,
        apiKeyOverride: apiKey,
        since: since,
      );
      final mapping   = source.fieldMapping;

      for (final raw in rawOrders) {
        final order = _adapter.normalizeOrder(raw, mapping, source.name, source.idFieldPath);

        // Deduplication check
        final existing = await OrdersDao.instance.getOrderByNumber(order.orderNumber);
        if (existing != null) continue;

        await OrdersDao.instance.insertOrder(order);
        newCount++;

        // Assign to nearest drivers if coordinates available
        if (order.customerLatitude != null && order.customerLongitude != null) {
          final closest = await AssignmentService.instance.findClosestDrivers(
            order.customerLatitude!,
            order.customerLongitude!,
          );
          if (closest.isNotEmpty) {
            await AssignmentService.instance.createAssignments(order.id, closest);
          }
        }

        await NotificationService.instance.showNewOrderNotification(order.orderNumber);
      }

      // Update sync metadata in configJson
      await _updateSourceConfig(source, {
        'last_sync_at': DateTime.now().toIso8601String(),
        'last_error': '',
        'synced_count': source.syncedCount + newCount,
      });

      _states[id] = SourceState(
        status: SourceSyncStatus.ok,
        newOrdersCount: newCount,
      );
    } catch (e) {
      errorMsg = e.toString();
      await _updateSourceConfig(source, {
        'last_sync_at': DateTime.now().toIso8601String(),
        'last_error': errorMsg,
      });

      _states[id] = SourceState(
        status: SourceSyncStatus.error,
        errorMessage: errorMsg,
      );
    }

    notifyListeners();
  }

  // ── Persist config metadata ─────────────────────────────────────────────────

  Future<void> _updateSourceConfig(
    ExternalSource source,
    Map<String, dynamic> updates,
  ) async {
    final newConfig = {...source.config, ...updates};
    await LocalDatabase.instance.db.update(
      'external_sources',
      {'configJson': jsonEncode(newConfig)},
      where: 'id = ?',
      whereArgs: [source.id],
    );
  }
}
