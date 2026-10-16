import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/seasonal_campaign.dart';

SeasonalCampaign _campaign({
  String title = 'Nueva temporada',
  String? imageUrl,
  String? ipadImageUrl,
  DateTime? startsAt,
  DateTime? endsAt,
  String? handle = 'otono',
}) {
  return SeasonalCampaign(
    title: title,
    imageUrl: imageUrl,
    ipadImageUrl: ipadImageUrl,
    collectionHandle: handle,
    startsAt: startsAt,
    endsAt: endsAt,
  );
}

void main() {
  final now = DateTime.utc(2026, 10, 14);

  test('a campaign is active inside an inclusive start and exclusive end', () {
    final campaign = _campaign(
      startsAt: DateTime.utc(2026, 10, 14),
      endsAt: DateTime.utc(2026, 12, 1),
    );

    expect(campaign.isActiveAt(now), isTrue);
    expect(
      campaign.isActiveAt(DateTime.utc(2026, 12, 1)),
      isFalse,
    );
    expect(
      campaign.isActiveAt(DateTime.utc(2026, 10, 13, 23, 59)),
      isFalse,
    );
  });

  test('missing dates stay active and empty entries do not', () {
    expect(_campaign().isActiveAt(now), isTrue);
    expect(
      _campaign(title: '  ', handle: null).isActiveAt(now),
      isFalse,
    );
    expect(
      _campaign(title: '', imageUrl: 'https://cdn.example/a.jpg')
          .isActiveAt(now),
      isTrue,
    );
  });

  test('the latest start wins and an undated campaign loses to a dated one',
      () {
    final early =
        _campaign(title: 'Temprana', startsAt: DateTime.utc(2026, 1, 1));
    final late = _campaign(title: 'Tardía', startsAt: DateTime.utc(2026, 9, 1));
    final undated = _campaign(title: 'Siempre');
    final expired = _campaign(
      title: 'Pasada',
      endsAt: DateTime.utc(2026, 2, 1),
    );

    expect(
      pickActiveSeasonalCampaign([early, undated, late, expired], now)?.title,
      'Tardía',
    );
    expect(
      pickActiveSeasonalCampaign([expired], now),
      isNull,
    );
  });

  test('iPad art prefers ipadImage and falls back to the phone file', () {
    final both = _campaign(
      imageUrl: 'https://cdn.example/phone.jpg',
      ipadImageUrl: 'https://cdn.example/ipad.jpg',
    );
    expect(both.imageFor(ipad: false), 'https://cdn.example/phone.jpg');
    expect(both.imageFor(ipad: true), 'https://cdn.example/ipad.jpg');
    expect(
      _campaign(imageUrl: 'https://cdn.example/phone.jpg').imageFor(ipad: true),
      'https://cdn.example/phone.jpg',
    );
  });
}
