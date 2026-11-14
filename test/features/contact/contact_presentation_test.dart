import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/contact/contact_links.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import '../../support/client_guide_capture.dart';

void main() {
  for (final (size, scale, brightness) in [
    (const Size(390, 1100), 1.0, Brightness.light),
    (const Size(320, 568), 2.0, Brightness.light),
    (const Size(834, 1194), 1.0, Brightness.light),
    (const Size(390, 1100), 1.0, Brightness.dark),
  ]) {
    testWidgets(
      'configured communities and contact at $size / $scale / $brightness',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final opened = <Uri>[];
          await pumpClientGuide(
            tester,
            ContactScreen(
              openUri: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
            size: size,
            textScale: scale,
            brightness: brightness,
          );
          expect(
              find.bySemanticsLabel(kContactHeroAccessibleLabel), findsWidgets);
          expect(find.text('Enviar Whatsapp al 826 106 6868'), findsOneWidget);
          expect(find.text('Únete'), findsOneWidget);
          expect(
            find.text('A nuestros grupos de emprendedores'),
            findsOneWidget,
          );
          final hero =
              tester.getRect(find.byKey(const ValueKey('contact-hero')));
          final title = tester.getRect(
            find.byKey(const ValueKey('contact-hero-title')),
          );
          expect(hero.overlaps(title), isTrue);
          expect(title.bottom, lessThanOrEqualTo(hero.bottom + 0.5));
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('contact-hero')),
              matching: find.byType(Text),
            ),
            findsNothing,
          );
          if (scale == 1) {
            final label = tester.widget<Text>(
              find.text('Enviar Whatsapp al 826 106 6868'),
            );
            expect(label.maxLines, 1);
            await captureClientGuide(
              tester,
              'contact-${size.width.toInt()}-${brightness.name}',
            );
          }
          expect(opened, isEmpty);
          for (final key in ['grupo-1', 'grupo-2', 'facebook-group']) {
            final row = find.byKey(ValueKey('contact-channel-$key'));
            await tester.scrollUntilVisible(row, 200);
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            await tester.tap(row);
            await tester.pumpAndSettle();
          }
          expect(opened, [
            ...monettaWhatsAppGroups.map(Uri.parse),
            Uri.parse(monettaFacebookGroup),
          ]);
          expect(find.text('Más ayuda'), findsNothing);
          expect(find.textContaining('Horario, correo'), findsNothing);
          expect(find.text('Mayoreo por WhatsApp'), findsNothing);
          expect(find.text('Contacto en monetta.mx'), findsNothing);
          expect(find.textContaining('Escríbenos'), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets('missing social config stays empty, thrown launcher is explained',
      (
    tester,
  ) async {
    await pumpClientGuide(
      tester,
      ContactScreen(
        socialLinks: const [],
        openUri: (_) async => throw Exception('fixture failure'),
      ),
    );
    final row = find.byKey(const ValueKey('contact-channel-whatsapp'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Redes sociales: enlaces pendientes.'),
      300,
    );
    expect(
      find.byKey(const ValueKey('contact-channel-social-instagram')),
      findsNothing,
    );
  });
}
