class TransactionLine {
  const TransactionLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.note = '',
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final String note;

  int get total => quantity * unitPrice;

  factory TransactionLine.fromJson(Map<String, dynamic> json) {
    return TransactionLine(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      unitPrice: json['unitPrice'] as int,
      note: (json['note'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'note': note,
    };
  }
}

class PosTransaction {
  const PosTransaction({
    required this.id,
    required this.createdAtIso,
    required this.storeName,
    required this.paymentMethod,
    required this.lines,
    this.promoType = 'none',
    this.promoLabel = '',
    this.grossSubtotal = 0,
    this.discountAmount = 0,
    required this.total,
    required this.synced,
  });

  final String id;
  final String createdAtIso;
  final String storeName;
  final String paymentMethod;
  final List<TransactionLine> lines;
  final String promoType;
  final String promoLabel;
  final int grossSubtotal;
  final int discountAmount;
  final int total;
  final bool synced;

  PosTransaction copyWith({
    String? id,
    String? createdAtIso,
    String? storeName,
    String? paymentMethod,
    List<TransactionLine>? lines,
    String? promoType,
    String? promoLabel,
    int? grossSubtotal,
    int? discountAmount,
    int? total,
    bool? synced,
  }) {
    return PosTransaction(
      id: id ?? this.id,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      storeName: storeName ?? this.storeName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      lines: lines ?? this.lines,
      promoType: promoType ?? this.promoType,
      promoLabel: promoLabel ?? this.promoLabel,
      grossSubtotal: grossSubtotal ?? this.grossSubtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      total: total ?? this.total,
      synced: synced ?? this.synced,
    );
  }

  factory PosTransaction.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List<dynamic>? ?? [];
    return PosTransaction(
      id: json['id'] as String,
      createdAtIso: json['createdAtIso'] as String,
      storeName: json['storeName'] as String,
      paymentMethod: json['paymentMethod'] as String? ?? 'Cash',
      lines: rawLines
          .map((e) => TransactionLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      promoType: json['promoType'] as String? ?? 'none',
      promoLabel: json['promoLabel'] as String? ?? '',
      grossSubtotal: json['grossSubtotal'] as int? ?? (json['total'] as int),
      discountAmount: json['discountAmount'] as int? ?? 0,
      total: json['total'] as int,
      synced: json['synced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAtIso': createdAtIso,
      'storeName': storeName,
      'paymentMethod': paymentMethod,
      'lines': lines.map((e) => e.toJson()).toList(),
      'promoType': promoType,
      'promoLabel': promoLabel,
      'grossSubtotal': grossSubtotal,
      'discountAmount': discountAmount,
      'total': total,
      'synced': synced,
    };
  }
}
