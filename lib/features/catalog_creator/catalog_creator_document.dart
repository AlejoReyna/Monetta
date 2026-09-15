/// Modelo y generación del documento del creador de catálogo (paquete F).
///
/// Precios, disponibilidad e imágenes siempre provienen de [Product] reales;
/// aquí no hay precios inventados ni enlaces públicos sin alojamiento.
/// El resultado se comparte solo por acción explícita del usuario
/// (`Share.share`), nunca con envío automático a terceros.
library;

import '../../domain/product.dart';

/// Selección por producto: variante elegida y cantidad.
class CatalogSelection {
  CatalogSelection({
    required this.productId,
    required this.variantId,
    required this.quantity,
  }) : assert(quantity > 0);

  final String productId;
  final String variantId;
  final int quantity;

  CatalogSelection copyWith({String? variantId, int? quantity}) =>
      CatalogSelection(
        productId: productId,
        variantId: variantId ?? this.variantId,
        quantity: quantity ?? this.quantity,
      );
}

class CatalogLine {
  const CatalogLine({
    required this.product,
    required this.variant,
    required this.quantity,
  });

  final Product product;
  final ProductVariant variant;
  final int quantity;

  double get lineTotal => variant.price * quantity;
}

/// Resuelve selecciones contra productos reales. Ignora productos o
/// variantes inexistentes y fija la cantidad a >= 1.
List<CatalogLine> resolveCatalogLines(
  List<Product> products,
  Map<String, CatalogSelection> selections,
) {
  final byId = {for (final p in products) p.id: p};
  final lines = <CatalogLine>[];
  for (final entry in selections.entries) {
    final product = byId[entry.key];
    if (product == null) continue;
    final selection = entry.value;
    final variant =
        product.variants.where((v) => v.id == selection.variantId).firstOrNull;
    if (variant == null) continue;
    lines.add(
      CatalogLine(
        product: product,
        variant: variant,
        quantity: selection.quantity < 1 ? 1 : selection.quantity,
      ),
    );
  }
  return lines;
}

String _money(double amount) {
  final whole = amount == amount.roundToDouble();
  final body = whole ? amount.toInt().toString() : amount.toStringAsFixed(2);
  // Miles estilo es-MX sin dependencias.
  final parts = body.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  if (parts.length > 1) buffer.write('.${parts[1]}');
  return '\$$buffer MXN';
}

/// Documento compartible: encabezado, líneas con variante/cantidad/precio
/// real, disponibilidad honesta y total. Sin enlaces públicos inventados.
String buildCatalogShareText({
  required String title,
  required List<CatalogLine> lines,
}) {
  final buffer = StringBuffer();
  buffer.writeln(title.isEmpty ? 'Mi selección Monetta' : title);
  buffer.writeln('Monetta · productos originales importados de EE. UU.');
  buffer.writeln();
  var total = 0.0;
  var index = 1;
  for (final line in lines) {
    final variantLabel =
        line.variant.isDefault ? '' : ' (${line.variant.title})';
    final stock =
        line.variant.available ? 'Disponible' : 'Últimas piezas / consultar';
    buffer.writeln(
      '$index. ${line.product.title}$variantLabel ×${line.quantity} — '
      '${_money(line.variant.price)} c/u · $stock',
    );
    total += line.lineTotal;
    index += 1;
  }
  buffer.writeln();
  buffer.writeln('Total estimado: ${_money(total)}');
  buffer.writeln(
    'Precios y disponibilidad al momento de crear la selección; '
    'confirma por WhatsApp antes de comprar.',
  );
  return buffer.toString();
}

double catalogTotal(List<CatalogLine> lines) =>
    lines.fold(0.0, (sum, line) => sum + line.lineTotal);

int catalogModelCount(List<CatalogLine> lines) =>
    lines.fold(0, (sum, line) => sum + line.quantity);
