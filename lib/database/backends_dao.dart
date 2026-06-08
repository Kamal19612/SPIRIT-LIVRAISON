import 'package:sqflite/sqflite.dart';

import '../models/backend_server_model.dart';
import '../utils/url_normalize.dart';
import 'local_database.dart';

class BackendsDao {
  BackendsDao._();
  static final BackendsDao instance = BackendsDao._();

  Database get _db => LocalDatabase.instance.db;

  Future<List<BackendServer>> getAll({bool activeOnly = false}) async {
    final rows = await _db.query(
      'backends',
      where: activeOnly ? 'isActive = 1' : null,
      orderBy: 'id ASC',
    );
    return rows.map(BackendServer.fromSqlite).toList();
  }

  Future<List<BackendServer>> getByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.query(
      'backends',
      where: 'id IN ($placeholders) AND isActive = 1',
      whereArgs: ids,
      orderBy: 'id ASC',
    );
    return rows.map(BackendServer.fromSqlite).toList();
  }

  Future<BackendServer?> getById(int id) async {
    final rows = await _db.query('backends', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return BackendServer.fromSqlite(rows.first);
  }

  Future<int> insert({
    required String name,
    required String origin,
    String storeCode = '',
    int? managerStoreId,
    bool isActive = true,
  }) async {
    final normalized = normalizeBackendOrigin(origin);
    if (normalized == null) {
      throw ArgumentError('URL backend invalide');
    }
    return _db.insert(
      'backends',
      BackendServer(
        name: name.trim(),
        origin: normalized,
        storeCode: storeCode.trim().toLowerCase(),
        managerStoreId: managerStoreId,
        isActive: isActive,
      ).toInsertMap(),
    );
  }

  Future<void> update({
    required int id,
    required String name,
    required String origin,
    String storeCode = '',
    int? managerStoreId,
    bool? isActive,
  }) async {
    final normalized = normalizeBackendOrigin(origin);
    if (normalized == null) {
      throw ArgumentError('URL backend invalide');
    }
    final data = <String, Object?>{
      'name': name.trim(),
      'origin': normalized,
      'storeCode': storeCode.trim().toLowerCase(),
      'managerStoreId': managerStoreId,
    };
    if (isActive != null) data['isActive'] = isActive ? 1 : 0;
    await _db.update('backends', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setActive(int id, bool active) async {
    await _db.update(
      'backends',
      {'isActive': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete('backends', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> hasAnyActive() async {
    final rows = await _db.query('backends', where: 'isActive = 1', limit: 1);
    return rows.isNotEmpty;
  }
}
