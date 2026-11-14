import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';

void main() {
  final groups = {
    'grupo-1': Uri.parse('https://fixture.example/group1'),
    'grupo-2': Uri.parse('https://fixture.example/group2'),
    'facebook-group': Uri.parse('https://fixture.example/group3')
  };
  const socials = [
    HomeSocialLink(
        id: 'instagram',
        label: 'Instagram',
        url: 'https://fixture.example/instagram'),
    HomeSocialLink(
        id: 'facebook',
        label: 'Facebook',
        url: 'https://fixture.example/facebook'),
    HomeSocialLink(
        id: 'tiktok', label: 'TikTok', url: 'https://fixture.example/tiktok')
  ];
  testWidgets('C5 copy and only authorized destinations appear',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: buildTheme(), home: const ContactScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Contáctanos'), findsOneWidget);
    expect(find.text('Enviar Whatsapp al 826 106 6868'), findsOneWidget);
    expect(find.text('Únete'), findsOneWidget);
    expect(find.text('A nuestros grupos de emprendedores'), findsOneWidget);
    expect(find.byKey(const ValueKey('contact-channel-grupo-1')), findsNothing);
    expect(find.byKey(const ValueKey('contact-channel-social-instagram')),
        findsNothing);
    expect(find.text('Correo'), findsNothing);
  });
  testWidgets(
      'configured channels open only on tap with accessible social labels',
      (tester) async {
    final opened = <Uri>[];
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: ContactScreen(
            groups: groups,
            socialLinks: socials,
            openUri: (uri) async {
              opened.add(uri);
              return true;
            })));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    for (final key in [
      'whatsapp',
      'grupo-1',
      'grupo-2',
      'facebook-group',
      'social-instagram',
      'social-facebook',
      'social-tiktok'
    ]) {
      final button = find.byKey(ValueKey('contact-channel-$key'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    expect(opened, [
      Uri.parse('https://wa.me/528261066868'),
      ...groups.values,
      ...socials.map((s) => s.uri)
    ]);
    expect(opened.first.query, isEmpty);
    expect(find.bySemanticsLabel('Instagram'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('a failed open explains itself', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(), home: ContactScreen(openUri: (_) async => false)));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('contact-channel-whatsapp')));
    await tester.tap(find.byKey(const ValueKey('contact-channel-whatsapp')));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
  });
}
