import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/contact/contact_links.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';

void main() {
  group('contact channels', () {
    test('drops a group whose URI is empty and never invents one', () {
      expect(contactCommunityUri(''), isNull);
      expect(contactCommunityUri('   '), isNull);
      expect(contactCommunityUri('notaurl'), isNull);
      expect(contactCommunityUri('javascript:alert(1)'), isNull);

      final channels = monettaContactChannels(
        whatsAppGroups: const [
          '',
          'https://chat.whatsapp.com/Kob3rTxvWzO53KVtXxS9DC',
        ],
        facebookGroup: ' ',
        socialLinks: const <HomeSocialLink>[],
      );

      expect(
        channels.map((channel) => channel.key).toList(),
        ['whatsapp', 'grupo-2'],
      );
      expect(
          channels.map((channel) => channel.title), isNot(contains('Grupo 1')));
      expect(
        channels.map((channel) => channel.title),
        isNot(contains('Grupo de Facebook')),
      );
      expect(
        channels.map((channel) => channel.title),
        isNot(contains('Mayoreo por WhatsApp')),
      );
      expect(
        channels.map((channel) => channel.title),
        isNot(contains('Contacto en monetta.mx')),
      );
      expect(channels[1].uri.toString(), monettaWhatsAppGroups[1]);
    });
  });

  group('ContactScreen', () {
    testWidgets('shows the v4.1 contact actions and hides retired ones', (
      tester,
    ) async {
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
      expect(find.text('Estamos para ayudarte'), findsOneWidget);
      expect(find.text('Enviar Whatsapp al 826 106 6868'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('+52 826 106 6868'), findsNothing);
      expect(find.text('Únete'), findsOneWidget);
      expect(find.text('A nuestros grupos de emprendedores'), findsOneWidget);
      expect(find.text('Grupo 1'), findsOneWidget);
      expect(find.text('Grupo 2'), findsOneWidget);
      expect(find.text('Grupo de Facebook'), findsOneWidget);
      expect(find.text('Síguenos en redes'), findsOneWidget);
      expect(
        find.text('Descubre novedades, lanzamientos y más.'),
        findsOneWidget,
      );
      expect(find.text('Mayoreo por WhatsApp'), findsNothing);
      expect(find.text('Contacto en monetta.mx'), findsNothing);
      expect(find.textContaining('Escríbenos'), findsNothing);
      expect(find.text('Más ayuda'), findsNothing);
      expect(find.textContaining('Horario, correo'), findsNothing);
      expect(find.text('Correo'), findsNothing);
      expect(find.textContaining('hola@monetta'), findsNothing);
      // Nothing opens until the person taps. The invite is not a join.
      expect(opened, isEmpty);

      final join = tester.getTopLeft(find.text('Únete'));
      final joinLine = tester.getTopLeft(
        find.text('A nuestros grupos de emprendedores'),
      );
      final button = tester.getBottomLeft(
        find.text('Enviar Whatsapp al 826 106 6868'),
      );
      expect(join.dx, joinLine.dx);
      expect(join.dx, lessThan(200));
      expect(join.dy, greaterThan(button.dy));
      expect(
        tester.getTopLeft(find.text('Grupo 1')).dy,
        greaterThan(joinLine.dy),
      );
      expect(
        tester.getTopLeft(find.text('Grupo 2')).dy,
        greaterThan(tester.getTopLeft(find.text('Grupo 1')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Grupo de Facebook')).dy,
        greaterThan(tester.getTopLeft(find.text('Grupo 2')).dy),
      );
    });

    testWidgets('hero lettering sits on the photograph', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const ContactScreen(),
        ),
      );
      await tester.pumpAndSettle();

      String? assetName(Key key) {
        final image = tester.widget<Image>(find.byKey(key));
        final provider = image.image;
        return provider is AssetImage ? provider.assetName : null;
      }

      expect(assetName(const ValueKey('contact-hero-title')),
          kContactLetteringTitle);
      expect(
        assetName(const ValueKey('contact-hero-body')),
        kContactLetteringDescription,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == kGuideContactHero,
        ),
        findsOneWidget,
      );

      final hero = tester.getRect(find.byKey(const ValueKey('contact-hero')));
      final title = tester.getRect(
        find.byKey(const ValueKey('contact-hero-title')),
      );
      final body = tester.getRect(
        find.byKey(const ValueKey('contact-hero-body')),
      );
      expect(hero.overlaps(title), isTrue);
      expect(hero.overlaps(body), isTrue);
      expect(title.bottom, lessThanOrEqualTo(hero.bottom + 0.5));
      expect(body.bottom, lessThanOrEqualTo(hero.bottom + 0.5));
      expect(body.top, greaterThanOrEqualTo(title.top));
      expect(
        tester.getTopLeft(find.text('Contáctanos')).dy,
        greaterThanOrEqualTo(hero.bottom - 0.5),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contact-hero')),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(find.textContaining('Tu boutique'), findsNothing);
      expect(find.textContaining('confianza'), findsNothing);
      expect(
        find.bySemanticsLabel(kContactHeroAccessibleLabel),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('the WhatsApp label stays one line at normal text size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: const ContactScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final finder = find.text('Enviar Whatsapp al 826 106 6868');
        final text = tester.widget<Text>(finder);
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
        expect(text.style?.fontSize, MonettaTokens.body.compact);
        final line = (text.style?.fontSize ?? 15) * (text.style?.height ?? 1);
        expect(tester.getSize(finder).height, lessThanOrEqualTo(line + 1));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('hides Grupo 1 and Facebook when those URIs are empty', (
      tester,
    ) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: ContactScreen(
            whatsAppGroups: const [
              '',
              'https://chat.whatsapp.com/Kob3rTxvWzO53KVtXxS9DC',
            ],
            facebookGroup: '',
            openUri: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grupo 1'), findsNothing);
      expect(
          find.byKey(const ValueKey('contact-channel-grupo-1')), findsNothing);
      expect(find.text('Grupo de Facebook'), findsNothing);
      expect(
        find.byKey(const ValueKey('contact-channel-facebook-group')),
        findsNothing,
      );
      expect(find.text('Grupo 2'), findsOneWidget);
      expect(opened, isEmpty);

      final row = find.byKey(const ValueKey('contact-channel-grupo-2'));
      await tester.scrollUntilVisible(row, 200);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse(monettaWhatsAppGroups[1])]);
    });

    testWidgets(
      'rows carry the gold guide icons and the networks are three '
      'icons with accessible labels',
      (tester) async {
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
        expect(
          assetIn('contact-channel-social-instagram'),
          kGuideIconInstagram,
        );
        expect(assetIn('contact-channel-social-facebook'), kGuideIconFacebook);
        expect(assetIn('contact-channel-social-tiktok'), kGuideIconTikTok);

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
      },
    );

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
      expect(opened, isEmpty);

      for (final key in [
        'contact-channel-whatsapp',
        'contact-channel-grupo-1',
        'contact-channel-grupo-2',
        'contact-channel-facebook-group',
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

      expect(opened, [
        conciergeWhatsAppUri(),
        ...monettaWhatsAppGroups.map(Uri.parse),
        Uri.parse(monettaFacebookGroup),
        Uri.parse('https://www.instagram.com/_monetta.mx'),
        Uri.parse('https://www.tiktok.com/@monetta.oficial'),
        Uri.parse(
          'https://www.facebook.com/profile.php?id=100091065527635',
        ),
      ]);
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
