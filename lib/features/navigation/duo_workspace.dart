/// Two fixed sides on a foldable's inner display.
///
/// The app's navigator stays on the left of the crease: Inicio, categorías,
/// colecciones, búsqueda, marcas and favoritos. The right side is a companion
/// pane with its own history. It starts with the bag and shows the preview
/// card, the product, the account or the catalog filters without covering the
/// browsing side. Checkout opens in a third layer that spans both sides. One
/// rail on the system bar edge serves both sides.
///
/// The workspace splits only when the system reports a vertical division and
/// both sides fit ([DuoSides.resolve]); every other window keeps the ordinary
/// single navigator, and the right side is not even built until a window has
/// had two sides. When the window loses its second side while the right side
/// or checkout shows a page, that page is drawn over the browsing side with
/// its state intact until it is closed, and it returns to the right when the
/// window opens again.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../../app/motion.dart';
import '../../app/storefront_layout.dart';
import '../../app/theme.dart';
import '../../main.dart' show AccountScope, StoreScope;
import '../../platform/system_layout_context.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/categories_screen.dart';
import 'monetta_bottom_navigation.dart';
import 'storefront_pane_scope.dart';

/// Where a page lives inside the workspace.
enum DuoRegion { browse, pane, task }

/// What the right side shows above the bag.
enum DuoPaneKind { bag, preview, product, account, filters }

/// A page for the right side. [kind], [productId] and [owner] identify it, so
/// asking again for the page already on top does nothing.
@immutable
class DuoPanePage {
  const DuoPanePage({
    required this.kind,
    required this.builder,
    this.productId,
    this.owner,
  });

  final DuoPaneKind kind;
  final WidgetBuilder builder;
  final String? productId;

  /// The browsing page that opened it, such as the screen whose filters it
  /// edits. That page closes it when it goes away
  /// ([DuoWorkspaceState.dismissOwnedBy]).
  final Object? owner;

  bool sameAs(DuoPanePage other) =>
      kind == other.kind &&
      productId == other.productId &&
      owner == other.owner;
}

/// The two sides of an inner display, split at the system's vertical
/// division, and the rail on the system bar edge.
@immutable
class DuoSides {
  const DuoSides({
    required this.left,
    required this.gutter,
    required this.right,
    required this.rail,
  });

  final Rect left;
  final Rect gutter;
  final Rect right;
  final Rect rail;

  /// Both sides and the gutter: the room checkout gets.
  Rect get content =>
      Rect.fromLTRB(left.left, left.top, right.right, right.bottom);

  /// Null unless the system reports a vertical division (folded or flat) and
  /// each side keeps the app's minimum pane width with ordinary text. The
  /// keyboard never collapses the sides: only the safe area counts.
  static DuoSides? resolve({
    required Size size,
    required EdgeInsets padding,
    required SystemLayoutContext geometry,
    required TextScaler textScaler,
  }) {
    if (!geometry.supported || StorefrontLayout.enlargedText(textScaler)) {
      return null;
    }
    Rect? crease;
    for (final division in geometry.divisions) {
      final bounds = division.bounds;
      if (bounds.isEmpty ||
          bounds.height < size.height * .5 ||
          bounds.width > size.width * .2 ||
          bounds.left <= 0 ||
          bounds.right >= size.width) {
        continue;
      }
      crease = bounds;
      break;
    }
    if (crease == null) return null;
    final railLeft = geometry.barEdge == SystemBarEdge.left;
    final reserved = railLeft ? padding.left : padding.right;
    // A reported inset that already holds the system bar is used once.
    final railWidth = reserved >= 48 ? reserved : StorefrontLayout.railWidth;
    final rail = railLeft
        ? Rect.fromLTWH(
            reserved >= 48 ? 0 : padding.left,
            0,
            railWidth,
            size.height,
          )
        : Rect.fromLTWH(
            size.width - (reserved >= 48 ? 0 : padding.right) - railWidth,
            0,
            railWidth,
            size.height,
          );
    final start = railLeft ? rail.right : padding.left;
    final end = railLeft ? size.width - padding.right : rail.left;
    final left =
        Rect.fromLTRB(start, 0, math.max(start, crease.left), size.height);
    final right =
        Rect.fromLTRB(math.min(end, crease.right), 0, end, size.height);
    if (left.width < StorefrontLayout.browseMinimum ||
        right.width < StorefrontLayout.detailMinimum ||
        size.height - padding.vertical < StorefrontLayout.splitHeight) {
      return null;
    }
    return DuoSides(
      left: left,
      gutter: Rect.fromLTRB(crease.left, 0, crease.right, size.height),
      right: right,
      rail: rail,
    );
  }
}

