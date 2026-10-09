import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String _interLicenseAsset = 'assets/fonts/inter/OFL.txt';
const String _playfairLicenseAsset = 'assets/fonts/playfair_display/OFL.txt';

bool _registered = false;

/// Adds the SIL Open Font License texts of the bundled fonts to the
/// [LicenseRegistry], so they show up in the app's licence page.
///
/// Idempotent: calling it more than once registers a single collector.
void registerFontLicenses() {
  if (_registered) {
    return;
  }
  _registered = true;
  LicenseRegistry.addLicense(_collectFontLicenses);
}

Stream<LicenseEntry> _collectFontLicenses() async* {
  yield LicenseEntryWithLineBreaks(
    const <String>['Inter'],
    await rootBundle.loadString(_interLicenseAsset),
  );
  yield LicenseEntryWithLineBreaks(
    const <String>['Playfair Display'],
    await rootBundle.loadString(_playfairLicenseAsset),
  );
}
