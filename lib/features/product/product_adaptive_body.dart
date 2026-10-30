import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/storefront_layout.dart';
import '../../platform/system_layout_context.dart';

class ProductAdaptiveBody extends StatefulWidget {
  const ProductAdaptiveBody({
    required this.gallery,
    required this.details,
    this.galleryAccessoryHeight = 0,
    super.key,
  });
  final Widget Function(double height) gallery;
  final Widget details;
  final double galleryAccessoryHeight;
  @override
  State<ProductAdaptiveBody> createState() => _ProductAdaptiveBodyState();
}

class _ProductAdaptiveBodyState extends State<ProductAdaptiveBody> {
  final _galleryKey = GlobalKey();
  final _detailsKey = GlobalKey();
  final _flow = ScrollController();
  final _detailScroll = ScrollController();

  @override
  void dispose() {
    _flow.dispose();
    _detailScroll.dispose();
    super.dispose();
  }

  Widget _gallery(double height) => KeyedSubtree(
        key: _galleryKey,
        child: widget
            .gallery(math.max(StorefrontLayout.minimumGalleryHeight, height)),
      );

  Widget get _details => KeyedSubtree(key: _detailsKey, child: widget.details);

  @override
  Widget build(BuildContext context) => ViewRelativeLayout(
        builder: (context, box, origin) {
          final size = box.biggest;
          final whole = origin & size;
          final geometry = SystemLayoutScope.of(context);
          final active = geometry.divisions.where(
            (r) => r.active && r.bounds.overlaps(whole) && !r.bounds.isEmpty,
          );
          if (active.isNotEmpty) {
            final cut = active.first.bounds.intersect(whole);
            final horizontal = cut.width >= whole.width * .8;
            final regions = horizontal
                ? [
                    Rect.fromLTRB(whole.left, whole.top, whole.right, cut.top),
                    Rect.fromLTRB(
                      whole.left,
                      cut.bottom,
                      whole.right,
                      whole.bottom,
                    ),
                  ]
                : [
                    Rect.fromLTRB(
                      whole.left,
                      whole.top,
                      cut.left,
                      whole.bottom,
                    ),
                    Rect.fromLTRB(
                      cut.right,
                      whole.top,
                      whole.right,
                      whole.bottom,
                    ),
                  ];
            if (regions.every(
              (r) =>
                  r.width >= StorefrontLayout.regionMinimumWidth &&
                  r.height >= StorefrontLayout.minimumTaskHeight,
            )) {
              // Gallery and all related purchase controls move as groups. Each
              // group scrolls inside its real region, including short poses.
              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: regions.first.shift(-origin),
                    child: _OcclusionSafe(
                      child: SingleChildScrollView(
                        child: _gallery(
                          regions.first.height - widget.galleryAccessoryHeight,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: regions.last.shift(-origin),
                    child: _OcclusionSafe(
                      child: SingleChildScrollView(
                        controller: _detailScroll,
                        child: _details,
                      ),
                    ),
                  ),
                ],
              );
            }
          }
          return _OcclusionSafe(
            child: LayoutBuilder(
              builder: (context, safeBox) =>
                  _normalFlow(context, safeBox.biggest),
            ),
          );
        },
      );

  Widget _normalFlow(BuildContext context, Size size) {
    final roomy =
        StorefrontLayout.canSplit(size, MediaQuery.textScalerOf(context));
    final galleryWidth = roomy
        ? (size.width * .52)
            .clamp(
              StorefrontLayout.browseMinimum,
              size.width -
                  StorefrontLayout.detailMinimum -
                  StorefrontLayout.paneGap,
            )
            .toDouble()
        : size.width;
    final detailsWidth = roomy
        ? size.width - galleryWidth - StorefrontLayout.paneGap
        : size.width;
    final photoHeight = roomy
        ? math.min(
            galleryWidth * 1.25,
            size.height - widget.galleryAccessoryHeight,
          )
        : math.min(
            galleryWidth * 1.25,
            size.height * .55 - widget.galleryAccessoryHeight,
          );
    return ListView(
      controller: _flow,
      padding: EdgeInsets.zero,
      children: [
        Wrap(
          spacing: StorefrontLayout.paneGap,
          children: [
            SizedBox(width: galleryWidth, child: _gallery(photoHeight)),
            SizedBox(width: detailsWidth, child: _details),
          ],
        ),
      ],
    );
  }
}

/// A camera region may sit inside an otherwise usable pane. Keep a control
/// group wholly in the largest remaining rectangle, without adding margins.
class _OcclusionSafe extends StatelessWidget {
  const _OcclusionSafe({required this.child});
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
            child: child,
          );
        },
      );
}
