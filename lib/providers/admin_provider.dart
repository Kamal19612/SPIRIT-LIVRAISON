import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/drivers_dao.dart';
import '../database/local_database.dart';
import '../database/orders_dao.dart';
import '../models/external_source_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/polling_service.dart';

class AdminProvider extends ChangeNotifier {
  List<UserModel>      _drivers = [];
  List<Order>          _orders  = [];
  List<ExternalSource> _sources = [];
  bool    _isLoading = false;
  String? _error;

  List<UserModel>      get drivers => _drivers;
  List<Order>          get orders  => _orders;
  List<ExternalSource> get sources => _sources;
  bool    get isLoading => _isLoading;
  String? get error     => _error;

  int get totalOrders    => _orders.length;
  int get pendingOrders  => _orders.where((o) => o.status == 'CONFIRMED').length;
  int get activeDrivers  => _drivers.where((d) => d.active).length;

  // ── Chargement global ──────────────────────────────────────────────────────

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await Future.wait([loadDrivers(), loadOrders(), loadSources()]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Livreurs ───────────────────────────────────────────────────────────────

  Future<void> loadDrivers() async {
    _drivers = await DriversDao.instance.getAllDrivers();
    notifyListeners();
  }

  /// Retourne le nom d’utilisateur généré (connexion livreur).
  Future<String> createDriver({
    required String lastName,
    required String firstName,
    required String phone,
    required String password,
    String? cnibImagePath,
    String? cnibOcrText,
    String? cnibNationalId,
    String? cnibSerial,
    String? birthDate,
    String? birthPlace,
    String? gender,
    String? profession,
    String? cnibIssueDate,
    String? cnibExpiryDate,
  }) async {
    final username = await DriversDao.instance.createDriver(
      lastName: lastName,
      firstName: firstName,
      phone: phone,
      password: password,
      cnibImagePath: cnibImagePath,
      cnibOcrText: cnibOcrText,
      cnibNationalId: cnibNationalId,
      cnibSerial: cnibSerial,
      birthDate: birthDate,
      birthPlace: birthPlace,
      gender: gender,
      profession: profession,
      cnibIssueDate: cnibIssueDate,
      cnibExpiryDate: cnibExpiryDate,
    );
    await loadDrivers();
    return username;
  }

  Future<void> deleteDriver(int id) async {
    await DriversDao.instance.deleteDriver(id);
    await loadDrivers();
  }

  Future<void> toggleDriver(int id, bool active) async {
    await DriversDao.instance.toggleActive(id, active);
    await loadDrivers();
  }

  // ── Commandes ──────────────────────────────────────────────────────────────

  Future<void> loadOrders() async {
    _orders = await OrdersDao.instance.getAllOrders();
    notifyListeners();
  }

  // ── Sources externes (intégrations) ───────────────────────────────────────

  Future<void> loadSources() async {
    final rows = await LocalDatabase.instance.db.query(
      'external_sources',
      orderBy: 'createdAt DESC',
    );
    _sources = rows.map(ExternalSource.fromSqlite).toList();
    notifyListeners();
  }

  Future<void> addExternalSource({
    required String name,
    required String platformType,
    required Map<String, dynamic> config,
    bool isActive = true,
  }) async {
    await LocalDatabase.instance.db.insert('external_sources', {
      'name': name,
      'platformType': platformType,
      'configJson': jsonEncode(config),
      'isActive': isActive ? 1 : 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await loadSources();
  }

  Future<void> toggleSource(int id, bool active) async {
    await LocalDatabase.instance.db.update(
      'external_sources',
      {'isActive': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadSources();
  }

  Future<void> deleteSource(int id) async {
    await LocalDatabase.instance.db.delete(
      'external_sources',
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadSources();
  }

  Future<void> updateSourceConfig(int id, Map<String, dynamic> configUpdates) async {
    final source = _sources.firstWhere((s) => s.id == id);
    final newConfig = {...source.config, ...configUpdates};
    await LocalDatabase.instance.db.update(
      'external_sources',
      {'configJson': jsonEncode(newConfig)},
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadSources();
  }

  Future<void> pollSource(ExternalSource source, PollingService polling) async {
    await polling.pollSource(source);
    await loadSources(); // refresh to show updated last_sync_at / synced_count
    await loadOrders();
  }
}
