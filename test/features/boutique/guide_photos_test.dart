import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';

import '../../support/client_guide_capture.dart';
import '../../support/guide_photo_finders.dart';

const _photos = <String>[
  kGuideHomeBannerEasy,
  kGuideHomeBannerNew,
  kGuideHomeBannerPerfumes,
  kGuideHomeWholesale,
  kGuideWholesaleHero,
  kGuideWholesaleBags,
  kGuideWholesalePerfumes,
  kGuideContactHero,
  kGuideShareCatalog,
  kGuideShareRewards,
  kGuideCollectionCoach,
  kGuideCollectionMichaelKors,
  kGuideCollectionSteveMadden,
  kGuideCollectionToryBurch,
  kGuideCollectionKateSpade,
  kGuideCollectionMarcJacobs,
  kGuideCollectionTotes,
  kGuideCollectionShoulder,
  kGuideCollectionCrossbody,
  kGuideCollectionHandbags,
  kGuideCollectionWallets,
  kGuideCollectionPerfumes,
  kGuideCollectionAccessories,
];

void main() {
  test('every owner photograph constant points at a shipped file', () {
    expect(_photos.toSet(), hasLength(_photos.length));
    for (final asset in _photos) {
      expect(asset, startsWith('assets/images/guide/'));
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  group('guideCollectionPhoto', () {
    test('resolves the six brands with the side that carries the text', () {
      const expected = <String, GuidePhoto>{
        'coach': GuidePhoto(kGuideCollectionCoach, GuideTextSide.right),
        'michael_kors':
            GuidePhoto(kGuideCollectionMichaelKors, GuideTextSide.right),
        'steve_madden':
            GuidePhoto(kGuideCollectionSteveMadden, GuideTextSide.right),
        'tory_burch':
            GuidePhoto(kGuideCollectionToryBurch, GuideTextSide.right),
        'kate_spade':
            GuidePhoto(kGuideCollectionKateSpade, GuideTextSide.right),
        'marc_jacobs':
            GuidePhoto(kGuideCollectionMarcJacobs, GuideTextSide.left),
      };
      expected.forEach((brand, photo) {
        expect(guideCollectionPhoto(brand: brand), photo, reason: brand);
      });
    });

    test('accepts display names and hyphenated handles for a brand', () {
      const michael =
          GuidePhoto(kGuideCollectionMichaelKors, GuideTextSide.right);
      expect(guideCollectionPhoto(brand: 'Michael Kors'), michael);
      expect(guideCollectionPhoto(brand: 'michael-kors'), michael);
      expect(guideCollectionPhoto(brand: ' COACH '), isNotNull);
    });

    test('resolves silhouettes', () {
      const left = GuideTextSide.left;
      expect(
        guideCollectionPhoto(silhouette: 'tote'),
        const GuidePhoto(kGuideCollectionTotes, left),
      );
      expect(
        guideCollectionPhoto(silhouette: 'shoulder'),
        const GuidePhoto(kGuideCollectionShoulder, left),
      );
      expect(
        guideCollectionPhoto(silhouette: 'crossbody'),
        const GuidePhoto(kGuideCollectionCrossbody, left),
      );
      for (final handbag in ['satchel', 'handbag', 'bolsa de mano']) {
        expect(
          guideCollectionPhoto(silhouette: handbag),
          const GuidePhoto(kGuideCollectionHandbags, left),
          reason: handbag,
        );
      }
    });

    test('resolves categories, the watch still serving accessories', () {
      const left = GuideTextSide.left;
      expect(
        guideCollectionPhoto(category: 'cartera'),
        const GuidePhoto(kGuideCollectionWallets, left),
      );
      expect(
        guideCollectionPhoto(category: 'perfume'),
        const GuidePhoto(kGuideCollectionPerfumes, left),
      );
      expect(
        guideCollectionPhoto(category: 'accesorio'),
        const GuidePhoto(kGuideCollectionAccessories, left),
      );
      expect(
        guideCollectionPhoto(category: 'reloj'),
        const GuidePhoto(kGuideCollectionAccessories, left),
      );
      expect(
        guideCollectionPhoto(category: 'bolsa'),
        const GuidePhoto(kGuideWholesaleBags, left),
      );
    });

    test('brand beats silhouette and silhouette beats category', () {
      expect(
        guideCollectionPhoto(
          brand: 'coach',
          silhouette: 'tote',
          category: 'bolsa',
        )?.asset,
        kGuideCollectionCoach,
      );
      expect(
        guideCollectionPhoto(silhouette: 'tote', category: 'bolsa')?.asset,
        kGuideCollectionTotes,
      );
      // A brand without its own still falls through; it never borrows another
      // brand's photograph.
      expect(
        guideCollectionPhoto(brand: 'guess', category: 'cartera')?.asset,
        kGuideCollectionWallets,
      );
    });

    test('returns null when nothing matches', () {
      expect(guideCollectionPhoto(), isNull);
      expect(guideCollectionPhoto(brand: 'guess'), isNull);
      expect(guideCollectionPhoto(silhouette: 'clutch'), isNull);
      expect(guideCollectionPhoto(category: 'set'), isNull);
      expect(guideCollectionPhoto(brand: '', silhouette: ' '), isNull);
    });
  });

  group('GuideHero text side', () {
    Future<void> pumpHero(WidgetTester tester, GuideTextSide side) {
      return pumpClientGuide(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: GuideHero(
            asset: kGuideWholesaleHero,
            title: 'MAYOREO',
            textSide: side,
          ),
        ),
      );
    }

    testWidgets('left (the default) puts the title in the left half', (
      tester,
    ) async {
      await pumpHero(tester, GuideTextSide.left);
      expect(
        tester.getCenter(find.text('MAYOREO')).dx,
        lessThan(390 / 2),
      );
      final scrim = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GuideScrim),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient =
          (scrim.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.begin, Alignment.centerLeft);
    });

    testWidgets('right puts the title in the right half and flips the scrim', (
      tester,
    ) async {
      await pumpHero(tester, GuideTextSide.right);
      expect(
        tester.getCenter(find.text('MAYOREO')).dx,
        greaterThan(390 / 2),
      );
      final scrim = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(GuideScrim),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient =
          (scrim.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.begin, Alignment.centerRight);
      expect(gradient.end, Alignment.centerLeft);
      expect(findAssetImage(kGuideWholesaleHero), findsOneWidget);
    });
  });
}
