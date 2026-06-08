import 'package:flutter/foundation.dart';
import '../database/drivers_dao.dart';
import '../database/orders_dao.dart';
import '../models/backend_server_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/admin_user_service.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/store_api_bridge.dart';

class AdminProvider extends ChangeNotifier {
  List<UserModel> _drivers = [];
  List<Order> _orders = [];
  Map<String, dynamic>? _apiStats;
  bool _isLoading = false;
  String? _error;
  String? _driversError;

  List<UserModel> get drivers => _drivers;
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get driversError => _driversError;

  int get totalOrders {
    final v = _apiStats?['totalOrders'];
    if (v is num) return v.toInt();
    return _orders.length;
  }

  int get pendingOrders {
    if (_apiStats == null) {
      return _orders.where((o) => o.status == 'CONFIRMED').length;
    }
    if (_orders.isNotEmpty) {
      return _orders.where((o) => o.status == 'CONFIRMED').length;
    }
    final c = _apiStats!['confirmedOrders'];
    if (c is num) return c.toInt();
    return 0;
  }

  int get activeDrivers => _drivers.where((d) => d.active).length;

  Future<bool> _shouldLoadAdminFromStoreApi() async {
    final u = await AuthService.instance.tryRestoreSession();
    if (u == null || !u.isAdmin) return false;
    final backends = await StoreApiBridge.instance.getAuthenticatedBackends();
    return backends.isNotEmpty;
  }

  /// Serveurs backend actuellement authentifiés (multi-instances).
  Future<List<BackendServer>> get connectedBackends =>
      StoreApiBridge.instance.getAuthenticatedBackends();

  /// Rafraîchissement silencieux (SSE / FCM). Si [backendId] est fourni, ne met à jour que ce serveur.
  Future<void> syncFromDatabase({
    bool orders = true,
    bool drivers = false,
    int? backendId,
  }) async {
    if (!await _shouldLoadAdminFromStoreApi()) return;

    if (backendId != null) {
      try {
        if (orders) {
          final fresh = await OrderService.instance.fetchAdminOrdersForBackend(backendId);
          _orders = [
            ..._orders.where((o) => o.backendId != backendId),
            ...fresh,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          try {
            _apiStats = await OrderService.instance.fetchAdminDashboardStats();
          } catch (_) {}
          _error = null;
        }
        if (drivers) {
          final fresh = await AdminUserService.instance.fetchAdminDriversForBackend(backendId);
          _drivers = [
            ..._drivers.where((d) => d.backendId != backendId),
            ...fresh,
          ]..sort((a, b) => a.username.compareTo(b.username));
          _driversError = null;
        }
        notifyListeners();
      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        if (orders) _error = msg;
        if (drivers) _driversError = msg;
        notifyListeners();
      }
      return;
    }

    final tasks = <Future<void>>[];
    if (orders) tasks.add(loadOrders());
    if (drivers) tasks.add(loadDrivers());
    if (tasks.isEmpty) return;
    await Future.wait(tasks);
  }

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    _driversError = null;
    notifyListeners();
    try {
      await Future.wait([loadDrivers(), loadOrders()]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDrivers() async {
    if (await _shouldLoadAdminFromStoreApi()) {
      try {
        _drivers = await AdminUserService.instance.fetchAdminDrivers();
        _driversError = null;
        notifyListeners();
        return;
      } catch (e) {
        _drivers = [];
        _driversError = e.toString().replaceFirst('Exception: ', '');
        if (kDebugMode) {
          debugPrint('[Admin] erreur API livreurs: $_driversError');
        }
        notifyListeners();
        return;
      }
    }

    _driversError = null;
    _drivers = await DriversDao.instance.getAllDrivers();
    notifyListeners();
  }

  Future<String> createDriver({
    int backendId = 0,
    required String username,
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
    if (await _shouldLoadAdminFromStoreApi()) {
      var targetBackendId = backendId;
      if (targetBackendId <= 0) {
        final backends = await connectedBackends;
        if (backends.length == 1 && backends.first.id != null) {
          targetBackendId = backends.first.id!;
        } else {
          throw Exception('Sélectionnez le serveur cible pour ce livreur.');
        }
      }
      final loginId = await AdminUserService.instance.createDriver(
        backendId: targetBackendId,
        username: username,
        lastName: lastName,
        firstName: firstName,
        phone: phone,
        password: password,
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
      return loginId;
    }

    final loginId = await DriversDao.instance.createDriver(
      username: username,
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
    return loginId;
  }

  Future<void> deleteDriver(UserModel driver) async {
    if (await _shouldLoadAdminFromStoreApi()) {
      await AdminUserService.instance.deleteDriver(driver);
    } else {
      await DriversDao.instance.deleteDriver(driver.id);
    }
    await loadDrivers();
  }

  Future<void> toggleDriver(UserModel driver, bool active) async {
    if (await _shouldLoadAdminFromStoreApi()) {
      await AdminUserService.instance.toggleDriver(driver, active);
    } else {
      await DriversDao.instance.toggleActive(driver.id, active);
    }
    await loadDrivers();
  }

  Future<void> loadOrders() async {
    if (await _shouldLoadAdminFromStoreApi()) {
      try {
        _orders = await OrderService.instance.fetchAdminOrders();
        try {
          _apiStats = await OrderService.instance.fetchAdminDashboardStats();
        } catch (e) {
          _apiStats = null;
          if (kDebugMode) {
            debugPrint('[Admin] stats API ignorées: $e');
          }
        }
        _error = null;
        if (kDebugMode) {
          debugPrint(
            '[Admin] Spring: ${_orders.length} commandes, totalOrders API=${_apiStats?['totalOrders']}',
          );
        }
        notifyListeners();
        return;
      } catch (e) {
        _orders = [];
        _apiStats = null;
        _error = e.toString().replaceFirst('Exception: ', '');
        if (kDebugMode) {
          debugPrint('[Admin] erreur API commandes: $_error');
        }
        notifyListeners();
        return;
      }
    }

    _apiStats = null;
    _error = null;
    _orders = await OrdersDao.instance.getAllOrders();
    notifyListeners();
  }
}
