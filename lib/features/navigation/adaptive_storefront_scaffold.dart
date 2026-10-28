/// Flutter chrome follows verified host bar context, never a device width.
library;

import 'package:flutter/material.dart';

import '../../app/storefront_layout.dart';
import '../../app/theme.dart';
import '../../platform/system_layout_context.dart';
import 'monetta_bottom_navigation.dart';
import 'storefront_pane_scope.dart';

class AdaptiveStorefrontScaffold extends StatelessWidget {
  const AdaptiveStorefrontScaffold({
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.drawer,
    this.drawerScrimColor,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.onSearch,
    this.avoidReservedRegions = false,
    super.key,
  });
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget? drawer;
  final Color? drawerScrimColor;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final VoidCallback? onSearch;
  final bool avoidReservedRegions;

  @override
  Widget build(BuildContext context) {
    final geometry = SystemLayoutScope.of(context);
    final ownsChrome = StorefrontPaneScope.ownsNavigationOf(context);
    final vertical = ownsChrome &&
        geometry.barEdge != SystemBarEdge.none &&
        bottomNavigationBar is MonettaBottomNavigation;
    final bar = appBar;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: vertical ? null : appBar,
      drawer: drawer,
      drawerScrimColor: drawerScrimColor,
      extendBody: extendBody,
      bottomNavigationBar: vertical ? null : bottomNavigationBar,
      body: ViewRelativeLayout(
        builder: (context, constraints, origin) {
          // The same Stack/Positioned slots survive changes of bar axis.
          final size = constraints.biggest;
          final safe = MediaQuery.paddingOf(context);
          final left = vertical ? safe.left : 0.0;
          final right = vertical ? safe.right : 0.0;
          final top = vertical ? safe.top : 0.0;
          final bottom = vertical ? safe.bottom : 0.0;
          final railLeft = geometry.barEdge == SystemBarEdge.left;
          final reservedWidth = railLeft ? safe.left : safe.right;
          final railWidth =
              reservedWidth >= 48 ? reservedWidth : StorefrontLayout.railWidth;
          final extraRail = reservedWidth >= 48 ? 0.0 : railWidth;
          final content = Rect.fromLTRB(
            left + (vertical && railLeft ? extraRail : 0),
            top,
            size.width - right - (vertical && !railLeft ? extraRail : 0),
            size.height - bottom,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: content,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: content.size,
                    padding: vertical ? EdgeInsets.zero : safe,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vertical && bar is AppBar && bar.title != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Center(child: bar.title!),
                        )
                      else
                        const SizedBox.shrink(),
                      Expanded(
                        child: avoidReservedRegions
                            ? SystemUsableSurface(child: body)
                            : body,
                      ),
                    ],
                  ),
                ),
              ),
              if (vertical)
                Positioned(
                  left: railLeft ? (reservedWidth >= 48 ? 0 : left) : null,
                  right: railLeft ? null : (reservedWidth >= 48 ? 0 : right),
                  top: top,
                  bottom: bottom,
                  width: railWidth,
                  child: _ReservedRail(
                    child: ColoredBox(
                      color: context.monettaColors.navigationSurface,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                if (bar is AppBar && bar.leading != null)
                                  bar.leading!
                                else if (Navigator.canPop(context))
                                  const BackButton(),
                                if (drawer != null &&
                                    (bar is! AppBar || bar.leading == null))
                                  Builder(
                                    builder: (context) => IconButton(
                                      tooltip: 'Abrir menú',
                                      onPressed: () =>
                                          Scaffold.of(context).openDrawer(),
                                      icon: const Icon(Icons.menu),
                                    ),
                                  ),
                                if (bar is AppBar) ...?bar.actions,
                                if (bar == null && onSearch != null)
                                  IconButton(
                                    tooltip: 'Buscar',
                                    onPressed: onSearch,
                                    icon: const Icon(Icons.search),
                                  ),
                              ],
                            ),
                          ),
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: (bottomNavigationBar!
                                      as MonettaBottomNavigation)
                                  .asRail(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Move the related rail controls together when an active region intersects
/// the rail. No additional hinge margins are invented.
class _ReservedRail extends StatelessWidget {
  const _ReservedRail({required this.child});
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
