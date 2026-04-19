import 'package:flutter_test/flutter_test.dart';
import 'package:appstore/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DeliveryApp());
    expect(find.byType(DeliveryApp), findsOneWidget);
  });
}
