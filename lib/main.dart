/// App entry point.
///
/// Phase 1 demo build: the catalog comes from the bundled snapshot asset rather
/// than the Storefront API, because there is no access token yet. Everything
/// else — normalization, profiling, ranking, explanations — is the real code
/// from `data/normalize` and `reco`, running on the real 271-product catalog.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'app/catalog_store.dart';
import 'app/external_catalog_config.dart';
import 'app/external_catalog_controller.dart';
import 'app/theme.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const MonettaApp());
}

/// Exposes the store to the widget tree.
///
/// Deliberately plain Flutter rather than Riverpod for now: the store is a
/// single object and this keeps the demo free of state-management wiring that
/// will be rewritten anyway when `data/local` lands.
class StoreScope extends InheritedNotifier<CatalogStore> {
  const StoreScope({
    required CatalogStore super.notifier,
    required super.child,
    super.key,
  });

  static CatalogStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope?.notifier != null, 'StoreScope is missing from the tree');
    return scope!.notifier!;
  }
}

/// Exposes the external-catalog prototype to the widget tree. Present in
/// every build, but inert — `ExternalCatalogController.items` is always
/// empty — unless the app was built with
/// `--dart-define=ENABLE_EXTERNAL_CATALOG=true` and a base URL. See
/// `app/external_catalog_config.dart`.
class ExternalCatalogScope
    extends InheritedNotifier<ExternalCatalogController> {
  const ExternalCatalogScope({
    required ExternalCatalogController super.notifier,
    required super.child,
    super.key,
  });

  static ExternalCatalogController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ExternalCatalogScope>();
    assert(
      scope?.notifier != null,
      'ExternalCatalogScope is missing from the tree',
    );
    return scope!.notifier!;
  }
}

class MonettaApp extends StatefulWidget {
  const MonettaApp({super.key});

  @override
  State<MonettaApp> createState() => _MonettaAppState();
}

class _MonettaAppState extends State<MonettaApp> {
  final CatalogStore _store = CatalogStore();
  final ExternalCatalogController _externalCatalog = ExternalCatalogController(
    config: ExternalCatalogConfig.fromEnvironment(),
  );
  late final Future<void> _loading = _store.loadFromAsset();

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: cache-first load, then a best-effort background
    // refresh. A failed or slow external fetch must never block or affect
    // the Monetta home screen — see ExternalCatalogRepository's contract.
    unawaited(_externalCatalog.loadAndRefresh());
  }

  @override
  void dispose() {
    _store.dispose();
    _externalCatalog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monetta',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: StoreScope(
        notifier: _store,
        child: ExternalCatalogScope(
          notifier: _externalCatalog,
          child: FutureBuilder<void>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorScreen(error: '${snapshot.error}');
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const _SplashScreen();
              }
              return const HomeScreen();
            },
          ),
        ),
      ),
    );
  }
}

/// Wordmark centred over a thin gold rule instead of a spinner. A Material
/// spinner is the loudest possible "this is an app" signal, and this is the
/// first frame the shopper ever sees.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MonettaWordmark(height: 34),
            const SizedBox(height: 18),
            Text('Originales importados'.toUpperCase(), style: eyebrow()),
            const SizedBox(height: 36),
            const SizedBox(
              width: 64,
              height: 1,
              child: ColoredBox(color: kGold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No se pudo cargar el catálogo.', style: display(20)),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: sans(size: 12, color: kInkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
