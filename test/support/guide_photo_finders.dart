import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds an [Image] that paints the bundled asset [name].
Finder findAssetImage(String name) => find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == name,
      description: 'Image.asset($name)',
    );
