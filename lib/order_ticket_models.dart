class OrderTicketStatus {
  static const incoming = 'incoming';
  static const onProgress = 'on_progress';
  static const finished = 'finished';

  static bool isValid(String value) {
    return value == incoming || value == onProgress || value == finished;
  }
}

class OrderTicketItem {
  const OrderTicketItem({
    required this.name,
    required this.quantity,
    this.note = '',
  });

  final String name;
  final int quantity;
  final String note;

  factory OrderTicketItem.fromJson(Map<String, dynamic> json) {
    return OrderTicketItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      note: (json['note'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'note': note,
    };
  }
}

class OrderTicket {
  const OrderTicket({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.createdAtIso,
    required this.total,
    required this.itemCount,
    this.items = const [],
    this.status = OrderTicketStatus.incoming,
  });

  final String id;
  final String orderNumber;
  final String customerName;
  final String createdAtIso;
  final int total;
  final int itemCount;
  final List<OrderTicketItem> items;
  final String status;

  bool get isIncoming => status == OrderTicketStatus.incoming;
  bool get isOnProgress => status == OrderTicketStatus.onProgress;
  bool get isFinished => status == OrderTicketStatus.finished;

  factory OrderTicket.fromJson(Map<String, dynamic> json) {
    return OrderTicket(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as String,
      customerName: json['customerName'] as String,
      createdAtIso: json['createdAtIso'] as String,
      total: json['total'] as int,
      itemCount: json['itemCount'] as int,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => OrderTicketItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: OrderTicketStatus.isValid((json['status'] as String?) ?? '')
          ? (json['status'] as String)
          : OrderTicketStatus.incoming,
    );
  }

  OrderTicket copyWith({String? status, List<OrderTicketItem>? items}) {
    return OrderTicket(
      id: id,
      orderNumber: orderNumber,
      customerName: customerName,
      createdAtIso: createdAtIso,
      total: total,
      itemCount: itemCount,
      items: items ?? this.items,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerName': customerName,
      'createdAtIso': createdAtIso,
      'total': total,
      'itemCount': itemCount,
      'items': items.map((item) => item.toJson()).toList(),
      'status': status,
    };
  }
}
