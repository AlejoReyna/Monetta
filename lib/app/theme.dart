/// Visual language, matched to the Atelier storefront rather than Material blue.
///
/// The gold accent is taken from the live site's Loox widget configuration
/// (`#aa7d44`), so the app reads as the same brand as monetta.mx.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color kGold = Color(0xFFAA7D44);
const Color kInk = Color(0xFF1A1A1A);

/// Matches the store's `money_format` of `$ {{amount}}` in MXN.
final NumberFormat kMoney = NumberFormat.currency(
  locale: 'es_MX',
  symbol: r'$ ',
  decimalDigits: 2,
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kGold,
    primary: kGold,
    surface: Colors.white,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: kInk,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    ),
    textTheme: const TextTheme(
      titleMedium: TextStyle(fontWeight: FontWeight.w600, color: kInk),
      bodyMedium: TextStyle(color: kInk),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kGold.withValues(alpha: 0.10),
      side: BorderSide(color: kGold.withValues(alpha: 0.35)),
      labelStyle: const TextStyle(fontSize: 11, color: kInk),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kGold,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size.fromHeight(52),
      ),
    ),
  );
}
