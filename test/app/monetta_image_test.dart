import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/app/theme.dart';

void main() {
  testWidgets('a missing URL shows the wordmark fallback, not an empty box',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 160,
            child: MonettaImage(url: null),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MonettaWordmark), findsOneWidget);
  });

  testWidgets('a non-https URL shows the wordmark fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 160,
            child: MonettaImage(url: 'http://example.com/bag.jpg'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MonettaWordmark), findsOneWidget);
  });
}
