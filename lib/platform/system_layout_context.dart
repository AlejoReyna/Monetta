/// View-relative UIKit geometry, with an explicit fallback on other systems.
library;

import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum SystemBarEdge { none, left, right }

@immutable
class ReservedRegion {
  const ReservedRegion({required this.bounds, required this.active});
  final Rect bounds;
  final bool active;
}

@immutable
class SystemLayoutContext {
  const SystemLayoutContext({
    this.supported = false,
    this.sequence = 0,
    this.viewSize = Size.zero,
    this.safeInsets = EdgeInsets.zero,
    this.barEdge = SystemBarEdge.none,
    this.divisions = const [],
    this.occlusions = const [],
  });

  final bool supported;
  final int sequence;
  final Size viewSize;
  final EdgeInsets safeInsets;
  final SystemBarEdge barEdge;
  final List<ReservedRegion> divisions;
  final List<ReservedRegion> occlusions;

  factory SystemLayoutContext.fromMessage(Map<Object?, Object?> message) {
    double number(Object? value) => value is num ? value.toDouble() : 0;
    Rect rect(Map<Object?, Object?> value) => Rect.fromLTWH(
          number(value['x']),
          number(value['y']),
          number(value['width']),
          number(value['height']),
        );
    List<ReservedRegion> regions(Object? raw) => [
          if (raw is List)
            for (final value in raw)
              if (value is Map<Object?, Object?>)
                ReservedRegion(
                  bounds: rect(value),
                  active: value['active'] == true,
                ),
        ];
    final insets = message['safeInsets'];
    return SystemLayoutContext(
      supported: message['supported'] == true,
      sequence: (message['sequence'] as num?)?.toInt() ?? 0,
      viewSize: Size(number(message['width']), number(message['height'])),
      safeInsets: insets is Map<Object?, Object?>
          ? EdgeInsets.fromLTRB(
              number(insets['left']),
              number(insets['top']),
              number(insets['right']),
              number(insets['bottom']),
            )
          : EdgeInsets.zero,
      barEdge: switch (message['barEdge']) {
        'left' => SystemBarEdge.left,
        'right' => SystemBarEdge.right,
        _ => SystemBarEdge.none,
      },
      divisions: regions(message['divisions']),
      occlusions: regions(message['occlusions']),
    );
  }

  /// Reject geometry from a previous rotation until the host and Flutter agree.
  bool matches(Size size) =>
      supported &&
      (viewSize.width - size.width).abs() < 1 &&
      (viewSize.height - size.height).abs() < 1;

  /// Region frames already include UIKit's interactive margins.
  List<Rect> usableRegions(Rect content) {
    var result = <Rect>[content];
    for (final region in [...divisions, ...occlusions]) {
      if (!region.active || region.bounds.isEmpty) continue;
      final next = <Rect>[];
      for (final area in result) {
        final cut = area.intersect(region.bounds);
        if (cut.isEmpty) {
          next.add(area);
          continue;
        }
        // Keep disjoint rectangles: every returned control group is wholly
        // outside the reserved region, including a camera in the interior.
        next.addAll(
          [
            Rect.fromLTRB(area.left, area.top, area.right, cut.top),
            Rect.fromLTRB(area.left, cut.bottom, area.right, area.bottom),
            Rect.fromLTRB(area.left, cut.top, cut.left, cut.bottom),
            Rect.fromLTRB(cut.right, cut.top, area.right, cut.bottom),
          ].where((candidate) => !candidate.isEmpty),
        );
      }
      result = next;
    }
    result.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return result;
  }
}

class SystemLayoutScope extends InheritedWidget {
  const SystemLayoutScope({
    required this.geometry,
    required super.child,
    super.key,
  });
  final SystemLayoutContext geometry;

  static SystemLayoutContext of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SystemLayoutScope>()
          ?.geometry ??
      const SystemLayoutContext();

