import 'dart:async';

import 'package:drift/drift.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests intentionally open independent in-memory AppDatabase instances in
  // parallel. They never share a QueryExecutor, so Drift's production warning
  // would be noise rather than evidence of a corruption risk.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
