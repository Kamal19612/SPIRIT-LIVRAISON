/// Backend Spring (STORE-ALL ou compatible) configuré dans l’app.
class BackendServer {
  final int? id;
  final String name;
  final String origin;
  final String storeCode;
  final bool isActive;
  final String createdAt;

  const BackendServer({
    this.id,
    required this.name,
    required this.origin,
    this.storeCode = '',
    this.isActive = true,
    this.createdAt = '',
  });

  factory BackendServer.fromSqlite(Map<String, dynamic> row) {
    return BackendServer(
      id: row['id'] as int?,
      name: row['name']?.toString() ?? '',
      origin: row['origin']?.toString() ?? '',
      storeCode: row['storeCode']?.toString() ?? '',
      isActive: (row['isActive'] as int? ?? 1) == 1,
      createdAt: row['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'name': name,
        'origin': origin,
        'storeCode': storeCode,
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
    bool? isActive,
    String? createdAt,
  }) {
    return BackendServer(
      id: id ?? this.id,
      name: name ?? this.name,
      origin: origin ?? this.origin,
      storeCode: storeCode ?? this.storeCode,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
