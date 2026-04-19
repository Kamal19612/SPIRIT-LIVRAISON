class OrderItem {
  final int id;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;

  const OrderItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: (json['id'] as num).toInt(),
        productName: json['productName']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: _parseDouble(json['unitPrice']),
        total: _parseDouble(json['total']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      };
}

double _parseDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

class Order {
  final int id;
  final String orderNumber;
  final String? confirmationCode;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String? customerNotes;
  final double? customerLatitude;
  final double? customerLongitude;
  final double? distanceKm; // distance calculée depuis le livreur
  final String? deliveryType;
  final double? deliveryCost;
  final double subtotal;
  final double tax;
  final double total;
  final String status;
  final String createdAt;
  final String? updatedAt;
  final bool deleted;
  final Map<String, dynamic>? deliveryAgent;
  final List<OrderItem> items;
  final String syncStatus;
  final String sourcePlatform;

  const Order({
    required this.id,
    required this.orderNumber,
    this.confirmationCode,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.customerNotes,
    this.customerLatitude,
    this.customerLongitude,
    this.distanceKm,
    this.deliveryType,
    this.deliveryCost,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.deleted = false,
    this.deliveryAgent,
    this.items = const [],
    this.syncStatus = 'local',
    this.sourcePlatform = 'manual',
  });

  Order copyWith({double? distanceKm}) => Order(
        id: id,
        orderNumber: orderNumber,
        confirmationCode: confirmationCode,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        customerNotes: customerNotes,
        customerLatitude: customerLatitude,
        customerLongitude: customerLongitude,
        distanceKm: distanceKm ?? this.distanceKm,
        deliveryType: deliveryType,
        deliveryCost: deliveryCost,
        subtotal: subtotal,
        tax: tax,
        total: total,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deleted: deleted,
        deliveryAgent: deliveryAgent,
        items: items,
        syncStatus: syncStatus,
        sourcePlatform: sourcePlatform,
      );

  factory Order.fromSqlite(Map<String, dynamic> row) => Order(
        id: row['id'] as int,
        orderNumber: row['orderNumber']?.toString() ?? '',
        confirmationCode: row['confirmationCode']?.toString(),
        customerName: row['customerName']?.toString() ?? '',
        customerPhone: row['customerPhone']?.toString() ?? '',
        customerAddress: row['customerAddress']?.toString() ?? '',
        customerNotes: row['customerNotes']?.toString(),
        customerLatitude: row['customerLatitude'] != null
            ? (row['customerLatitude'] as num).toDouble()
            : null,
        customerLongitude: row['customerLongitude'] != null
            ? (row['customerLongitude'] as num).toDouble()
            : null,
        subtotal: 0,
        tax: 0,
        total: _parseDouble(row['total']),
        status: row['status']?.toString() ?? 'CONFIRMED',
        createdAt: row['createdAt']?.toString() ?? '',
        updatedAt: row['updatedAt']?.toString(),
        syncStatus: row['syncStatus']?.toString() ?? 'local',
        sourcePlatform: row['sourcePlatform']?.toString() ?? 'manual',
      );

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<OrderItem> itemsList = rawItems is List
        ? rawItems.map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList()
        : [];
    return Order(
      id: (json['id'] as num).toInt(),
      orderNumber: json['orderNumber']?.toString() ?? '',
      confirmationCode: json['confirmationCode']?.toString(),
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      customerAddress: json['customerAddress']?.toString() ?? '',
      customerNotes: json['customerNotes']?.toString(),
      customerLatitude:
          json['customerLatitude'] != null ? _parseDouble(json['customerLatitude']) : null,
      customerLongitude:
          json['customerLongitude'] != null ? _parseDouble(json['customerLongitude']) : null,
      subtotal: _parseDouble(json['subtotal']),
      tax: _parseDouble(json['tax']),
      total: _parseDouble(json['total']),
      status: json['status']?.toString() ?? 'CONFIRMED',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString(),
      deleted: json['deleted'] as bool? ?? false,
      deliveryAgent: json['deliveryAgent'] as Map<String, dynamic>?,
      items: itemsList,
      sourcePlatform: json['sourcePlatform']?.toString() ?? 'manual',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'confirmationCode': confirmationCode,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerAddress': customerAddress,
        'customerNotes': customerNotes,
        'customerLatitude': customerLatitude,
        'customerLongitude': customerLongitude,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted,
        'deliveryAgent': deliveryAgent,
        'items': items.map((e) => e.toJson()).toList(),
        'sourcePlatform': sourcePlatform,
      };
}
