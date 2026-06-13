// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:simple_bluetooth_pos/main.dart';

void main() {
  testWidgets('POS home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PosApp());

    expect(find.text('Simple Bluetooth POS'), findsOneWidget);
    expect(find.textContaining('Sync ('), findsOneWidget);
    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();

    expect(find.text('Add sale item from saved products'), findsOneWidget);
  });
}
