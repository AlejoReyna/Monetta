import 'package:flutter/widgets.dart';

/// Counts the elements Flutter rebuilds while it is installed.
///
/// It hooks [debugOnRebuildDirtyWidget], which the framework calls once per
/// dirty element rebuilt in a frame. [total] is every rebuilt element and
/// [own] is the number of times the one element passed as [screen] was
/// rebuilt. The hook is global: [stop] (or the caller's `addTearDown`) must put
/// it back to null so no other test is counted.
class RebuildCounter {
  RebuildCounter(this.screen);

  /// The element of the screen under measurement.
  final Element screen;

  int total = 0;
  int own = 0;

  void start() {
    total = 0;
    own = 0;
    debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
      total++;
      if (identical(element, screen)) own++;
    };
  }

  void stop() {
    debugOnRebuildDirtyWidget = null;
  }
}
