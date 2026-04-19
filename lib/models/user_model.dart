class UserModel {
  final int id;
  final String username;
  final String role;
  final bool active;
  final double? lat;
  final double? lng;
  final String? fcmToken;

  const UserModel({
    required this.id,
    required this.username,
    required this.role,
    this.active = true,
    this.lat,
    this.lng,
    this.fcmToken,
  });

  bool get isDeliveryAgent => role == 'DELIVERY_AGENT';
  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';
  bool get hasDeliveryAccess => isDeliveryAgent || isAdmin;

  factory UserModel.fromSqlite(Map<String, dynamic> row) => UserModel(
        id: row['id'] as int,
        username: row['username'] as String,
        role: row['role'] as String,
        active: (row['active'] as int? ?? 1) == 1,
        lat: row['lat'] != null ? (row['lat'] as num).toDouble() : null,
        lng: row['lng'] != null ? (row['lng'] as num).toDouble() : null,
        fcmToken: row['fcm_token'] as String?,
      );
}
