import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

class OrdersProvider extends ChangeNotifier {
  List<Order> _availableOrders = [];
  List<Order> _myOrders        = [];
  bool        _isLoading       = false;
  bool        _isRefreshing    = false;
  bool        _refreshInFlight = false;
  String?     _error;
  double?     _driverLat;
  double?     _driverLng;

  List<Order> get availableOrders => _availableOrders;
  List<Order> get myOrders        => _myOrders;
  bool        get isLoading       => _isLoading;
  bool        get isRefreshing    => _isRefreshing;
  String?     get error           => _error;

  // ── Localisation livreur ───────────────────────────────────────────────────

  void updateDriverLocation(double? lat, double? lng) {
    _driverLat = lat;
    _driverLng = lng;
    if (lat != null && lng != null) {
      _availableOrders = _sortByDistance(_availableOrders);
      notifyListeners();
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  List<Order> _sortByDistance(List<Order> orders) {
    if (_driverLat == null || _driverLng == null) return orders;
    final list = orders.map((o) {
      if (o.customerLatitude != null && o.customerLongitude != null) {
        return o.copyWith(
          distanceKm: _haversine(
              _driverLat!, _driverLng!, o.customerLatitude!, o.customerLongitude!),
        );
      }
      return o;
    }).toList();
    list.sort((a, b) {
      if (a.distanceKm == null && b.distanceKm == null) return 0;
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });
    return list;
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();
    try {
      _availableOrders = _sortByDistance(await OrderService.instance.fetchAvailableOrders());
      _myOrders        = await OrderService.instance.fetchMyOrders();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Chargement par onglet ──────────────────────────────────────────────────

  Future<void> loadOrders(String tab) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();
    try {
      if (tab == 'available') {
        _availableOrders = _sortByDistance(await OrderService.instance.fetchAvailableOrders());
      } else {
        _myOrders = await OrderService.instance.fetchMyOrders();
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Actualisation ──────────────────────────────────────────────────────────

  /// [silent] : polling / SSE — pas de spinner plein écran (aligné PWA).
  Future<void> refresh({bool silent = false}) async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    if (!silent) {
      _isRefreshing = true;
      _error = null;
      notifyListeners();
    }
    try {
      _availableOrders =
          _sortByDistance(await OrderService.instance.fetchAvailableOrders());
      _myOrders = await OrderService.instance.fetchMyOrders();
      if (silent) _error = null;
    } catch (e) {
      if (!silent) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      _refreshInFlight = false;
      if (!silent) _isRefreshing = false;
      notifyListeners();
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Retourne la commande prise en charge (affichage immédiat, comme la PWA).
  Future<Order> claimOrder(int id) async {
    try {
      final claimed = await OrderService.instance.claimOrder(id);
      _availableOrders.removeWhere((o) => o.id == id);
      _myOrders = [
        claimed,
        ..._myOrders.where((o) => o.id != claimed.id),
      ];
      notifyListeners();
      try {
        _myOrders = await OrderService.instance.fetchMyOrders();
        notifyListeners();
      } catch (_) {}
      return claimed;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> completeDelivery(int id, String code) async {
    try {
      await OrderService.instance.completeDelivery(id, code);
      _myOrders.removeWhere((o) => o.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }
}
