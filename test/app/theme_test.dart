import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';

void main() {
  test('light and dark themes expose complete semantic palettes', () {
    final light = buildLightTheme();
    final dark = buildDarkTheme();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(
      light.extension<MonettaColors>(),
      same(MonettaColors.light),
    );
    expect(
      dark.extension<MonettaColors>(),
      same(MonettaColors.dark),
    );
    expect(
      dark.scaffoldBackgroundColor,
      MonettaColors.dark.canvas,
    );
    expect(
      dark.appBarTheme.backgroundColor,
      MonettaColors.dark.surface,
    );
  });

  testWidgets('semantic context colors follow ThemeMode', (tester) async {
    Color? canvas;
    Color? content;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            canvas = context.monettaColors.canvas;
            content = context.monettaColors.contentPrimary;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(canvas, MonettaColors.dark.canvas);
    expect(content, MonettaColors.dark.contentPrimary);
  });

  testWidgets('section headings use the fluid editorial title reveal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: SectionHeading(
            kicker: 'LO QUE DICEN',
            title: 'Experiencias de clientes',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(EditorialTitleReveal), findsOneWidget);
    expect(find.text('Experiencias de clientes'), findsOneWidget);
    expect(find.text('LO QUE DICEN'), findsOneWidget);
  });
}
