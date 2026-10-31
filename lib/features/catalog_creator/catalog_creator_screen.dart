/// Creador de catálogo compartible (paquete F, figura 11).
///
/// Flujo: seleccionar productos → variante/cantidad → resumen → vista previa →
/// exportar/compartir por acción explícita. Usa precios, disponibilidad e
/// imágenes reales de [Product]. Sin enlaces públicos sin alojamiento.
/// Propiedad de F; el parche de integración global vive en
/// `docs/redesign/PAQUETE_F_INTEGRACION.md`.
library;

import 'package:flutter/material.dart';

import '../navigation/monetta_page_header.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/media/monetta_image.dart';
import '../../app/theme.dart';
import '../../domain/product.dart';
import '../../main.dart';
import 'catalog_creator_document.dart';

typedef CatalogSharer = Future<void> Function(String text, Rect? origin);

Future<void> _defaultShare(String text, Rect? origin) => Share.share(
      text,
      subject: 'Mi selección Monetta',
      sharePositionOrigin: origin,
    );

/// Abre el creador con el catálogo real del store. Punto de integración
/// documentado (no se llama desde pantallas de otros paquetes en este cambio).
Future<void> openCatalogCreator(BuildContext context) {
  final store = StoreScope.of(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CatalogCreatorScreen(products: store.products),
    ),
  );
}

class CatalogCreatorScreen extends StatefulWidget {
  const CatalogCreatorScreen({
    required this.products,
    this.sharer,
    super.key,
  });

  /// Productos reales del catálogo (precio, disponibilidad, imágenes).
  final List<Product> products;
  final CatalogSharer? sharer;

  @override
  State<CatalogCreatorScreen> createState() => _CatalogCreatorScreenState();
}

class _CatalogCreatorScreenState extends State<CatalogCreatorScreen> {
  final Map<String, CatalogSelection> _selections = {};
  final Map<String, int> _variantIndex = {};
  String _title = '';
  String _query = '';
  int _step = 0;

