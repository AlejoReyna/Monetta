/// One mounted result surface and one mounted selection through every reflow.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/storefront_layout.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../platform/system_layout_context.dart';
import '../../reco/events.dart';
import '../product/product_screen.dart';
import '../navigation/duo_workspace.dart';
import '../navigation/storefront_pane_scope.dart';

class BrowseDetailScope extends InheritedWidget {
  const BrowseDetailScope({
    required this.selectedId,
    this.enabled = true,
    required this.select,
    required this.register,
    required super.child,
    super.key,
  });
  final bool enabled;
  final String? selectedId;
  final void Function(Product, int) select;
  final void Function(String, BuildContext?, [ValueChanged<bool>?]) register;

  static BrowseDetailScope? maybeOf(BuildContext context) =>
      switch (context.dependOnInheritedWidgetOfExactType<BrowseDetailScope>()) {
        final scope? when scope.enabled => scope,
        _ => null,
      };

  @override
  bool updateShouldNotify(BrowseDetailScope oldWidget) =>
      selectedId != oldWidget.selectedId || enabled != oldWidget.enabled;
}

class BrowseDetailLayout extends StatefulWidget {
  const BrowseDetailLayout({required this.child, super.key});
  final Widget child;

  @override
  State<BrowseDetailLayout> createState() => _BrowseDetailLayoutState();
}

class _BrowseDetailLayoutState extends State<BrowseDetailLayout> {
  final Map<String, BuildContext> _anchors = {};
  final Map<String, ValueChanged<bool>> _pins = {};
  String? _resultAnchorId;
  String? _pinnedId;
  FocusNode? _returnFocus;
  int _restoreGeneration = 0;
  String? _selectedId;
  int _initialVariant = 0;

  /// One key per selection, so the same product page can move to a
  /// two-sided window's right side with its state when the window opens.
  GlobalKey _detailKey = GlobalKey();
  bool _handOverQueued = false;
  double _anchorAlignment = 0;
  Size? _lastSize;
  SystemLayoutContext? _lastGeometry;

  void _register(String id, BuildContext? context, [ValueChanged<bool>? pin]) {
    if (context == null) {
      _anchors.remove(id);
      _pins.remove(id);
    } else {
      _anchors[id] = context;
      if (pin != null) _pins[id] = pin;
    }
  }

  void _remember(String id) {
    final anchor = _anchors[id];
    final box = anchor?.findRenderObject();
    final scrollable = anchor == null ? null : Scrollable.maybeOf(anchor);
    final viewport = scrollable?.context.findRenderObject();
    if (box is RenderBox && viewport is RenderBox && viewport.hasSize) {
      final offset = box.localToGlobal(Offset.zero, ancestor: viewport);
      final horizontal = scrollable?.position.axis == Axis.horizontal;
      final available = horizontal
          ? viewport.size.width - box.size.width
          : viewport.size.height - box.size.height;
      _anchorAlignment = available > 0
          ? ((horizontal ? offset.dx : offset.dy) / available).clamp(0, 1)
          : 0;
    }
    _resultAnchorId = id;
    _pins[_pinnedId]?.call(false);
    _pinnedId = id;
    _pins[id]?.call(true);
  }

