import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/media/monetta_image.dart';
import '../../data/media/media_url.dart';
import '../boutique/boutique_tokens.dart';

Future<int?> showProductZoom(
  BuildContext context, {
  required List<String> images,
  required int initialPage,
  required String title,
}) {
  final focus = FocusManager.instance.primaryFocus;
  return showDialog<int>(
    context: context,
    builder: (_) =>
        _ProductZoom(images: images, initialPage: initialPage, title: title),
  ).whenComplete(() {
    if (focus?.context != null) focus!.requestFocus();
  });
}

class _ProductZoom extends StatefulWidget {
  const _ProductZoom({
    required this.images,
    required this.initialPage,
    required this.title,
  });
  final List<String> images;
  final int initialPage;
  final String title;
  @override
  State<_ProductZoom> createState() => _ProductZoomState();
}

class _ProductZoomState extends State<_ProductZoom> {
  final _transform = TransformationController();
  late int _page = widget.initialPage;
  double get _scale => _transform.value.getMaxScaleOnAxis();
  void _setScale(double value) {
    _transform.value = Matrix4.diagonal3Values(
      value.clamp(1, 4).toDouble(),
      value.clamp(1, 4).toDouble(),
      1,
    );
  }

  void _move(int delta) => setState(() {
        _page = (_page + delta + widget.images.length) % widget.images.length;
        _transform.value = Matrix4.identity();
      });
  void _close() => Navigator.of(context).pop(_page);
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _close,
          const SingleActivator(LogicalKeyboardKey.equal): () =>
              _setScale(_scale + .5),
          const SingleActivator(LogicalKeyboardKey.minus): () =>
              _setScale(_scale - .5),
          if (widget.images.length > 1) ...{
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _move(1),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _move(-1),
          },
        },
        child: Dialog(
          key: const Key('product-zoom-dialog'),
          backgroundColor: context.boutique.canvas,
          insetPadding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Imagen del producto',
                          style: boutiqueText(size: 18),
                        ),
                      ),
                      IconButton(
                        autofocus: true,
                        tooltip: 'Cerrar zoom',
                        onPressed: _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      transformationController: _transform,
                      minScale: 1,
                      maxScale: 4,
                      child: MonettaImage(
                        key: ValueKey(widget.images[_page]),
                        url: widget.images[_page],
                        fit: BoxFit.contain,
                        cacheWidth: MediaUrl.heroWidth,
                        fallbackLabel: widget.title,
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.title, textAlign: TextAlign.center),
                          ValueListenableBuilder<Matrix4>(
                            valueListenable: _transform,
                            builder: (_, __, ___) => Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Reducir',
                                  onPressed: _scale > 1
                                      ? () => _setScale(_scale - .5)
                                      : null,
                                  icon: const Icon(Icons.remove),
                                ),
                                Semantics(
                                  liveRegion: true,
                                  child: Text('${(_scale * 100).round()}%'),
                                ),
                                IconButton(
                                  tooltip: 'Ampliar',
                                  onPressed: _scale < 4
                                      ? () => _setScale(_scale + .5)
                                      : null,
                                  icon: const Icon(Icons.add),
                                ),
                                TextButton(
                                  onPressed: () => _setScale(1),
                                  child: Text(
                                    'Restablecer',
                                    style: boutiqueText(
                                      color: context.boutique.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.images.length > 1)
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Foto anterior',
                                  onPressed: () => _move(-1),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text(
                                  'Foto ${_page + 1} de ${widget.images.length}',
                                ),
                                IconButton(
                                  tooltip: 'Foto siguiente',
                                  onPressed: () => _move(1),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
