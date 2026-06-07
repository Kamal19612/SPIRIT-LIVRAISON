import 'package:flutter/foundation.dart';
import '../database/drivers_dao.dart';
import '../database/orders_dao.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/store_api_bridge.dart';

class AdminProvider extends ChangeNotifier {
  List<UserModel> _drivers = [];
  List<Order> _orders = [];
  Map<String, dynamic>? _apiStats;
  bool _isLoading = false;
  String? _error;

  List<UserModel> get drivers => _drivers;
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

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

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
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
    _drivers = await DriversDao.instance.getAllDrivers();
    notifyListeners();
  }

  Future<String> createDriver({
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

  Future<void> deleteDriver(int id) async {
    await DriversDao.instance.deleteDriver(id);
    await loadDrivers();
  }

  Future<void> toggleDriver(int id, bool active) async {
    await DriversDao.instance.toggleActive(id, active);
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
        if (kDebugMode) {
          debugPrint(
            '[Admin] Spring: ${_orders.length} commandes, totalOrders API=${_apiStats?['totalOrders']}',
          );
        }
        notifyListeners();
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Admin] repli SQLite (erreur API): $e');
        }
        _apiStats = null;
      }
    } else {
      _apiStats = null;
    }
    _orders = await OrdersDao.instance.getAllOrders();
    notifyListeners();
  }
}
