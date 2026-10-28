import 'package:flutter/widgets.dart';

/// The detail pane owns destination chrome while browsing remains visible.
class StorefrontPaneScope extends InheritedWidget {
  const StorefrontPaneScope({
    required this.ownsNavigation,
    required super.child,
    super.key,
  });
  final bool ownsNavigation;
  static bool ownsNavigationOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StorefrontPaneScope>()
          ?.ownsNavigation ??
      true;

  @override
  bool updateShouldNotify(StorefrontPaneScope oldWidget) =>
      ownsNavigation != oldWidget.ownsNavigation;
}