/// Follows the routes of one navigator. The app registers one in
/// `MaterialApp.navigatorObservers` so the workspace can read the browsing
/// side's top page; the right side and checkout use their own.
class DuoRouteObserver extends NavigatorObserver with ChangeNotifier {
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  List<Route<dynamic>> get routes => List.unmodifiable(_routes);
  Route<dynamic>? get top => _routes.isEmpty ? null : _routes.last;
  int get depth => _routes.length;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    notifyListeners();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    notifyListeners();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute != null) {
      if (index >= 0) {
        _routes[index] = newRoute;
      } else {
        _routes.add(newRoute);
      }
    } else if (index >= 0) {
      _routes.removeAt(index);
    }
    notifyListeners();
  }
}

class DuoWorkspace extends StatefulWidget {
  const DuoWorkspace({
    required this.navigatorKey,
    required this.routes,
    required this.paneRoot,
    required this.child,
    super.key,
  });

  /// Names of browsing pages that move to the right side when the window
  /// opens, and of the directory the rail opens.
  static const String bagRoute = '/bag';
  static const String accountRoute = '/account';
  static const String productRoute = '/product';
  static const String categoriesRoute = '/categories';

  /// The app's navigator: the browsing side.
  final GlobalKey<NavigatorState> navigatorKey;

  /// Registered on [navigatorKey]'s navigator.
  final DuoRouteObserver routes;

  /// The right side's first page: the bag.
  final WidgetBuilder paneRoot;

  /// The app's navigator widget.
  final Widget child;

  @override
  State<DuoWorkspace> createState() => DuoWorkspaceState();

  static _DuoScope? _scope(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_DuoScope>();

  /// The workspace around [context], to keep for later calls (from `dispose`,
  /// for example). Null outside a workspace.
  static DuoWorkspaceState? stateOf(BuildContext context) =>
      _scope(context)?.state;

  static DuoRegion regionOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_DuoRegionScope>()?.region ??
      DuoRegion.browse;

  /// Whether [context] belongs to a workspace that shows two sides. With
  /// [listen], the calling build runs again when that changes.
  static bool isDual(BuildContext context, {bool listen = false}) =>
      (listen
              ? context.dependOnInheritedWidgetOfExactType<_DuoScope>()
              : _scope(context))
          ?.dual ??
      false;

  /// The piece the right side shows, for the browsing side to mark it. Null
  /// on the right side itself and with a single side.
  static String? focusedProductOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DuoScope>();
    if (scope == null || !scope.dual) return null;
    if (regionOf(context) != DuoRegion.browse) return null;
    return scope.focusedProductId;
  }

  /// Shows [page] on the right side and returns true, or returns false when
  /// there are not two sides and the caller presents it the ordinary way.
  ///
  /// A page asked for from the browsing side replaces whatever the right side
  /// showed above the bag. One asked for from the right side opens above the
  /// current page (a related piece above its product), and a product replaces
  /// the preview it was opened from.
  static bool showPane(BuildContext context, DuoPanePage page) {
    final scope = _scope(context);
    if (scope == null || !scope.dual) return false;
    scope.state._show(page, regionOf(context));
    return true;
  }

