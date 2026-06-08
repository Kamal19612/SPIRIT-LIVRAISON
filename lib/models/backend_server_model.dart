/// Backend Spring (multi-serveur : STORE-ALL, autres instances compatibles).
class BackendServer {
  final int? id;
  final String name;
  final String origin;
  final String storeCode;
  /// ID boutique pour `/api/manager/{id}/...` si connu (optionnel, par serveur).
  final int? managerStoreId;
  final bool isActive;
  final String createdAt;

  const BackendServer({
    this.id,
    required this.name,
    required this.origin,
    this.storeCode = '',
    this.managerStoreId,
    this.isActive = true,
    this.createdAt = '',
  });

  factory BackendServer.fromSqlite(Map<String, dynamic> row) {
    final rawManagerId = row['managerStoreId'];
    int? managerStoreId;
    if (rawManagerId is int) {
      managerStoreId = rawManagerId;
    } else if (rawManagerId is num) {
      managerStoreId = rawManagerId.toInt();
    }
    return BackendServer(
      id: row['id'] as int?,
      name: row['name']?.toString() ?? '',
      origin: row['origin']?.toString() ?? '',
      storeCode: row['storeCode']?.toString() ?? '',
      managerStoreId: managerStoreId,
      isActive: (row['isActive'] as int? ?? 1) == 1,
      createdAt: row['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'origin': origin,
        'storeCode': storeCode,
        if (managerStoreId != null) 'managerStoreId': managerStoreId,
        'isActive': isActive ? 1 : 0,
        'createdAt': createdAt.isNotEmpty
            ? createdAt
            : DateTime.now().toIso8601String(),
      };

  BackendServer copyWith({
    int? id,
    String? name,
    String? origin,
    String? storeCode,
    int? managerStoreId,
    bool? isActive,
    String? createdAt,
  }) {
    return BackendServer(
      id: id ?? this.id,
      name: name ?? this.name,
      origin: origin ?? this.origin,
      storeCode: storeCode ?? this.storeCode,
      managerStoreId: managerStoreId ?? this.managerStoreId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
