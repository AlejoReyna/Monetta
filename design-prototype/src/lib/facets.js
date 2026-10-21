// Shopper-facing labels for the canonical facets. Values mirror the app's
// `lib/app/shopper_copy.dart`; slugs mirror `assets/rules/normalization_rules.json`.

export const CATEGORY_LABELS = {
  bolsa: 'Bolsa',
  cartera: 'Cartera',
  tarjetero: 'Tarjetero',
  monedero: 'Monedero',
  reloj: 'Reloj',
  cosmetiquera: 'Cosmetiquera',
  set: 'Set',
  accesorio: 'Accesorio',
};

export const CATEGORY_PLURALS = {
  bolsa: 'Bolsas',
  cartera: 'Carteras',
  tarjetero: 'Tarjeteros',
  monedero: 'Monederos',
  reloj: 'Relojes',
  cosmetiquera: 'Cosmetiqueras',
  set: 'Sets',
  accesorio: 'Accesorios',
};

export const SILHOUETTE_LABELS = {
  crossbody: 'Crossbody',
  tote: 'Tote',
  shoulder: 'De hombro',
  satchel: 'Satchel',
  hobo: 'Hobo',
  clutch: 'Clutch',
  mini: 'Mini',
  wristlet: 'Muñequera',
};

export const COLOR_LABELS = {
  negro: 'Negro',
  blanco: 'Blanco',
  cafe: 'Café',
  beige: 'Beige',
  gris: 'Gris',
  rosa: 'Rosa',
  azul: 'Azul',
  rojo: 'Rojo',
  dorado: 'Dorado',
  verde: 'Verde',
  morado: 'Morado',
  amarillo: 'Amarillo',
  multicolor: 'Multicolor',
};

/** Swatch fills from `product_selection.dart` (`kProductSwatchFills`). */
export const SWATCH_FILLS = {
  negro: '#1B1B1B',
  blanco: '#FFFFFF',
  cafe: '#6F4E37',
  beige: '#D9CBB8',
  gris: '#9AA0A6',
  rosa: '#E3A7B8',
  azul: '#2F4A7A',
  rojo: '#B3261E',
  dorado: '#C5A052',
  verde: '#3B7B4A',
  morado: '#7A5C9E',
  amarillo: '#E0B400',
};

export const PATTERN_LABELS = {
  monograma: 'Monograma',
  floral: 'Floral',
  cerezas: 'Cerezas',
  limones: 'Limones',
  rayas: 'Rayas',
  animal_print: 'Animal print',
  relieve: 'Relieve',
  acolchado: 'Acolchado',
  liso: 'Liso',
};

export const DELIVERY_LABELS = {
  inmediato: 'Envío inmediato',
  pedido: 'Sobre pedido',
};

export function fold(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

export function slugify(value) {
  return fold(value)
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

export function isInStock(product) {
  return product.variants.some((variant) => variant.available);
}

export function deliveryOf(product) {
  if (product.flags.sobrePedido) return 'pedido';
  if (product.flags.envioInmediato) return 'inmediato';
  return null;
}

export function defaultVariant(product) {
  return product.variants.find((variant) => variant.id === product.defaultVariantId) ?? product.variants[0];
}

/** The lowest current price across variants, as a decimal string. */
export function minPrice(product) {
  return product.variants.reduce(
    (low, variant) => (Number(variant.price) < Number(low) ? variant.price : low),
    product.variants[0].price,
  );
}

export function variantLabel(product, variant) {
  if (!variant?.title) return null;
  const option = product.options[0]?.name ?? 'Opción';
  return `${option}: ${variant.title}`;
}

/**
 * The app's swatch rule: swatches only when every selectable variant names
 * exactly one canonical colour (no "/" bicolours, no model names).
 */
export function swatchFor(title) {
  if (!title || title.includes('/')) return null;
  const folded = fold(title);
  const aliases = {
    negro: ['negro', 'negra', 'black'],
    blanco: ['blanco', 'blanca', 'white', 'vanilla', 'crema', 'ivory'],
    cafe: ['cafe', 'brown', 'chocolate', 'camel', 'taupe', 'marron', 'saddle'],
    beige: ['beige', 'nude', 'arena', 'hueso'],
    gris: ['gris', 'grey', 'gray'],
    rosa: ['rosa', 'pink'],
    azul: ['azul', 'blue', 'navy', 'marino'],
    rojo: ['rojo', 'roja', 'red', 'vino'],
    dorado: ['dorado', 'gold'],
    verde: ['verde', 'green'],
    morado: ['morado', 'lila', 'purple'],
    amarillo: ['amarillo', 'yellow'],
  };
  for (const [slug, words] of Object.entries(aliases)) {
    if (words.includes(folded)) return { slug, fill: SWATCH_FILLS[slug] };
  }
  return null;
}

export function hasReliableSwatches(product) {
  return product.variants.length > 1 && product.variants.every((variant) => swatchFor(variant.title));
}
