import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../database/drivers_dao.dart';

class LocationService extends ChangeNotifier {
  double? _lat;
  double? _lng;
  Timer? _timer;
  int? _currentDriverId;
  bool _isTracking = false;

  double? get lat => _lat;
  double? get lng => _lng;
  bool get isTracking => _isTracking;

  Future<void> startTracking(int driverId) async {
    if (_isTracking) return;
    _currentDriverId = driverId;

    // Sur desktop (test), on simule une position fixe
    if (!Platform.isAndroid && !Platform.isIOS) {
      _lat = 9.5370;
      _lng = -13.6773;
      _isTracking = true;
      await DriversDao.instance.updateLocation(driverId, _lat!, _lng!);
      notifyListeners();
      return;
    }

    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    _isTracking = true;
    await _fetchAndSave();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchAndSave());
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _isTracking = false;
    notifyListeners();
  }

  Future<bool> _ensurePermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchAndSave() async {
    if (_currentDriverId == null) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _lat = position.latitude;
      _lng = position.longitude;
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _lat = last.latitude;
          _lng = last.longitude;
        }
      } catch (_) {}
    }

    if (_lat != null && _lng != null) {
      try {
        await DriversDao.instance.updateLocation(_currentDriverId!, _lat!, _lng!);
        notifyListeners();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
