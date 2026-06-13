class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.productId = '',
    this.note = '',
  });

  final String name;
  final int quantity;
  final int unitPrice;
  final String productId;
  final String note;

  int get total => quantity * unitPrice;
}
