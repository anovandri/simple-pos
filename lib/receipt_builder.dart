import 'receipt_models.dart';

class ReceiptBuilder {
  static List<String> buildReceiptLines({
    required String storeName,
    required String storeAddress,
    required DateTime transactionDateTime,
    required List<ReceiptItem> items,
    String? customerName,
    String? orderNumber,
    String? paymentMethod,
    String? bookingWhatsappNumber,
    String? wifiName,
    String? wifiPassword,
    int discountAmount = 0,
    String? promoLabel,
    int? paidAmount,
    int lineWidth = 32,
  }) {
    final grossSubtotal = _subtotal(items);
    final sanitizedDiscount = discountAmount < 0
        ? 0
        : (discountAmount > grossSubtotal ? grossSubtotal : discountAmount);
    final netSubtotal = grossSubtotal - sanitizedDiscount;
    final payment = paidAmount ?? netSubtotal;
    final change = payment - netSubtotal;
    final itemNameWidth = lineWidth >= 48 ? 30 : 18;
    const qtyWidth = 3;
    final totalWidth = lineWidth - itemNameWidth - qtyWidth;

    final normalizedAddress = storeAddress.trim();
    final formattedDate = _formatDateTime(transactionDateTime);
    final normalizedCustomerName = customerName?.trim() ?? '';
    final normalizedOrderNumber = orderNumber?.trim() ?? '';
    final normalizedPaymentMethod = paymentMethod?.trim() ?? '';
    final normalizedBookingWhatsapp = bookingWhatsappNumber?.trim() ?? '';
    final normalizedWifiName = wifiName?.trim() ?? '';
    final normalizedWifiPassword = wifiPassword?.trim() ?? '';
    final normalizedPromoLabel = promoLabel?.trim() ?? '';

    final lines = <String>[
      _center(storeName, width: lineWidth),
      if (normalizedAddress.isNotEmpty)
        _center(normalizedAddress, width: lineWidth),
      _center(formattedDate, width: lineWidth),
      if (normalizedOrderNumber.isNotEmpty)
        _center('Order #: $normalizedOrderNumber', width: lineWidth),
      if (normalizedCustomerName.isNotEmpty)
        _center('Name: $normalizedCustomerName', width: lineWidth),
      if (normalizedPaymentMethod.isNotEmpty)
        _center('Payment: $normalizedPaymentMethod', width: lineWidth),
      '-' * lineWidth,
      _headerLine(itemNameWidth, qtyWidth, totalWidth),
      '-' * lineWidth,
      ...items.expand(
        (item) => _formatItemLines(
          item,
          itemNameWidth: itemNameWidth,
          qtyWidth: qtyWidth,
          totalWidth: totalWidth,
          lineWidth: lineWidth,
        ),
      ),
      '-' * lineWidth,
      _row('Subtotal', _idr(grossSubtotal), width: lineWidth),
      if (normalizedPromoLabel.isNotEmpty)
        ..._wrapText('Promo: $normalizedPromoLabel', width: lineWidth),
      if (sanitizedDiscount > 0)
        _row('Discount', '-${_idr(sanitizedDiscount)}', width: lineWidth),
      _row('Total', _idr(netSubtotal), width: lineWidth),
      _row('Paid', _idr(payment), width: lineWidth),
      _row('Change', _idr(change < 0 ? 0 : change), width: lineWidth),
      '-' * lineWidth,
      _center('Thank you!', width: lineWidth),
      if (normalizedBookingWhatsapp.isNotEmpty)
        _center('Booking WA: $normalizedBookingWhatsapp', width: lineWidth),
      if (normalizedWifiName.isNotEmpty)
        _center('WiFi: $normalizedWifiName', width: lineWidth),
      if (normalizedWifiPassword.isNotEmpty)
        _center('Pass: $normalizedWifiPassword', width: lineWidth),
      '',
    ];

    return lines;
  }

  static int _subtotal(List<ReceiptItem> items) {
    return items.fold(0, (sum, item) => sum + item.total);
  }

  static String _headerLine(int itemNameWidth, int qtyWidth, int totalWidth) {
    return '${'Item'.padRight(itemNameWidth)}${'Qty'.padLeft(qtyWidth)}${'Total'.padLeft(totalWidth)}';
  }

  static List<String> _formatItemLines(
    ReceiptItem item, {
    required int itemNameWidth,
    required int qtyWidth,
    required int totalWidth,
    required int lineWidth,
  }) {
    final maxNameLength = itemNameWidth;
    final name = item.name.length > maxNameLength
        ? '${item.name.substring(0, maxNameLength - 1)}…'
        : item.name;
    final paddedName = name.padRight(itemNameWidth);
    final qty = item.quantity.toString().padLeft(qtyWidth);
    final total = _idr(item.total).padLeft(totalWidth);
    final lines = <String>['$paddedName$qty$total'];

    final normalizedNote = item.note.trim();
    if (normalizedNote.isNotEmpty) {
      lines.addAll(_wrapText('  - Note: $normalizedNote', width: lineWidth));
    }

    return lines;
  }

  static String _row(String label, String value, {required int width}) {
    final valueWidth = value.length + 1;
    final maxLabelWidth = width - valueWidth;
    if (maxLabelWidth <= 0) {
      return _leftClamp('$label $value', width: width);
    }
    final normalizedLabel = label.length > maxLabelWidth
        ? label.substring(0, maxLabelWidth)
        : label;
    return '${normalizedLabel.padRight(maxLabelWidth)}${value.padLeft(valueWidth)}';
  }

  static String _leftClamp(String text, {required int width}) {
    if (text.length <= width) return text;
    if (width <= 3) return text.substring(0, width);
    return '${text.substring(0, width - 3)}...';
  }

  static List<String> _wrapText(String text, {required int width}) {
    final normalized = text.trimRight();
    if (normalized.isEmpty) return [''];
    if (normalized.length <= width) return [normalized];

    final words = normalized.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      if (word.isEmpty) continue;
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length <= width) {
        current = candidate;
        continue;
      }

      if (current.isNotEmpty) {
        lines.add(current);
      }

      if (word.length <= width) {
        current = word;
        continue;
      }

      var remaining = word;
      while (remaining.length > width) {
        lines.add(remaining.substring(0, width));
        remaining = remaining.substring(width);
      }
      current = remaining;
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }

    return lines.isEmpty ? [''] : lines;
  }

  static String _idr(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final positionFromEnd = raw.length - i;
      buffer.write(raw[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'Rp$buffer';
  }

  static String _center(String text, {int width = 32}) {
    if (text.length >= width) return text;
    final totalPadding = width - text.length;
    final leftPadding = totalPadding ~/ 2;
    return '${' ' * leftPadding}$text';
  }

  static String _formatDateTime(DateTime dateTime) {
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final yyyy = dateTime.year.toString();
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }
}
