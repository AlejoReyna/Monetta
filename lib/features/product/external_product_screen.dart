/// In-app product detail for owner-procurement listings.
///
/// A product card always lands here first. Only the explicit merchant CTA
/// leaves Monetta, and the selected color's URL is validated immediately
/// before it is handed to the OS.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/catalog_item.dart';
import '../catalog/extracted_badge.dart';

typedef ExternalLinkOpener = Future<bool> Function(Uri uri);

Future<bool> defaultExternalLinkOpener(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> showExternalProductDetail(
  BuildContext context, {
  required CatalogItem item,
  ExternalLinkOpener openLink = defaultExternalLinkOpener,
  int initialVariantIndex = 0,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExternalProductScreen(
        item: item,
        openLink: openLink,
        initialVariantIndex: initialVariantIndex,
      ),
    ),
  );
}

class ExternalProductScreen extends StatefulWidget {
  const ExternalProductScreen({
    required this.item,
    this.openLink = defaultExternalLinkOpener,
    this.initialVariantIndex = 0,
    super.key,
  });

  final CatalogItem item;
  final ExternalLinkOpener openLink;
  final int initialVariantIndex;

  @override
  State<ExternalProductScreen> createState() => _ExternalProductScreenState();
}

class _ExternalProductScreenState extends State<ExternalProductScreen> {
  late int _selectedVariantIndex;

  @override
  void initState() {
    super.initState();
    _selectedVariantIndex = widget.item.variants.isNotEmpty &&
            widget.initialVariantIndex >= 0 &&
            widget.initialVariantIndex < widget.item.variants.length
        ? widget.initialVariantIndex
        : 0;
  }

  CatalogVariant? get _variant => widget.item.variants.isEmpty
      ? null
      : widget.item.variants[_selectedVariantIndex];

  String? get _imageUrl => _variant?.imageUrl ?? widget.item.imageUrl;
  Money? get _price => _variant?.price ?? widget.item.price;
  CatalogAvailability get _availability =>
      _variant?.availability ?? widget.item.availability;
  String get _detailUrl => _variant?.detailUrl ?? widget.item.detailUrl;

  Future<void> _openMerchant() async {
    if (!isValidExternalDetailUrlForSource(widget.item.source, _detailUrl)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enlace no válido para ${widget.item.merchant}'),
          ),
        );
      }
      return;
    }

    final launched = await widget.openLink(Uri.parse(_detailUrl));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir ${widget.item.merchant}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const MonettaWordmark.appBar(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ExternalDetailImage(url: _imageUrl),
                const Positioned(
                  top: 16,
                  left: 16,
                  child: ExtractedBadge(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.item.merchant} · Estados Unidos'.toUpperCase(),
                  style: eyebrow(size: 10.5),
                ),
                const SizedBox(height: 12),
                Text(
                  shopperProductName(widget.item.title),
                  style: display(26),
                ),
                const SizedBox(height: 16),
                Text(
                  formatCatalogMoney(_price),
                  style: sans(size: 17, weight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                _AvailabilityLabel(availability: _availability),
                if (widget.item.variants.length > 1) ...[
                  const SizedBox(height: 28),
                  Text('Color'.toUpperCase(), style: eyebrow()),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var index = 0;
                          index < widget.item.variants.length;
                          index++)
                        ChoiceChip(
                          key: ValueKey(
                            'detail-${widget.item.variants[index].variantId}',
                          ),
                          label: Text(
                            widget.item.variants[index].displayName,
                          ),
                          selected: index == _selectedVariantIndex,
                          onSelected: (_) {
                            setState(() => _selectedVariantIndex = index);
                          },
                          selectedColor: context.monettaColors.contentPrimary,
                          backgroundColor: context.monettaColors.surfaceMuted,
                          side: BorderSide.none,
                          showCheckmark: false,
                          labelStyle: sans(
                            size: 11,
                            color: index == _selectedVariantIndex
                                ? context.monettaColors.canvas
                                : context.monettaColors.contentPrimary,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ProductInformation(item: widget.item, variant: _variant),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: FilledButton(
          onPressed: _openMerchant,
          child: Text('Ver en ${widget.item.merchant}'.toUpperCase()),
        ),
      ),
    );
  }
}

class _ExternalDetailImage extends StatelessWidget {
  const _ExternalDetailImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.monettaColors.surfaceMuted,
      child: url == null
          ? Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 22,
                color: context.monettaColors.contentMuted,
              ),
            )
          : CachedNetworkImage(
              key: ValueKey(url),
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  ColoredBox(color: context.monettaColors.surfaceMuted),
              errorWidget: (_, __, ___) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 22,
                  color: context.monettaColors.contentMuted,
                ),
              ),
            ),
    );
  }
}

class _AvailabilityLabel extends StatelessWidget {
  const _AvailabilityLabel({required this.availability});

  final CatalogAvailability availability;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (availability) {
      CatalogAvailability.inStock => (
          'Disponible',
          context.monettaColors.success
        ),
      CatalogAvailability.outOfStock => ('Agotado', context.monettaColors.sale),
      CatalogAvailability.unknown => (
          'Disponibilidad por confirmar',
          context.monettaColors.contentMuted
        ),
    };
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(label.toUpperCase(), style: eyebrow(size: 9.5, color: color)),
      ],
    );
  }
}

class _ProductInformation extends StatelessWidget {
  const _ProductInformation({required this.item, required this.variant});

  final CatalogItem item;
  final CatalogVariant? variant;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Marca', item.brand),
      if (item.category != null && item.category!.trim().isNotEmpty)
        ('Categoría', item.category!),
      if (variant?.colorName != null) ('Color', variant!.colorName!),
      if (variant?.sku != null) ('SKU', variant!.sku!),
      ('Mercado', 'Estados Unidos'),
      ('Fuente', _sourceLabel(variant?.detailUrl ?? item.detailUrl)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child:
              Text('Descripción del producto'.toUpperCase(), style: eyebrow()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Text(
            '${item.title} de ${item.brand}. Información extraída del catálogo '
            'estadounidense de ${item.merchant} para que el propietario evalúe '
            'precio, disponibilidad y compra para envío a México.',
            style: sans(
              size: 13,
              color: context.monettaColors.contentMuted,
              height: 1.65,
            ),
          ),
        ),
        for (final (label, value) in rows)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: context.monettaColors.divider,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    label,
                    style: sans(
                      size: 12,
                      color: context.monettaColors.contentMuted,
                    ),
                  ),
                ),
                Expanded(child: Text(value, style: sans(size: 12.5))),
              ],
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: context.monettaColors.divider,
                width: 0.5,
              ),
            ),
          ),
          child: SizedBox(width: double.infinity),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Text(
            'Producto para compra manual. Confirma precio, existencias y envío '
            'en el sitio del comercio antes de comprar.',
            style: sans(size: 11, color: context.monettaColors.contentMuted),
          ),
        ),
      ],
    );
  }
}

String _sourceLabel(String detailUrl) {
  final uri = Uri.tryParse(detailUrl);
  if (uri == null || uri.host.isEmpty) return detailUrl;
  return '${uri.host}${uri.path}';
}
