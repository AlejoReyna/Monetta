import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/notifications/interest_profile_snapshot.dart';
import 'package:monetta_app/reco/profile.dart';

void main() {
  test('exports only bounded, scored affinities and no browsing history', () {
    final snapshot = InterestProfileSnapshot.fromTasteProfile(
      TasteProfile(
        weights: const {
          'brand:coach': .9,
          'brand:guess': .7,
          'brand:kate-spade': .5,
          'brand:fourth': .4,
          'category:bolsa': .8,
          'category:cartera': .6,
          'category:reloj': .3,
          'price_band:medio': .55,
        },
        eventCount: 26,
        builtAt: DateTime.utc(2026, 8, 25),
      ),
      profileVersion: 7,
      now: DateTime.utc(2026, 8, 25, 12),
    );

    expect(snapshot.topBrands, hasLength(3));
    expect(snapshot.topBrands.first, {'key': 'coach', 'score': 90});
    expect(snapshot.topCategories, hasLength(2));
    expect(snapshot.priceBand, 'medio');
    expect(snapshot.intentTier, 'high');
    expect(snapshot.signalCountBucket, '25_plus');
    expect(snapshot.toJson(), isNot(contains('events')));
    expect(snapshot.toJson(), isNot(contains('productIds')));
  });
}
