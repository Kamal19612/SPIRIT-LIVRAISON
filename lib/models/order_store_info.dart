/// Boutique d’origine d’une commande (JSON Spring `order.store`).
class OrderStoreInfo {
  final int? id;
  final String name;
  final String code;
  final String? phone;
  final String? mapsUrl;

  const OrderStoreInfo({
    this.id,
    required this.name,
    required this.code,
    this.phone,
    this.mapsUrl,
  });

  factory OrderStoreInfo.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'];
    int? id;
    if (idVal is int) {
      id = idVal;
    } else if (idVal is num) {
      id = idVal.toInt();
    }
    return OrderStoreInfo(
      id: id,
      name: json['name']?.toString().trim() ?? '',
      code: json['code']?.toString().trim().toLowerCase() ?? '',
      phone: json['phone']?.toString().trim(),
      mapsUrl: json['mapsUrl']?.toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'code': code,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (mapsUrl != null && mapsUrl!.isNotEmpty) 'mapsUrl': mapsUrl,
      };

  bool get hasDisplayInfo =>
      name.isNotEmpty || code.isNotEmpty || (phone?.isNotEmpty ?? false);
}

/// Point de retrait affiché sur la carte livreur (aligné PWA STORE-ALL).
class OrderPickupInfo {
  final String name;
  final String code;
  final String phone;
  final String location;

  const OrderPickupInfo({
    required this.name,
    required this.code,
    required this.phone,
    required this.location,
  });
}
