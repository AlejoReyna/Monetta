/// App entry point. The composition lives in `lib/app/`:
/// `bootstrap()` starts the app and `lib/app/composition/` builds, scopes and
/// disposes its dependencies. The exports below keep `package:monetta_app/main.dart`
/// as the stable import for tests and tooling that mount the app or its scopes.
library;

import 'app/bootstrap.dart';

export 'app/composition/app_scopes.dart';
export 'app/monetta_app.dart' show MonettaApp;

Future<void> main() => bootstrap();
