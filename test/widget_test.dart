import 'package:flutter_test/flutter_test.dart';
import 'package:my_catalog/main.dart';

void main() {
  testWidgets('MyCatalogApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyCatalogApp());
    expect(find.byType(MyCatalogApp), findsOneWidget);
    expect(find.text('Welcome Naila'), findsOneWidget);
  });
}

