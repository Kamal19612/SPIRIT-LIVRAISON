/// Métadonnées de session JWT par backend (complément du token).
class BackendSessionInfo {
  final int? storeId;
  final bool isSuperAdmin;

  const BackendSessionInfo({
    this.storeId,
    this.isSuperAdmin = false,
  });

  bool get canFetchAdminOrders => isSuperAdmin || (storeId != null && storeId! > 0);

  factory BackendSessionInfo.fromJson(Map<String, dynamic> json) => BackendSessionInfo(
        storeId: (json['storeId'] as num?)?.toInt(),
        isSuperAdmin: json['isSuperAdmin'] == true,
      );

  Map<String, dynamic> toJson() => {
        if (storeId != null) 'storeId': storeId,
        'isSuperAdmin': isSuperAdmin,
      };
}