  /// Returns the right side to the bag. False with a single side.
  static bool showBag(BuildContext context) {
    final scope = _scope(context);
    if (scope == null || !scope.dual) return false;
    scope.state._showBag();
    return true;
  }

  /// Confirms an add on the right side, where the bag already lives, instead
  /// of the mini-cart sheet. False with a single side.
  static bool confirmAdded(BuildContext context) {
    final scope = _scope(context);
    if (scope == null || !scope.dual) return false;
    scope.state._confirmAdded();
    return true;
  }

  /// The navigator for a browsing page, or for a page that falls back to an
  /// ordinary push. With two sides it is always the browsing side. With one
  /// side it is the caller's own, except that a right-side page or checkout
  /// drawn over the browsing side closes first and the page opens beneath it.
  static NavigatorState navigatorFor(BuildContext context) {
    final scope = _scope(context);
    final region = regionOf(context);
    final browse = scope?.state.widget.navigatorKey.currentState;
    if (scope == null || browse == null || region == DuoRegion.browse) {
      return Navigator.of(context);
    }
    if (!scope.dual) {
      scope.state._closeLayers();
    } else if (region == DuoRegion.task) {
      scope.state._closeTask();
    }
    return browse;
  }

  /// Checkout spans both sides when there are two.
  static NavigatorState taskNavigatorFor(BuildContext context) {
    final scope = _scope(context);
    if (scope != null && scope.dual) {
      final task = scope.state._task.currentState;
      if (task != null) return task;
    }
    return Navigator.of(context);
  }

  /// Closes checkout and the right side's pages, and returns the browsing
  /// side to its first page.
  static void returnToStart(BuildContext context) {
    final scope = _scope(context);
    if (scope == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    scope.state._returnToStart();
  }
}

class _DuoScope extends InheritedWidget {
  const _DuoScope({
    required this.state,
    required this.dual,
    required this.focusedProductId,
    required super.child,
  });

  final DuoWorkspaceState state;
  final bool dual;
  final String? focusedProductId;

  @override
  bool updateShouldNotify(_DuoScope oldWidget) =>
      dual != oldWidget.dual || focusedProductId != oldWidget.focusedProductId;
}

class _DuoRegionScope extends InheritedWidget {
  const _DuoRegionScope({required this.region, required super.child});

  final DuoRegion region;

  @override
  bool updateShouldNotify(_DuoRegionScope oldWidget) =>
      region != oldWidget.region;
}

class _RailSource {
  const _RailSource(this.owner, this.navigation);

  final Object owner;
  final MonettaBottomNavigation navigation;
}

class DuoWorkspaceState extends State<DuoWorkspace> {
  final _pane = GlobalKey<NavigatorState>(debugLabel: 'duo-pane');
  final _task = GlobalKey<NavigatorState>(debugLabel: 'duo-task');
  final _paneMessages =
      GlobalKey<ScaffoldMessengerState>(debugLabel: 'duo-pane-messages');
  final _taskMessages =
      GlobalKey<ScaffoldMessengerState>(debugLabel: 'duo-task-messages');
  final _paneRoutes = DuoRouteObserver();
  final _taskRoutes = DuoRouteObserver();

  /// The right side and checkout layer exist once a window had two sides.
  bool _sidesUsed = false;
  bool? _wasDual;
  DuoSides? _sides;
  bool _rebuildQueued = false;
  _RailSource? _rail;
  DuoBagDrag? _drag;
  Offset _dragPoint = Offset.zero;
  bool _dragOverBag = false;

  /// Pages that need the whole window while they show (the first-visit
  /// welcome).
  final Set<Object> _oneSideHolds = <Object>{};

