import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bluetooth_pos/receipt_builder.dart';
import 'package:simple_bluetooth_pos/receipt_models.dart';

void main() {
  test('buildReceiptLines creates totals correctly', () {
    final lines = ReceiptBuilder.buildReceiptLines(
      storeName: 'Test Store',
      storeAddress: 'Jl. Test No. 1',
      transactionDateTime: DateTime(2026, 4, 30, 14, 5),
      items: const [
        ReceiptItem(
          name: 'Coffee',
          quantity: 2,
          unitPrice: 12000,
          note: 'Less sugar',
        ),
        ReceiptItem(name: 'Bread', quantity: 1, unitPrice: 8000),
      ],
      customerName: 'Adit',
      orderNumber: 'ORD-001',
      paymentMethod: 'QRIS',
      bookingWhatsappNumber: '081234567890',
      wifiName: 'MyWifi',
      wifiPassword: 'secret123',
      paidAmount: 35000,
    );

    final text = lines.join('\n');

    expect(text, contains('Subtotal'));
    expect(text, contains('Rp32.000'));
    expect(text, contains('Paid'));
    expect(text, contains('Rp35.000'));
    expect(text, contains('Change'));
    expect(text, contains('Rp3.000'));
    expect(text, contains('30/04/2026 14:05'));
    expect(text, contains('Order #: ORD-001'));
    expect(text, contains('Name: Adit'));
    expect(text, contains('Payment: QRIS'));
    expect(text, contains('Booking WA: 081234567890'));
    expect(text, contains('WiFi: MyWifi'));
    expect(text, contains('Pass: secret123'));
    expect(text, contains('Note: Less sugar'));

    final orderIndex =
        lines.indexWhere((line) => line.contains('Order #: ORD-001'));
    final customerIndex =
        lines.indexWhere((line) => line.contains('Name: Adit'));
    final paymentIndex =
        lines.indexWhere((line) => line.contains('Payment: QRIS'));
    final firstSeparatorIndex = lines.indexWhere((line) => line == '-' * 32);
    final thankYouIndex =
        lines.indexWhere((line) => line.contains('Thank you!'));
    final bookingIndex =
        lines.indexWhere((line) => line.contains('Booking WA: 081234567890'));
    final wifiIndex = lines.indexWhere((line) => line.contains('WiFi: MyWifi'));

    expect(orderIndex, lessThan(firstSeparatorIndex));
    expect(customerIndex, lessThan(firstSeparatorIndex));
    expect(customerIndex, greaterThan(orderIndex));
    expect(paymentIndex, lessThan(firstSeparatorIndex));
    expect(bookingIndex, greaterThan(thankYouIndex));
    expect(wifiIndex, greaterThan(bookingIndex));
  });

  test('buildReceiptLines handles long item names', () {
    final lines = ReceiptBuilder.buildReceiptLines(
      storeName: 'Test Store',
      storeAddress: 'Jl. Test No. 1',
      transactionDateTime: DateTime(2026, 4, 30, 14, 5),
      items: const [
        ReceiptItem(
          name: 'Super Extra Long Product Name Beyond Limit',
          quantity: 1,
          unitPrice: 10000,
        ),
      ],
    );

    final line = lines.firstWhere((l) => l.contains('…'));
    expect(line.length, greaterThanOrEqualTo(20));
  });

  test('buildReceiptLines applies promo discount and net total', () {
    final lines = ReceiptBuilder.buildReceiptLines(
      storeName: 'Test Store',
      storeAddress: 'Jl. Test No. 1',
      transactionDateTime: DateTime(2026, 4, 30, 14, 5),
      items: const [
        ReceiptItem(name: 'Coffee', quantity: 2, unitPrice: 12000),
      ],
      discountAmount: 12000,
      promoLabel: 'Buy 1 Get 1 - Coffee',
      paidAmount: 12000,
    );

    final text = lines.join('\n');

    expect(text, contains('Subtotal'));
    expect(text, contains('Rp24.000'));
    expect(text, contains('Promo: Buy 1 Get 1 - Coffee'));
    expect(text, contains('Discount'));
    expect(text, contains('-Rp12.000'));
    expect(text, contains('Total'));
    expect(text, contains('Rp12.000'));
    expect(text, contains('Paid'));
    expect(text, contains('Change'));
    expect(text, contains('Rp0'));
  });
}