  @override
  bool updateShouldNotify(SystemLayoutScope oldWidget) =>
      geometry != oldWidget.geometry;
}

/// One subscription above the navigator; resizing does not create services or
/// engines. A canceled listener detaches its native geometry probe as well.
class SystemLayoutHost extends StatefulWidget {
  const SystemLayoutHost({required this.child, super.key});
  final Widget child;

  @override
  State<SystemLayoutHost> createState() => _SystemLayoutHostState();
}

class _SystemLayoutHostState extends State<SystemLayoutHost> {
  static const _channel = EventChannel('mx.monetta/system_layout');
  StreamSubscription<Object?>? _subscription;
  SystemLayoutContext _geometry = const SystemLayoutContext();

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    _subscription = _channel.receiveBroadcastStream().listen(
      (message) {
        if (!mounted || message is! Map<Object?, Object?>) return;
        final next = SystemLayoutContext.fromMessage(message);
        if (next.sequence <= _geometry.sequence) return;
        setState(() => _geometry = next);
      },
      onError: (Object error) {
        // Older hosts explicitly retain the ordinary responsive experience.
        if (mounted) setState(() => _geometry = const SystemLayoutContext());
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final current =
        _geometry.matches(media.size) ? _geometry : const SystemLayoutContext();
    return SystemLayoutScope(
      geometry: current,
      child: MediaQuery(
        data: media.copyWith(
          displayFeatures: [
            ...media.displayFeatures,
            for (final region in current.divisions)
              if (region.active && !region.bounds.isEmpty)
                DisplayFeature(
                  bounds: region.bounds,
                  type: DisplayFeatureType.hinge,
                  state: DisplayFeatureState.postureHalfOpened,
                ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Current source position for a Flutter sheet/dialog, including pane origins.
Offset presentationAnchor(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    return box.localToGlobal(box.size.center(Offset.zero));
  }
  return Offset.zero;
}

/// Layout and UIKit regions use different origins below a header or pane.
/// Measure after layout and coalesce the corrective frame. Until the origin
/// is measured, controls cannot receive a tap against an unverified frame.
class ViewRelativeLayout extends StatefulWidget {
  const ViewRelativeLayout({required this.builder, super.key});
  final Widget Function(BuildContext, BoxConstraints, Offset) builder;
  @override
  State<ViewRelativeLayout> createState() => _ViewRelativeLayoutState();
}

class _ViewRelativeLayoutState extends State<ViewRelativeLayout> {
  final _key = GlobalKey();
  Offset _origin = Offset.zero;
  Size? _size;
  bool _measured = false;
  bool _queued = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        key: _key,
        builder: (context, constraints) {
          if (_size != constraints.biggest) {
            _size = constraints.biggest;
            _measured = false;
          }
          if (!_queued) {
            _queued = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _queued = false;
              if (!mounted) return;
              final box = _key.currentContext?.findRenderObject();
              if (box is! RenderBox || !box.hasSize) return;
              final origin = box.localToGlobal(Offset.zero);
              if (!_measured || origin != _origin) {
                setState(() {
                  _origin = origin;
                  _measured = true;
                });
              }
            });
          }
          return IgnorePointer(
            ignoring: SystemLayoutScope.of(context).supported && !_measured,
            child: widget.builder(context, constraints, _origin),
          );
        },
      );
}

/// Existing scrolling surfaces can keep their full task in one usable region
/// when a small or partial-fold window cannot fit a useful two-pane layout.
class SystemUsableSurface extends StatelessWidget {
  const SystemUsableSurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => ViewRelativeLayout(
        builder: (context, box, origin) {
          final whole = origin & box.biggest;
          final regions = SystemLayoutScope.of(context).usableRegions(whole);
          final rect = regions.isEmpty ? whole : regions.first;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              rect.left - whole.left,
              rect.top - whole.top,
              whole.right - rect.right,
              whole.bottom - rect.bottom,
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: rect.size),
              child: child,
            ),
          );
        },
      );
}
