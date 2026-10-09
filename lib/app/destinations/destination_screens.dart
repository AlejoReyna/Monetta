/// Screens that [DestinationNavigator] opens when a destination is not a page
/// by itself: the product lookup and the dead link.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/catalog_repository.dart';
import '../../features/boutique/boutique_tokens.dart';
import '../../features/product/product_screen.dart';
import '../../features/product/product_unavailable.dart';
import '../catalog_store.dart';
import '../composition/app_scopes.dart';
import '../motion.dart';
import '../theme.dart';

/// Looks a product up after a catalog refresh, then replaces itself with the
/// product page.
///
/// Three endings are told apart:
/// * found: this route is replaced by the page, so it is never left stacked;
/// * not found after a refresh that ran (`updated` or `upToDate`): the piece
///   is gone, shown with [ProductUnavailable];
/// * the refresh could not run or threw: the lookup is inconclusive, so the
///   shopper can retry instead of being told the piece is gone.
class ProductLookupScreen extends StatefulWidget {
  const ProductLookupScreen({
    required this.store,
    required this.refresh,
    required this.productId,
    this.initialVariantIndex = 0,
    super.key,
  });

  final CatalogStore store;
  final Future<CatalogSyncResult> Function() refresh;
  final String productId;
  final int initialVariantIndex;

  @override
  State<ProductLookupScreen> createState() => _ProductLookupScreenState();
}

enum _LookupPhase { searching, gone, couldNotCheck }

class _ProductLookupScreenState extends State<ProductLookupScreen> {
  _LookupPhase _phase = _LookupPhase.searching;

  /// Bumped on every lookup so a stale answer is dropped.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_lookUp());
  }

  bool get _inCache =>
      widget.store.products.any((p) => p.id == widget.productId);

  Future<void> _lookUp() async {
    final attempt = ++_attempt;
    CatalogSyncOutcome? outcome;
    try {
      outcome = (await widget.refresh()).outcome;
    } on Object {
      outcome = null;
    }
    if (!mounted || attempt != _attempt) return;
    if (_inCache) {
      unawaited(
        Navigator.of(context).pushReplacement<void, void>(
          monettaFadeRoute<void>(
            StoreScope(
              notifier: widget.store,
              child: ProductScreen(
                productId: widget.productId,
                initialVariantIndex: widget.initialVariantIndex,
              ),
            ),
          ),
        ),
      );
      return;
    }
    final ran = outcome == CatalogSyncOutcome.updated ||
        outcome == CatalogSyncOutcome.upToDate;
    setState(() {
      _phase = ran ? _LookupPhase.gone : _LookupPhase.couldNotCheck;
    });
  }

  void _retry() {
    setState(() => _phase = _LookupPhase.searching);
    unawaited(_lookUp());
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _LookupPhase.searching:
        return const _SearchingView();
      case _LookupPhase.gone:
        return const ProductUnavailable();
      case _LookupPhase.couldNotCheck:
        return _NoticeScaffold(
          icon: Icons.wifi_off_outlined,
          title: 'No se pudo comprobar este artículo',
          body: 'Revisa tu conexión e inténtalo de nuevo.',
          actions: [
            BoutiqueButton(label: 'Reintentar', onPressed: _retry),
            BoutiqueButton(
              label: 'Volver',
              filled: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
    }
  }
}

/// Shown for a link that no longer leads to any piece of Monetta.
class UnavailableLinkScreen extends StatelessWidget {
  const UnavailableLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _NoticeScaffold(
      icon: Icons.link_off_outlined,
      title: 'Enlace no disponible',
      body: 'Este enlace ya no lleva a ninguna pieza de Monetta.',
      actions: [
        BoutiqueButton(
          label: 'Ir al inicio',
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }
}

class _SearchingView extends StatelessWidget {
  const _SearchingView();

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return _DestinationScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: BoutiqueSpace.lg),
          Text(
            'Buscando el artículo…',
            textAlign: TextAlign.center,
            style: boutiqueText(size: 13, color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _NoticeScaffold extends StatelessWidget {
  const _NoticeScaffold({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return _DestinationScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.gold, width: 1),
              ),
              child: Icon(icon, size: 28, color: palette.goldText),
            ),
          ),
          const SizedBox(height: BoutiqueSpace.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: boutiqueTitle(size: 16, color: palette.ink),
          ),
          const SizedBox(height: BoutiqueSpace.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: boutiqueText(size: 13, color: palette.inkMuted),
          ),
          const SizedBox(height: BoutiqueSpace.xl),
          for (var i = 0; i < actions.length; i += 1) ...[
            if (i > 0) const SizedBox(height: BoutiqueSpace.md),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// The frame shared by the screens above: the boutique app bar with a back
/// button, and [child] centred on the canvas.
class _DestinationScaffold extends StatelessWidget {
  const _DestinationScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.canvas,
        foregroundColor: palette.ink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const MonettaWordmark.appBar(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: palette.hairline),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              vertical: BoutiqueSpace.xxl,
              horizontal: BoutiqueSpace.gutter,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
