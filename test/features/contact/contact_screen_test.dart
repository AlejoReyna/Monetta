import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';

void main() {
  group('ContactScreen', () {
    testWidgets('renders only verified channels with real destinations',
        (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: ContactScreen(
            openUri: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contáctanos'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('826 106 6868'), findsOneWidget);
      expect(find.text('Mayoreo por WhatsApp'), findsOneWidget);
      expect(find.text('Contacto en monetta.mx'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('TikTok'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      // Sin buzón ni línea de voz verificados: no se renderizan.
      expect(find.text('Correo'), findsNothing);
      expect(find.textContaining('hola@monetta'), findsNothing);
    });

    testWidgets('every channel opens its real URI', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: ContactScreen(
            openUri: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final key in [
        'contact-channel-whatsapp',
        'contact-channel-mayoreo',
        'contact-channel-sitio',
        'contact-channel-social-instagram',
        'contact-channel-social-tiktok',
        'contact-channel-social-facebook',
      ]) {
        final row = find.byKey(ValueKey(key));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
      }

      expect(opened, hasLength(6));
      expect(
        opened[0].toString(),
        startsWith('https://wa.me/528261066868'),
      );
      expect(
        opened[1].toString(),
        startsWith('https://wa.me/528261066868'),
      );
      expect(opened[2], kMonettaContactPageUri);
      expect(opened[2].toString(), 'https://monetta.mx/pages/contact');
      expect(opened[3].toString(), contains('instagram.com'));
      expect(opened[4].toString(), contains('tiktok.com'));
      expect(opened[5].toString(), contains('facebook.com'));
    });

    testWidgets('a failed open explains itself', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: ContactScreen(openUri: (_) async => false),
        ),
      );
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('contact-channel-whatsapp'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
    });
  });
}
