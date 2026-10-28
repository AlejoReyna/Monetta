import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
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
      // The guide shows the number with its country code.
      expect(find.text('+52 826 106 6868'), findsOneWidget);
      expect(find.text('826 106 6868'), findsNothing);
      // «Más ayuda» is not in the guide: its two rows are gone.
      expect(find.text('Más ayuda'), findsNothing);
      expect(find.text('Mayoreo por WhatsApp'), findsNothing);
      expect(find.text('Contacto en monetta.mx'), findsNothing);
      expect(find.textContaining('Horario, correo'), findsNothing);
      // Sin buzón ni línea de voz verificados: no se renderizan.
      expect(find.text('Correo'), findsNothing);
      expect(find.textContaining('hola@monetta'), findsNothing);
    });

    testWidgets(
        'rows carry the gold guide icons and the networks are three '
        'icons with accessible labels', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const ContactScreen(),
        ),
      );
      await tester.pumpAndSettle();

      String? assetIn(String key) {
        final images = find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Image),
        );
        expect(images, findsOneWidget, reason: key);
        final provider = tester.widget<Image>(images).image;
        return provider is AssetImage ? provider.assetName : null;
      }

      expect(assetIn('contact-channel-whatsapp'), kGuideIconContactWhatsApp);
      expect(assetIn('contact-channel-grupo-1'), kGuideIconContactGroup);
      expect(assetIn('contact-channel-grupo-2'), kGuideIconContactGroup);
      expect(
        assetIn('contact-channel-facebook-group'),
        kGuideIconContactGroup,
      );
      expect(assetIn('contact-channel-social-instagram'), kGuideIconInstagram);
      expect(assetIn('contact-channel-social-facebook'), kGuideIconFacebook);
      expect(assetIn('contact-channel-social-tiktok'), kGuideIconTikTok);

      // Networks sit in the guide's order, side by side, without text.
      final instagram = tester.getCenter(
        find.byKey(const ValueKey('contact-channel-social-instagram')),
      );
      final facebook = tester.getCenter(
        find.byKey(const ValueKey('contact-channel-social-facebook')),
      );
      final tiktok = tester.getCenter(
        find.byKey(const ValueKey('contact-channel-social-tiktok')),
      );
      expect(instagram.dy, facebook.dy);
      expect(facebook.dy, tiktok.dy);
      expect(instagram.dx, lessThan(facebook.dx));
      expect(facebook.dx, lessThan(tiktok.dx));
      expect(find.text('Instagram'), findsNothing);
      expect(find.text('TikTok'), findsNothing);
      expect(find.bySemanticsLabel('Instagram'), findsOneWidget);
      expect(find.bySemanticsLabel('Facebook'), findsOneWidget);
      expect(find.bySemanticsLabel('TikTok'), findsOneWidget);
      semantics.dispose();
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

      expect(opened, hasLength(4));
      expect(
        opened[0].toString(),
        startsWith('https://wa.me/528261066868'),
      );
      expect(opened[1].toString(), contains('instagram.com'));
      expect(opened[2].toString(), contains('tiktok.com'));
      expect(opened[3].toString(), contains('facebook.com'));
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
