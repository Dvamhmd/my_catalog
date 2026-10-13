import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_catalog/screens/settings_screen.dart';
import 'package:my_catalog/widgets/app_drawer.dart';

void main() {
  testWidgets('SettingsScreen displays Pengaturan title and Data Dummy switch without menu count', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Pengaturan'), findsOneWidget);

    // Verify Data Dummy text exists
    expect(find.text('Data Dummy'), findsOneWidget);

    // Verify NO menu count text
    expect(find.textContaining('32 Menu'), findsNothing);
    expect(find.textContaining('Off'), findsNothing);

    // Verify Switch exists
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('AppDrawer contains Pengaturan button and opens SettingsScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: AppDrawer(
            activeMenu: AppDrawerMenu.admin,
            onSelectMenu: (_) {},
          ),
          body: const SizedBox(),
        ),
      ),
    );

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Verify Pengaturan button exists in drawer bottom
    expect(find.text('Pengaturan'), findsOneWidget);

    // Tap Pengaturan
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    // Verify navigated to SettingsScreen
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Data Dummy'), findsOneWidget);
  });
}