  void _rememberVisible() {
    final visible = <({String id, Rect rect})>[];
    for (final entry in _anchors.entries.toList()) {
      final box = entry.value.findRenderObject();
      final viewport =
          Scrollable.maybeOf(entry.value)?.context.findRenderObject();
      if (box is! RenderBox ||
          !box.hasSize ||
          viewport is! RenderBox ||
          !viewport.hasSize) {
        continue;
      }
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.overlaps(viewport.localToGlobal(Offset.zero) & viewport.size)) {
        visible.add((id: entry.key, rect: rect));
      }
    }
    visible.sort((a, b) {
      final vertical = a.rect.top.compareTo(b.rect.top);
      return vertical == 0 ? a.rect.left.compareTo(b.rect.left) : vertical;
    });
    if (visible.isNotEmpty) _remember(visible.first.id);
  }

  void _select(Product product, int variant) {
    if (_selectedId == product.id) return;
    _remember(product.id);
    _returnFocus = FocusManager.instance.primaryFocus;
    _returnFocus?.unfocus();
    StoreScope.of(context).record(EventType.productView, productId: product.id);
    setState(() {
      _selectedId = product.id;
      _initialVariant = variant;
      _detailKey = GlobalKey(debugLabel: 'detail ${product.id}');
    });
    _restoreAnchor(product.id);
  }

  /// A piece chosen while the window had one side moves to the right side
  /// when a second side appears, with its variant, photo and open sections;
  /// the results fill the left side again.
  void _handOver() {
    _handOverQueued = false;
    final id = _selectedId;
    if (!mounted || id == null || !DuoWorkspace.isDual(context)) return;
    final key = _detailKey;
    final variant = _initialVariant;
    final store = StoreScope.of(context);
    final shown = DuoWorkspace.showPane(
      context,
      DuoPanePage(
        kind: DuoPaneKind.product,
        productId: id,
        builder: (_) => StoreScope(
          notifier: store,
          child: ProductScreen(
            key: key,
            productId: id,
            initialVariantIndex: variant,
          ),
        ),
      ),
    );
    if (!shown) return;
    setState(() => _selectedId = null);
    _restoreAnchor(id);
  }

  void _restoreAnchor(String? requested, {bool restoreFocus = false}) {
    final generation = ++_restoreGeneration;
    final id = requested ?? _resultAnchorId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _restoreGeneration) return;
      final anchor = _anchors[id];
      if (anchor != null && anchor.mounted) {
        unawaited(
          Scrollable.ensureVisible(anchor, alignment: _anchorAlignment)
              .then((_) {
            if (!mounted || generation != _restoreGeneration) return;
            _pins[id]?.call(false);
            _pinnedId = null;
            if (restoreFocus && _returnFocus?.context != null) {
              _returnFocus?.requestFocus();
            }
            if (restoreFocus) _returnFocus = null;
          }),
        );
      }
    });
  }

  void _close() {
    final id = _selectedId;
    _pins[id]?.call(true);
    _pinnedId = id;
    setState(() => _selectedId = null);
    _restoreAnchor(id, restoreFocus: true);
  }

  @override
  Widget build(BuildContext context) {
    final dual = DuoWorkspace.isDual(context, listen: true);
    if (dual && _selectedId != null && !_handOverQueued) {
      _handOverQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _handOver());
    }
    return _build(context, dual);
  }

  Widget _build(BuildContext context, bool dual) => PopScope(
        canPop: _selectedId == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selectedId != null) _close();
        },
        child: BrowseDetailScope(
          selectedId: _selectedId,
          // A two-sided window shows the selection on its own right side.
          enabled: !dual,
          select: _select,
          register: _register,
          // A list card and its detail coexist on one route. Neither needs a
          // Hero flight, and neither registers duplicate product Hero tags.
          child: HeroMode(
            enabled: false,
            child: ViewRelativeLayout(
              builder: (context, constraints, origin) {
                final size = constraints.biggest;
                final whole = Offset.zero & size;
                final geometry = SystemLayoutScope.of(context);
                final regions = geometry
                    .usableRegions(whole.shift(origin))
                    .map((rect) => rect.shift(-origin))
                    .where(
                      (rect) =>
                          rect.width >= StorefrontLayout.browseMinimum &&
                          rect.height >= StorefrontLayout.minimumTaskHeight,
                    )
                    .toList()
                  ..sort((a, b) => a.left.compareTo(b.left));
                Rect browse = whole;
                Rect detail = whole;
                var split = false;
                if (_selectedId != null) {
                  final sideRegions = regions
                      .where((r) => r.height >= StorefrontLayout.splitHeight)
                      .toList();
                  if (sideRegions.length >= 2 &&
                      sideRegions.last.width >=
                          StorefrontLayout.detailMinimum) {
                    browse = sideRegions.first;
                    detail = sideRegions.last;
                    split = true;
                  } else if (geometry.divisions.any((r) => r.active)) {
                    // A seated/short pose keeps the entire task together in a
                    // usable region. Product content handles its own split.
                    detail = regions.isEmpty ? whole : regions.last;
                  } else if (StorefrontLayout.canSplit(
                    size,
                    MediaQuery.textScalerOf(context),
                  )) {
                    final width = (size.width * .42).clamp(
                      StorefrontLayout.browseMinimum,
                      size.width -
                          StorefrontLayout.detailMinimum -
                          StorefrontLayout.paneGap,
                    );
                    browse = Rect.fromLTWH(0, 0, width, size.height);
                    detail = Rect.fromLTRB(
                      width + StorefrontLayout.paneGap,
                      0,
                      size.width,
                      size.height,
                    );
                    split = true;
                  }
                }
                if (_lastSize != size || _lastGeometry != geometry) {
                  if (_selectedId == null) _rememberVisible();
                  _lastSize = size;
                  _lastGeometry = geometry;
                  _restoreAnchor(_selectedId);
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fromRect(
                      rect: browse,
                      child: Offstage(
                        offstage: _selectedId != null && !split,
                        child: TickerMode(
                          enabled: _selectedId == null || split,
                          child: _pane(
                            context,
                            browse,
                            size,
                            StorefrontPaneScope(
                              ownsNavigation: _selectedId == null &&
                                  StorefrontPaneScope.ownsNavigationOf(
                                    context,
                                  ),
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_selectedId case final id?)
                      Positioned.fromRect(
                        rect: detail,
                        child: _pane(
                          context,
                          detail,
                          size,
                          BrowseDetailScope(
                            enabled: false,
                            selectedId: null,
                            select: _select,
                            register: _register,
                            child: ProductScreen(
                              key: _detailKey,
                              productId: id,
                              initialVariantIndex: _initialVariant,
                              onClose: _close,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );

  Widget _pane(BuildContext context, Rect rect, Size size, Widget child) {
    final media = MediaQuery.of(context);
    EdgeInsets within(EdgeInsets insets) => EdgeInsets.fromLTRB(
          (insets.left - rect.left).clamp(0, rect.width),
          (insets.top - rect.top).clamp(0, rect.height),
          (insets.right - (size.width - rect.right)).clamp(0, rect.width),
          (insets.bottom - (size.height - rect.bottom)).clamp(0, rect.height),
        );
    return MediaQuery(
      data: media.copyWith(
        size: rect.size,
        padding: within(media.padding),
        viewPadding: within(media.viewPadding),
        viewInsets: within(media.viewInsets),
      ),
      child: child,
    );
  }
}

/// Keep the selected card alive even if a different column count moves its
/// row beyond the cache. Back can then restore by ID rather than raw pixels.
class ProductResultAnchor extends StatefulWidget {
  const ProductResultAnchor({
    required this.productId,
    required this.child,
    super.key,
  });
  final String productId;
  final Widget child;
  @override
  State<ProductResultAnchor> createState() => _ProductResultAnchorState();
}

class _ProductResultAnchorState extends State<ProductResultAnchor>
    with AutomaticKeepAliveClientMixin {
  BrowseDetailScope? _scope;
  bool _pinned = false;

  void _pin(bool value) {
    if (_pinned == value) return;
    _pinned = value;
    updateKeepAlive();
  }

  @override
  bool get wantKeepAlive => _pinned || _scope?.selectedId == widget.productId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = BrowseDetailScope.maybeOf(context);
    _scope?.register(widget.productId, context, _pin);
    updateKeepAlive();
  }

  @override
  void didUpdateWidget(ProductResultAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _scope?.register(oldWidget.productId, null);
      _pinned = false;
      _scope?.register(widget.productId, context, _pin);
      updateKeepAlive();
    }
  }

  @override
  void deactivate() {
    _scope?.register(widget.productId, null);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final selected = _scope?.selectedId == widget.productId ||
        DuoWorkspace.focusedProductOf(context) == widget.productId;
    return Semantics(
      selected: selected,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
