import 'package:sqflite/sqflite.dart';
import '../models/order_model.dart';
import 'local_database.dart';

class OrdersDao {
  OrdersDao._();
  static final OrdersDao instance = OrdersDao._();

  Database get _db => LocalDatabase.instance.db;

  // ── Lecture ────────────────────────────────────────────────────────────────

  Future<List<Order>> getAvailableOrders() async {
    final rows = await _db.rawQuery(
      "SELECT * FROM orders WHERE status = 'CONFIRMED' AND deliveryAgentId IS NULL ORDER BY createdAt DESC",
    );
    return rows.map(Order.fromSqlite).toList();
  }

  Future<List<Order>> getAllOrders() async {
    final rows = await _db.query('orders', orderBy: 'createdAt DESC');
    return rows.map(Order.fromSqlite).toList();
  }

  Future<List<Order>> getMyOrders(int userId) async {
    final rows = await _db.rawQuery(
      "SELECT * FROM orders WHERE status IN ('SHIPPED','CLAIMED') AND deliveryAgentId = ? ORDER BY createdAt DESC",
      [userId],
    );
    return rows.map(Order.fromSqlite).toList();
  }

  Future<Order?> getOrderById(int orderId) async {
    final rows = await _db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (rows.isEmpty) return null;
    return Order.fromSqlite(rows.first);
  }

  Future<Order?> getOrderByNumber(String orderNumber) async {
    final rows = await _db.query(
      'orders',
      where: 'orderNumber = ?',
      whereArgs: [orderNumber],
    );
    if (rows.isEmpty) return null;
    return Order.fromSqlite(rows.first);
  }

  Future<Map<String, int>> getOrderCounts() async {
    final rows = await _db
        .rawQuery('SELECT status, COUNT(*) as cnt FROM orders GROUP BY status');
    return Map.fromEntries(
      rows.map((r) => MapEntry(r['status'] as String, (r['cnt'] as int))),
    );
  }

  // ── Écriture ───────────────────────────────────────────────────────────────

  Future<int> insertOrder(Order order) async {
    return _db.insert(
      'orders',
      _toRow(order),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveOrders(List<Order> orders) async {
    await _db.transaction((txn) async {
      for (final order in orders) {
        await txn.insert('orders', _toRow(order),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> claimOrderLocal(int orderId, int? userId) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawUpdate(
      "UPDATE orders SET status = 'SHIPPED', deliveryAgentId = ? WHERE id = ?",
      [userId, orderId],
    );
    await _db.rawUpdate(
      "UPDATE order_assignments SET status = 'ACCEPTED', acceptedAt = ? WHERE orderId = ? AND driverId = ?",
      [now, orderId, userId],
    );
    await _db.rawUpdate(
      "UPDATE order_assignments SET status = 'MISSED' WHERE orderId = ? AND driverId != ? AND status = 'NOTIFIED'",
      [orderId, userId],
    );
  }

  Future<void> completeOrderLocal(int orderId) async {
    await _db.rawUpdate(
      "UPDATE orders SET status = 'DELIVERED', updatedAt = ? WHERE id = ?",
      [DateTime.now().toIso8601String(), orderId],
    );
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await _db.rawUpdate(
      'UPDATE orders SET status = ?, updatedAt = ? WHERE id = ?',
      [status, DateTime.now().toIso8601String(), orderId],
    );
  }

  Map<String, dynamic> _toRow(Order order) => {
        'id': order.id,
        'orderNumber': order.orderNumber,
        'confirmationCode': order.confirmationCode,
        'customerName': order.customerName,
        'customerAddress': order.customerAddress,
        'customerPhone': order.customerPhone,
        'customerNotes': order.customerNotes,
        'customerLatitude': order.customerLatitude,
        'customerLongitude': order.customerLongitude,
        'total': order.total,
        'status': order.status,
        'sourcePlatform': order.sourcePlatform,
        'syncStatus': order.syncStatus,
        'createdAt': order.createdAt,
        'updatedAt': order.updatedAt,
        'deliveryAgentId': order.deliveryAgent?['id'],
      };
}