  @override
  void initState() {
    super.initState();
    widget.routes.addListener(_rebuild);
    _paneRoutes.addListener(_rebuild);
    _taskRoutes.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(DuoWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routes != widget.routes) {
      oldWidget.routes.removeListener(_rebuild);
      widget.routes.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.routes.removeListener(_rebuild);
    _paneRoutes.dispose();
    _taskRoutes.dispose();
    super.dispose();
  }

  /// Route changes can arrive while a frame builds; they are applied after it.
  void _rebuild() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_rebuildQueued) return;
      _rebuildQueued = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _rebuildQueued = false;
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  void _afterFrame(VoidCallback action) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) action();
      });
    } else {
      action();
    }
  }

  static DuoPanePage? _pageOf(Route<dynamic>? route) {
    final arguments = route?.settings.arguments;
    return arguments is DuoPanePage ? arguments : null;
  }

  bool get _paneOpen => _paneRoutes.depth > 1;
  bool get _taskOpen => _taskRoutes.depth > 1;

  /// The right side's current page, ignoring a sheet or dialog above it.
  DuoPanePage? get _panePage {
    final routes = _paneRoutes.routes;
    for (var i = routes.length - 1; i >= 0; i--) {
      if (routes[i] is PageRoute) return _pageOf(routes[i]);
    }
    return null;
  }

  String? get _focusedProductId {
    final page = _panePage;
    return switch (page?.kind) {
      DuoPaneKind.preview || DuoPaneKind.product => page!.productId,
      _ => null,
    };
  }

  /// The rail marks what the right side shows: the bag (checkout belongs to
  /// it) or the account and the pages opened from it.
  MonettaBottomDestination? get _paneDestination {
    if (_taskOpen || !_paneOpen) return MonettaBottomDestination.bag;
    for (final route in _paneRoutes.routes) {
      if (_pageOf(route)?.kind == DuoPaneKind.account) {
        return MonettaBottomDestination.account;
      }
    }
    return null;
  }

  Route<void> _paneRoute(DuoPanePage page) => PageRouteBuilder<void>(
        settings: RouteSettings(name: 'duo-${page.kind.name}', arguments: page),
        transitionDuration: kSnap,
        reverseTransitionDuration: kSnap,
        pageBuilder: (context, _, __) => page.builder(context),
        transitionsBuilder: (context, animation, _, child) =>
            reduceMotion(context)
                ? child
                : FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: kMotionCurve,
                    ),
                    child: child,
                  ),
      );

  void _show(DuoPanePage page, DuoRegion from) {
    final pane = _pane.currentState;
    if (pane == null) return;
    if (page.kind == DuoPaneKind.bag) {
      _showBag();
      return;
    }
    final current = _panePage;
    final onTop = current != null && _paneRoutes.top is PageRoute;
    if (onTop && current.sameAs(page)) return;
    final next = _paneRoute(page);
    if (from == DuoRegion.pane) {
      final fromPreview = current?.kind == DuoPaneKind.preview &&
          page.kind == DuoPaneKind.product &&
          current?.productId == page.productId;
      if (fromPreview && onTop) {
        unawaited(pane.pushReplacement(next));
      } else {
        unawaited(pane.push(next));
      }
      return;
    }
    if (_paneOpen) {
      unawaited(pane.pushAndRemoveUntil(next, (route) => route.isFirst));
    } else {
      unawaited(pane.push(next));
    }
  }

  void _showBag() => _pane.currentState?.popUntil((route) => route.isFirst);

  void _closeTask() => _task.currentState?.popUntil((route) => route.isFirst);

  /// Everything drawn over the browsing side with a single side.
  void _closeLayers() {
    _closeTask();
    _showBag();
  }

  void _returnToStart() {
    _closeLayers();
    widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _confirmAdded() {
    final messenger = _paneMessages.currentState;
    if (messenger == null) return;
    final atBag = !_paneOpen;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('duo-added-to-bag'),
          content: const Text('Agregado a tu bolsa'),
          persist: false,
          action: atBag
              ? null
              : SnackBarAction(label: 'VER BOLSA', onPressed: _showBag),
        ),
      );
  }

  /// While [holder] holds, the window keeps one side even if it could show
  /// two. Safe to call from `build` and `dispose`.
  void holdOneSide(Object holder, {required bool hold}) {
    final changed =
        hold ? _oneSideHolds.add(holder) : _oneSideHolds.remove(holder);
    if (changed) _rebuild();
  }

  /// Closes the right side's pages opened by [owner], such as the filters of
  /// a browsing page that is going away. Safe to call from `dispose`.
  void dismissOwnedBy(Object owner) {
    _afterFrame(() {
      final pane = _pane.currentState;
      if (pane == null) return;
      for (final route in _paneRoutes.routes.reversed) {
        if (_pageOf(route)?.owner != owner) continue;
        if (route.isCurrent) {
          pane.pop();
        } else if (route.isActive) {
          pane.removeRoute(route);
        }
      }
    });
  }

  // Rail -------------------------------------------------------------------

  void _registerRail(Object owner, MonettaBottomNavigation navigation) {
    final previous = _rail;
    _rail = _RailSource(owner, navigation);
    if (previous?.owner != owner ||
        previous?.navigation.current != navigation.current) {
      _rebuild();
    }
  }

  void _unregisterRail(Object owner) {
    if (_rail?.owner != owner) return;
    _rail = null;
    _rebuild();
  }

  /// The browsing page's own handler decides, as its own bar would; the
  /// workspace only closes checkout first. Without such a page the rail
  /// falls back to the shared destinations.
  void _select(MonettaBottomDestination destination) {
    _closeTask();
    final source = _rail?.navigation;
    if (source != null) {
      source.onSelected(destination);
      return;
    }
    final browse = widget.navigatorKey.currentState;
    final context = widget.navigatorKey.currentContext;
    if (browse == null || context == null) return;
    switch (destination) {
      case MonettaBottomDestination.home:
        browse.popUntil((route) => route.isFirst);
      case MonettaBottomDestination.catalog:
        if (widget.routes.top?.settings.name != DuoWorkspace.categoriesRoute) {
          unawaited(openCategories(context));
        }
      case MonettaBottomDestination.bag:
        _showBag();
      case MonettaBottomDestination.account:
        final account = AccountScope.maybeOf(context);
        if (account != null) {
          unawaited(openAccount(context, controller: account));
        }
    }
  }

  // Drag to the bag ---------------------------------------------------------

  Offset _toLocal(Offset global) {
    final box = context.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : global;
  }

  bool _overBag(Offset point) => _sides?.right.contains(point) ?? false;

  void _beginDrag(DuoBagDrag drag, Offset global) {
    if (_sides == null) return;
    final point = _toLocal(global);
    setState(() {
      _drag = drag;
      _dragPoint = point;
      _dragOverBag = _overBag(point);
    });
  }

  void _moveDrag(Offset global) {
    if (_drag == null) return;
    final point = _toLocal(global);
    final over = _overBag(point);
    if (over && !_dragOverBag) unawaited(HapticFeedback.selectionClick());
    setState(() {
      _dragPoint = point;
      _dragOverBag = over;
    });
  }

  Future<void> _endDrag(Offset global) async {
    final drag = _drag;
    if (drag == null) return;
    final over = _overBag(_toLocal(global));
    setState(() => _drag = null);
    if (over) await _drop(drag);
  }

  void _cancelDrag() {
    if (_drag == null) return;
    _drag = null;
    _rebuild();
  }

  Future<void> _drop(DuoBagDrag drag) async {
    final context = _pane.currentContext;
    if (context == null || _sides == null) return;
    await drag.onDrop(context);
  }

  // Layout ------------------------------------------------------------------

  /// One side's view of the window: its own size, and the insets and display
  /// features that fall inside it, in its own coordinates.
  MediaQueryData _sideMedia(MediaQueryData media, Rect rect) {
    final size = media.size;
    EdgeInsets within(EdgeInsets insets) => EdgeInsets.fromLTRB(
          (insets.left - rect.left).clamp(0.0, rect.width),
          (insets.top - rect.top).clamp(0.0, rect.height),
          (insets.right - (size.width - rect.right)).clamp(0.0, rect.width),
          (insets.bottom - (size.height - rect.bottom)).clamp(0.0, rect.height),
        );
    return media.copyWith(
      size: rect.size,
      padding: within(media.padding),
      viewPadding: within(media.viewPadding),
      viewInsets: within(media.viewInsets),
      displayFeatures: [
        for (final feature in media.displayFeatures)
          if (feature.bounds.overlaps(rect))
            DisplayFeature(
              bounds: feature.bounds.intersect(rect).shift(-rect.topLeft),
              type: feature.type,
              state: feature.state,
            ),
      ],
    );
  }

  Widget _side({
    required MediaQueryData media,
    required Rect rect,
    required DuoRegion region,
    required bool ownsNavigation,
    required bool visible,
    required bool covered,
    required Widget child,
  }) =>
      Positioned.fromRect(
        rect: rect,
        child: Offstage(
          offstage: !visible,
          child: TickerMode(
            enabled: visible && !covered,
            child: ExcludeSemantics(
              excluding: covered,
              child: MediaQuery(
                data: _sideMedia(media, rect),
                child: StorefrontPaneScope(
                  ownsNavigation: ownsNavigation,
                  child: _DuoRegionScope(region: region, child: child),
                ),
              ),
            ),
          ),
        ),
      );

  /// A layer with its own history, snack bars and no shared hero controller.
  Widget _layer({
    required GlobalKey<NavigatorState> key,
    required GlobalKey<ScaffoldMessengerState> messages,
    required DuoRouteObserver observer,
    required WidgetBuilder root,
    required String name,
  }) =>
      HeroControllerScope.none(
        child: ScaffoldMessenger(
          key: messages,
          child: Navigator(
            key: key,
            observers: [observer],
            onGenerateInitialRoutes: (_, __) => [
              PageRouteBuilder<void>(
                settings: RouteSettings(name: name),
                pageBuilder: (context, _, __) => root(context),
              ),
            ],
          ),
        ),
      );

  /// A bag, account or product page opened on the browsing side while the
  /// window had one side moves to the right side when the second appears.
  /// A product page carries its own key, so it keeps its state on the way.
  void _adopt() {
    if (!mounted || _sides == null) return;
    final browse = widget.navigatorKey.currentState;
    final top = widget.routes.top;
    if (browse == null || top == null || !top.isCurrent) return;
    final page = top.settings.arguments;
    switch (top.settings.name) {
      case DuoWorkspace.bagRoute:
        browse.removeRoute(top);
      case DuoWorkspace.accountRoute || DuoWorkspace.productRoute:
        if (page is! DuoPanePage) return;
        // Removed without an exit, so the page's key is free this frame.
        browse.removeRoute(top);
        _show(page, DuoRegion.browse);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sides = _oneSideHolds.isNotEmpty
        ? null
        : DuoSides.resolve(
            size: media.size,
            padding: media.padding,
            geometry: SystemLayoutScope.of(context),
            textScaler: media.textScaler,
          );
    _sides = sides;
    final dual = sides != null;
    if (dual) _sidesUsed = true;
    if (_wasDual != dual) {
      final opened = dual && _wasDual == false;
      _wasDual = dual;
      if (opened) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _adopt());
      }
      if (!dual && _drag != null) _drag = null;
    }
    final whole = Offset.zero & media.size;
    final paneOpen = _paneOpen;
    final taskOpen = _taskOpen;
    final paneVisible = _sidesUsed && (dual || paneOpen);
    final browseCovered = taskOpen || (!dual && paneOpen);
    final palette = context.boutique;
    final drag = _drag;

    return _DuoScope(
      state: this,
      dual: dual,
      focusedProductId: dual ? _focusedProductId : null,
      // The rail's tooltips and the dragged card float above both sides.
      child: Overlay.wrap(
        child: ColoredBox(
          color: palette.canvas,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _side(
                media: media,
                rect: sides?.left ?? whole,
                region: DuoRegion.browse,
                ownsNavigation: !dual,
                visible: true,
                covered: browseCovered,
                child: widget.child,
              ),
              Positioned.fromRect(
                rect: sides?.gutter ?? Rect.zero,
                child: dual
                    ? Center(
                        child: SizedBox(
                          key: const Key('duo-crease'),
                          width: .5,
                          child: ColoredBox(color: palette.hairline),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              _side(
                media: media,
                rect: sides?.right ?? whole,
                region: DuoRegion.pane,
                ownsNavigation: !dual,
                visible: paneVisible,
                covered: taskOpen,
                child: _sidesUsed
                    ? _layer(
                        key: _pane,
                        messages: _paneMessages,
                        observer: _paneRoutes,
                        root: widget.paneRoot,
                        name: 'duo-bag',
                      )
                    : const SizedBox.shrink(),
              ),
              _side(
                media: media,
                rect: sides?.content ?? whole,
                region: DuoRegion.task,
                ownsNavigation: !dual,
                visible: _sidesUsed && taskOpen,
                covered: false,
                child: _sidesUsed
                    ? _layer(
                        key: _task,
                        messages: _taskMessages,
                        observer: _taskRoutes,
                        root: (_) => const SizedBox.shrink(),
                        name: 'duo-task',
                      )
                    : const SizedBox.shrink(),
              ),
              Positioned.fromRect(
                rect: sides?.rail ?? Rect.zero,
                child: sides != null
                    ? MediaQuery(
                        data: _sideMedia(media, sides.rail),
                        child: _DuoRail(
                          current: _rail != null
                              ? _rail!.navigation.current
                              : widget.routes.depth <= 1
                                  ? MonettaBottomDestination.home
                                  : null,
                          secondary: _paneDestination,
                          onSelected: _select,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (sides != null && drag != null) ...[
                Positioned.fromRect(
                  rect: sides.right.deflate(BoutiqueSpace.md),
                  child: IgnorePointer(
                    // Above every page: the text needs its own material.
                    child: Material(
                      type: MaterialType.transparency,
                      child: _BagDropZone(active: _dragOverBag),
                    ),
                  ),
                ),
                Positioned(
                  left: _dragPoint.dx - 48,
                  top: _dragPoint.dy - 132,
                  child: IgnorePointer(child: drag.feedback),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the browsing side's visible page drive the rail: its selection and
/// its handlers are the ones its own bar would use.
class DuoRailRegistration extends StatefulWidget {
  const DuoRailRegistration({
    required this.navigation,
    required this.child,
    super.key,
  });

  final MonettaBottomNavigation navigation;
  final Widget child;

  @override
  State<DuoRailRegistration> createState() => _DuoRailRegistrationState();
}

class _DuoRailRegistrationState extends State<DuoRailRegistration> {
  DuoWorkspaceState? _workspace;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DuoScope>();
    final workspace = _workspace = scope?.state;
    if (workspace != null) {
      final active = scope!.dual &&
          DuoWorkspace.regionOf(context) == DuoRegion.browse &&
          (ModalRoute.isCurrentOf(context) ?? true);
      // The rail belongs to the workspace: it changes after this frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (active) {
          workspace._registerRail(this, widget.navigation);
        } else {
          workspace._unregisterRail(this);
        }
      });
    }
    return widget.child;
  }

  @override
  void dispose() {
    _workspace?._unregisterRail(this);
    super.dispose();
  }
}

class _DuoRail extends StatelessWidget {
  const _DuoRail({
    required this.current,
    required this.secondary,
    required this.onSelected,
  });

  final MonettaBottomDestination? current;
  final MonettaBottomDestination? secondary;
  final ValueChanged<MonettaBottomDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final bagCount = StoreScope.maybeOf(context)?.bagQuantity ?? 0;
    return StorefrontPaneScope(
      ownsNavigation: true,
      child: _RailFrame(
        child: ColoredBox(
          key: const Key('duo-rail'),
          color: context.monettaColors.navigationSurface,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: SafeArea(
                  left: false,
                  right: false,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: MonettaBottomNavigation(
                      current: current,
                      secondary: secondary,
                      bagCount: bagCount,
                      onSelected: onSelected,
                      vertical: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Moves the rail's controls together when an active region (the system's
/// status indicators, a camera) intersects it. No margins are invented.
class _RailFrame extends StatelessWidget {
  const _RailFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ViewRelativeLayout(
        builder: (context, box, origin) {
          final whole = origin & box.biggest;
          final regions = SystemLayoutScope.of(context).usableRegions(whole);
          final region = regions.isEmpty ? whole : regions.first;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              region.left - whole.left,
              region.top - whole.top,
              whole.right - region.right,
              whole.bottom - region.bottom,
            ),
            child: child,
          );
        },
      );
}

// Drag to the bag -----------------------------------------------------------

/// What a catalog card hands the workspace when it is dragged to the bag.
@immutable
class DuoBagDrag {
  const DuoBagDrag({required this.feedback, required this.onDrop});

  /// Follows the finger while dragging.
  final Widget feedback;

  /// Adds the piece. Receives a context on the right side.
  final Future<void> Function(BuildContext paneContext) onDrop;
}

/// With two sides, a long press on a browsing card lifts it; dropping it on
/// the right side adds it to the bag. Assistive technologies get the same
/// action by name. With one side the card behaves as before.
class DuoBagDragSource extends StatefulWidget {
  const DuoBagDragSource({required this.drag, required this.child, super.key});

  final DuoBagDrag drag;
  final Widget child;

  @override
  State<DuoBagDragSource> createState() => _DuoBagDragSourceState();
}

class _DuoBagDragSourceState extends State<DuoBagDragSource> {
  DuoWorkspaceState? _workspace;
  bool _dragging = false;

  void _cancel() {
    if (!_dragging) return;
    _dragging = false;
    _workspace?._cancelDrag();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DuoScope>();
    final workspace = _workspace = scope?.state;
    final active = workspace != null &&
        scope!.dual &&
        DuoWorkspace.regionOf(context) == DuoRegion.browse;
    // One structure in every mode, so the card keeps its state on a fold.
    return Semantics(
      customSemanticsActions: active
          ? {
              const CustomSemanticsAction(label: 'Agregar a la bolsa'): () =>
                  unawaited(workspace._drop(widget.drag)),
            }
          : null,
      child: Listener(
        onPointerCancel: active ? (_) => _cancel() : null,
        child: GestureDetector(
          onLongPressStart: active
              ? (details) {
                  _dragging = true;
                  unawaited(HapticFeedback.mediumImpact());
                  workspace._beginDrag(widget.drag, details.globalPosition);
                }
              : null,
          onLongPressMoveUpdate: active
              ? (details) => workspace._moveDrag(details.globalPosition)
              : null,
          onLongPressEnd: active
              ? (details) {
                  _dragging = false;
                  unawaited(workspace._endDrag(details.globalPosition));
                }
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}

class _BagDropZone extends StatelessWidget {
  const _BagDropZone({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return AnimatedContainer(
      key: const Key('duo-bag-drop-zone'),
      duration: reduceMotion(context) ? Duration.zero : kSnap,
      // Opaque, so the bag beneath does not read through the invitation.
      decoration: BoxDecoration(
        color: active ? palette.surface : palette.canvas,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? palette.ink : palette.hairline,
          width: active ? 2 : 1,
        ),
      ),
      // High in the zone: the lifted card follows the finger near its middle.
      child: Align(
        alignment: const Alignment(0, -.6),
        child: Padding(
          padding: const EdgeInsets.all(BoutiqueSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 34, color: palette.ink),
              const SizedBox(height: BoutiqueSpace.md),
              Text(
                active
                    ? 'Suelta para agregarla'
                    : 'Suéltala aquí para agregarla a tu bolsa',
                textAlign: TextAlign.center,
                style: boutiqueText(
                  size: 15,
                  weight: FontWeight.w600,
                  color: palette.ink,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
