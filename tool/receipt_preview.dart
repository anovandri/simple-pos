import 'package:simple_bluetooth_pos/receipt_builder.dart';
import 'package:simple_bluetooth_pos/receipt_models.dart';

void main() {
  final lines = ReceiptBuilder.buildReceiptLines(
    storeName: 'Kreasi Positif',
    storeAddress: 'Jl. Bahagia No. 99',
    transactionDateTime: DateTime(2026, 4, 30, 18, 30),
    items: const [
      ReceiptItem(name: 'Nasi Goreng', quantity: 2, unitPrice: 18000),
      ReceiptItem(name: 'Es Teh', quantity: 3, unitPrice: 5000),
    ],
    wifiName: 'KREASI-WIFI',
    wifiPassword: '12345678',
    paidAmount: 60000,
  );

  for (final line in lines) {
    // ignore: avoid_print
    print(line);
  }
}
