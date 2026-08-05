/// App entry point.
///
/// Phase 1 demo build: the catalog comes from the bundled snapshot asset rather
/// than the Storefront API, because there is no access token yet. Everything
/// else — normalization, profiling, ranking, explanations — is the real code
/// from `data/normalize` and `reco`, running on the real 271-product catalog.
library;

import 'package:flutter/material.dart';

import 'app/catalog_store.dart';
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

class MonettaApp extends StatefulWidget {
  const MonettaApp({super.key});

  @override
  State<MonettaApp> createState() => _MonettaAppState();
}

class _MonettaAppState extends State<MonettaApp> {
  final CatalogStore _store = CatalogStore();
  late final Future<void> _loading = _store.loadFromAsset();

  @override
  void dispose() {
    _store.dispose();
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
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MONETTA',
              style: TextStyle(
                fontSize: 26,
                letterSpacing: 8,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: kGold),
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
        child: Center(child: Text('No se pudo cargar el catálogo.\n\n$error')),
      ),
    );
  }
}
