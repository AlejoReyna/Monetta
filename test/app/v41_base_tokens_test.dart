// MONETTA UI v4.1 base: the confirmed colours, faces and halo of
// 02_sistema/tokens_v4.1.json, and every asset the v4.1 manifest names.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';

void main() {
  test('v4.1 confirmed colours', () {
    expect(MonettaTokens.canvas, const Color(0xFFFFFFFF)); // blanco puro
    expect(MonettaTokens.gold, const Color(0xFFA58248));
    expect(MonettaTokens.success, const Color(0xFF3B7030));
    expect(MonettaTokens.ink, const Color(0xFF242622));
    expect(MonettaTokens.inkMuted, const Color(0xFF595D56));
    expect(MonettaTokens.sale, const Color(0xFFA63535));
    expect(MonettaTokens.soldBadge, const Color(0xFF111111));
    expect(MonettaTokens.onSoldBadge, const Color(0xFFFFFFFF));
    expect(MonettaTokens.focusColor, const Color(0xFF1F211F));
    expect(MonettaTokens.focusWidth, 2);
    expect(MonettaTokens.focusOffset, 3);
  });

  test('v4.1 halo C: gold at 18%, blur 10, spread 2', () {
    expect(MonettaTokens.haloColor, const Color(0x2EA58248));
    expect(MonettaTokens.haloBlur, 10);
    expect(MonettaTokens.haloSpread, 2);
  });

  test('v4.1 faces: DM Sans for UI, Cormorant Garamond editorial', () {
    expect(MonettaTokens.sansFamily, 'DM Sans');
    expect(MonettaTokens.serifFamily, 'Cormorant Garamond');
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final path in <String>[
      'assets/fonts/dm_sans/DMSans-Regular.ttf',
      'assets/fonts/dm_sans/DMSans-SemiBold.ttf',
      'assets/fonts/dm_sans/DMSans-Bold.ttf',
      'assets/fonts/cormorant_garamond/CormorantGaramond-Regular.ttf',
      'assets/fonts/cormorant_garamond/CormorantGaramond-Bold.ttf',
    ]) {
      expect(pubspec, contains(path));
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('every v4.1 asset in the manifest ships with the app and the theme', () {
    final manifest = jsonDecode(
      File('design-system/v41-assets.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final banners = manifest['banners'] as List<dynamic>;
    final photos = manifest['home_photos'] as List<dynamic>;
    final icons = manifest['icons'] as List<dynamic>;
    expect(banners, hasLength(33)); // B01–B32 + B04 editorial
    expect(photos, hasLength(18));
    expect(icons, hasLength(61));
    for (final entry in <dynamic>[...banners, ...photos, ...icons]) {
      final map = entry as Map<String, dynamic>;
      expect(
        File(map['app'] as String).existsSync(),
        isTrue,
        reason: map['app'] as String,
      );
      final web = map['web'];
      final webFiles =
          web is Map ? web.values.cast<String>() : <String>[web as String];
      for (final file in webFiles) {
        expect(
          File('storefront-theme/assets/$file').existsSync(),
          isTrue,
          reason: file,
        );
      }
    }
    final f11 = photos.cast<Map<String, dynamic>>().firstWhere(
          (p) => p['id'] == 'F11',
        );
    expect(f11['key'], 'carteras_hombre'); // Corrección 5 p89
  });
}