  List<Product> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products
        .where(
          (p) =>
              p.title.toLowerCase().contains(q) ||
              p.vendor.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  List<CatalogLine> get _lines =>
      resolveCatalogLines(widget.products, _selections);

  void _toggle(Product product) {
    setState(() {
      if (_selections.containsKey(product.id)) {
        _selections.remove(product.id);
      } else if (product.variants.isNotEmpty) {
        final index = _variantIndex[product.id] ?? 0;
        final variant =
            product.variants[index.clamp(0, product.variants.length - 1)];
        _selections[product.id] = CatalogSelection(
          productId: product.id,
          variantId: variant.id,
          quantity: 1,
        );
      }
    });
  }

  void _setVariant(Product product, int index) {
    setState(() {
      _variantIndex[product.id] = index;
      final current = _selections[product.id];
      if (current != null && index < product.variants.length) {
        _selections[product.id] =
            current.copyWith(variantId: product.variants[index].id);
      }
    });
  }

  void _setQuantity(Product product, int delta) {
    final current = _selections[product.id];
    if (current == null) return;
    setState(() {
      _selections[product.id] = current.copyWith(
        quantity: (current.quantity + delta).clamp(1, 99),
      );
    });
  }

  Future<void> _share() async {
    final lines = _lines;
    if (lines.isEmpty) return;
    final text = buildCatalogShareText(title: _title.trim(), lines: lines);
    final renderBox = context.findRenderObject();
    final origin = renderBox is RenderBox
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;
    try {
      await (widget.sharer ?? _defaultShare)(text, origin);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir la selección')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    return Scaffold(
      appBar: buildMonettaPageAppBar(
        context,
        title: 'Crear catálogo',
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final selection = _SelectionPane(
            visible: _visible,
            selections: _selections,
            variantIndex: _variantIndex,
            query: _query,
            onQuery: (value) => setState(() => _query = value),
            onToggle: _toggle,
            onVariant: _setVariant,
            onQuantity: _setQuantity,
          );
          final side = _SummaryPane(
            title: _title,
            onTitle: (value) => setState(() => _title = value),
            lines: lines,
            step: _step,
            onStep: (value) => setState(() => _step = value),
            onShare: _share,
            onCopy: () async {
              final text = buildCatalogShareText(
                title: _title.trim(),
                lines: lines,
              );
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selección copiada')),
              );
            },
          );
          if (!wide) {
            return ListView(
              key: const ValueKey('catalog-creator-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _StepsHeader(
                  step: _step,
                  onStep: (v) => setState(() => _step = v),
                ),
                const SizedBox(height: 20),
                if (_step == 0) selection else side,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: selection),
              Expanded(
                flex: 9,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 20, 28, 32),
                  child: side,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepsHeader extends StatelessWidget {
  const _StepsHeader({required this.step, required this.onStep});

  final int step;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Seleccionar', 'Resumir', 'Vista previa'];
    return Row(
      key: const ValueKey('catalog-creator-steps'),
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onStep(i),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0${i + 1}',
                    style: eyebrow(
                      color: i == step
                          ? context.monettaColors.accentContent
                          : context.monettaColors.contentMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: sans(
                      size: 12,
                      weight: i == step ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 2,
                    color: i == step
                        ? context.monettaColors.accent
                        : context.monettaColors.divider,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectionPane extends StatelessWidget {
  const _SelectionPane({
    required this.visible,
    required this.selections,
    required this.variantIndex,
    required this.query,
    required this.onQuery,
    required this.onToggle,
    required this.onVariant,
    required this.onQuantity,
  });

  final List<Product> visible;
  final Map<String, CatalogSelection> selections;
  final Map<String, int> variantIndex;
  final String query;
  final ValueChanged<String> onQuery;
  final ValueChanged<Product> onToggle;
  final void Function(Product, int) onVariant;
  final void Function(Product, int) onQuantity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('catalog-creator-search'),
          decoration: const InputDecoration(
            hintText: 'Buscar en tu catálogo…',
            prefixIcon: Icon(Icons.search_outlined),
          ),
          onChanged: onQuery,
        ),
        const SizedBox(height: 8),
        Text(
          '${visible.length} PRODUCTOS · ${selections.length} SELECCIONADOS',
          style: eyebrow(
            size: 8,
            color: context.monettaColors.contentMuted,
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Sin resultados en el catálogo real.',
              style: sans(color: context.monettaColors.contentMuted),
            ),
          ),
        for (final product in visible)
          _ProductRow(
            product: product,
            selected: selections.containsKey(product.id),
            selection: selections[product.id],
            selectedVariant: variantIndex[product.id] ?? 0,
            onToggle: () => onToggle(product),
            onVariant: (index) => onVariant(product, index),
            onQuantity: (delta) => onQuantity(product, delta),
          ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.selected,
    required this.selection,
    required this.selectedVariant,
    required this.onToggle,
    required this.onVariant,
    required this.onQuantity,
  });

  final Product product;
  final bool selected;
  final CatalogSelection? selection;
  final int selectedVariant;
  final VoidCallback onToggle;
  final ValueChanged<int> onVariant;
  final ValueChanged<int> onQuantity;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final current = product.variants.isEmpty
        ? null
        : product
            .variants[selectedVariant.clamp(0, product.variants.length - 1)];
    return Container(
      key: ValueKey('catalog-creator-product-${product.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: selected ? colors.accent : colors.divider,
          width: selected ? 1 : .5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    height: 88,
                    child: product.primaryImage == null
                        ? Container(color: colors.surfaceMuted)
                        : MonettaImage(
                            url: product.primaryImage!,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: sans(size: 13, weight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current == null
                              ? 'Consultar precio'
                              : '\$${current.price.toStringAsFixed(0)} MXN',
                          style: sans(size: 13, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: product.isInStock
                                    ? colors.success
                                    : colors.sale,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              product.isInStock
                                  ? 'Disponible'
                                  : 'Consultar disponibilidad',
                              style: sans(
                                size: 11,
                                color: colors.contentMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                    color: selected ? colors.accent : colors.contentMuted,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
          if (selected && product.variants.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < product.variants.length; i++)
                    ChoiceChip(
                      label: Text(product.variants[i].title),
                      selected: selectedVariant == i,
                      onSelected: (_) => onVariant(i),
                    ),
                ],
              ),
            ),
          if (selected && selection != null)
            _QuantityStepper(
              productId: product.id,
              quantity: selection!.quantity,
              onQuantity: onQuantity,
            ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.productId,
    required this.quantity,
    required this.onQuantity,
  });

  final String productId;
  final int quantity;
  final ValueChanged<int> onQuantity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Text('Cantidad', style: sans(size: 12)),
          const Spacer(),
          IconButton.outlined(
            key: ValueKey('qty-dec-$productId'),
            onPressed: () => onQuantity(-1),
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Quitar uno',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '$quantity',
              key: ValueKey('qty-$productId'),
              style: sans(size: 15, weight: FontWeight.w600),
            ),
          ),
          IconButton.outlined(
            key: ValueKey('qty-inc-$productId'),
            onPressed: () => onQuantity(1),
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Agregar uno',
          ),
        ],
      ),
    );
  }
}

class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
    required this.title,
    required this.onTitle,
    required this.lines,
    required this.step,
    required this.onStep,
    required this.onShare,
    required this.onCopy,
  });

  final String title;
  final ValueChanged<String> onTitle;
  final List<CatalogLine> lines;
  final int step;
  final ValueChanged<int> onStep;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final total = catalogTotal(lines);
    final models = catalogModelCount(lines);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RESUMEN', style: eyebrow()),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('catalog-creator-title'),
          decoration: const InputDecoration(
            hintText: 'Título de tu selección (opcional)',
          ),
          onChanged: onTitle,
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          color: colors.surfaceMuted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$models ${models == 1 ? 'MODELO' : 'MODELOS'} · '
                '${lines.length} ${lines.length == 1 ? 'PRODUCTO' : 'PRODUCTOS'}',
                style: eyebrow(size: 8, color: colors.contentMuted),
              ),
              const SizedBox(height: 8),
              Text(
                'Total estimado: \$${total.toStringAsFixed(0)} MXN',
                key: const ValueKey('catalog-creator-total'),
                style: editorial(24),
              ),
              const SizedBox(height: 6),
              Text(
                'Precios y disponibilidad reales al momento de crear la '
                'selección.',
                style:
                    sans(size: 11.5, color: colors.contentMuted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('VISTA PREVIA', style: eyebrow()),
        const SizedBox(height: 10),
        if (lines.isEmpty)
          Text(
            'Elige productos para ver aquí tu vista previa.',
            style: sans(color: colors.contentMuted),
          ),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${i + 1}. ${lines[i].product.title} ×${lines[i].quantity} — '
              '\$${lines[i].variant.price.toStringAsFixed(0)} MXN',
              key: ValueKey('catalog-creator-preview-$i'),
              style: sans(size: 12.5, height: 1.5),
            ),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('catalog-creator-share'),
            onPressed: lines.isEmpty ? null : onShare,
            icon: const Icon(Icons.ios_share_outlined, size: 18),
            label: const Text('COMPARTIR SELECCIÓN'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: lines.isEmpty ? null : onCopy,
            child: const Text('COPIAR TEXTO'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Se comparte solo cuando lo pides. Sin enlaces públicos: el texto '
          'sale por la app que elijas.',
          style: sans(size: 11, color: colors.contentMuted, height: 1.5),
        ),
        if (step != 1)
          TextButton(
            onPressed: () => onStep(1),
            child: const Text('REVISAR RESUMEN'),
          ),
      ],
    );
  }
}
