import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/app/theme_controller.dart';
import 'package:monetta_app/data/local/appearance_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/settings/appearance_sheet.dart';

void main() {
  testWidgets('shopper can choose all three appearance modes', (tester) async {
    final database = openTestDatabase();
    addTearDown(database.close);
    final controller = ThemeController(store: AppearanceStore(database));

    await tester.pumpWidget(
      ThemeScope(
        notifier: controller,
        child: MaterialApp(
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openAppearanceSettings(context),
              child: const Text('Abrir apariencia'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir apariencia'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('appearance-system')), findsOneWidget);
    expect(find.byKey(const ValueKey('appearance-light')), findsOneWidget);
    expect(find.byKey(const ValueKey('appearance-dark')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('appearance-dark')));
    await tester.pump();
    expect(controller.mode, ThemeMode.dark);
  });
}
