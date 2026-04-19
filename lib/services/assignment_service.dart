import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../database/drivers_dao.dart';
import '../database/local_database.dart';
import '../models/user_model.dart';

class AssignmentService {
  AssignmentService._();
  static final AssignmentService instance = AssignmentService._();

  static const int _maxDrivers = 5;

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Retourne les N livreurs les plus proches (parmi ceux ayant une position connue)
  Future<List<UserModel>> findClosestDrivers(double lat, double lng) async {
    final drivers = await DriversDao.instance.getActiveDriversWithLocation();
    if (drivers.isEmpty) return [];

    final withDist = drivers
        .where((d) => d.lat != null && d.lng != null)
        .map((d) => (driver: d, dist: _haversine(lat, lng, d.lat!, d.lng!)))
        .toList()
      ..sort((a, b) => a.dist.compareTo(b.dist));

    return withDist.take(_maxDrivers).map((e) => e.driver).toList();
  }

  /// Crée les enregistrements d'attribution dans order_assignments
  Future<void> createAssignments(int orderId, List<UserModel> drivers) async {
    final db = LocalDatabase.instance.db;
    final now = DateTime.now().toIso8601String();
    for (final driver in drivers) {
      await db.insert(
        'order_assignments',
        {
          'orderId': orderId,
          'driverId': driver.id,
          'notifiedAt': now,
          'status': 'NOTIFIED',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
