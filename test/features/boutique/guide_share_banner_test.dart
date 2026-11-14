import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/rewards/rewards_share_screen.dart';

import '../../support/client_guide_capture.dart';
import '../../support/guide_photo_finders.dart';

void main() {
  testWidgets(
      'Rewards share uses the rewards photo with its body and no '
      'button', (tester) async {
    await pumpClientGuide(
      tester,
      const RewardsShareScreen(),
      size: const Size(390, 1200),
    );
    expect(findAssetImage(kGuideShareRewards), findsOneWidget);
    expect(find.text('Comparte'), findsOneWidget);
    expect(find.text('y gana'), findsOneWidget);
    expect(
      find.text(
        'Explora nuestros catálogos, compártelos con el mundo y comienza a '
        'ganar desde tu primer pedido.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(GuideShareEarnBanner),
        matching: find.byType(ButtonStyleButton),
      ),
      findsNothing,
    );
    // The generated phone mockup is gone.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('rewards_phone'),
      ),
      findsNothing,
    );
  });
}
