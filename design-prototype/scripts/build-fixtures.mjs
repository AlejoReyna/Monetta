// Builds the prototype's demo catalog from the dated public storefront snapshot.
//
//   node scripts/build-fixtures.mjs             # rebuild src/data/catalog.json + fixtures/manifest.json
//   node scripts/build-fixtures.mjs --download  # also fetch missing product photos (needs network)
//
// The normal prototype workflow never runs this: its outputs are committed next
// to it. Facet resolution is a small port of the app's `lib/data/normalize`
// (aliases from fixtures/source/normalization_rules.json, tag ▸ product type ▸
// title tiers, whole-word matching after folding).
import { mkdir, readFile, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SOURCE = 'fixtures/source/monetta-public-catalog-2026-10-17.json';
const RULES = 'fixtures/source/normalization_rules.json';
const OUT_CATALOG = 'src/data/catalog.json';
const OUT_MANIFEST = 'fixtures/manifest.json';
const MEDIA_ROOT = 'public/media/products';
const IMAGE_WIDTH = 800;
const MAX_IMAGES = 6;
const CAPTURE_DATE = '2026-10-17';

// Curated so every state the prototype must show exists in real data: long
// names, multi-variant products with a sold-out variant, genuine compare-at
// prices, "sobre pedido" descriptions and "Envío inmediato" tags.
const MUST_INCLUDE = [
  'bolso-coach-shoulder-negro-rectangular',
  'bolso-steve-madden-crossbody-3',
  'bolso-michael-kors-marilyn-medium-signature-convertible-satchel-vanilla-rosa',
  'bolso-michael-kors-jet-set-travel-vanilla',
  'bolso-michael-kors-thompson-medium-pebbled-leather-satchel-negro',
  'cartera-michael-kors-greenwich-medium-leather-trifold-wallet-negro-1',
  'bolso-coach-station-tote-bag-negro',
  'reloj-coach-sammy-gold-white',
  'bolso-tommy-hilfiger-crossbody-beige-y-rojo',
  'bolso-guess-crossbody-negro-1',
  'bolsa-guess-crossbody-camera-camel',
  'bolsa-guess-tote-cafe-monograma-dijes',
  'cartera-calvin-klein-negra-texturizada',
  'bolsa-juicy-couture-hobo-rosa',
  'bolsa-juicy-couture-crossbody-satchel-blanca',
  'bolsa-juicy-couture-crossbody-satchel-negra',
  'bolsa-steve-madden-hobo-animal-print-piton-cafe',
  'bolsa-steve-madden-crossbody-satchel-azul-denim-estampado-cerezas',
  'cartera-guess-compacta-negro',
  'bolsa-guess-shoulder-vino-brillante',
  'reloj-michael-kors-lennox-pave-gold',
  'reloj-michael-kors-mini-aspyn-rose-gold',
  'reloj-coach-olivia-gold',
  'reloj-coach-talia-saddle',
];

const BRAND_CAPS = {
  guess: 22,
  steve_madden: 16,
  coach: 16,
  michael_kors: 16,
  tommy_hilfiger: 12,
  juicy_couture: 3,
  calvin_klein: 1,
};

// Explicitly documented demo states that the 2026-10-17 snapshot lacks.
const SYNTHETIC = {
  'bolsa-guess-shoulder-vino-brillante': {
    soldOut: true,
    note: 'Agotado de demostración: ningún producto estaba agotado por completo en el snapshot del 17-oct-2026.',
  },
  'cartera-guess-compacta-negro': {
    inventoryLimit: 2,
    note: 'Límite de existencia de demostración (2 piezas): la API pública no expone cantidades.',
  },
};

// Brands the app vocabulary does not know yet; their vendor field is correct.
const EXTRA_BRANDS = {
  juicy_couture: ['Juicy Couture'],
  calvin_klein: ['Calvin Klein'],
};

const BRAND_LABELS = {
  guess: 'Guess',
  coach: 'Coach',
  michael_kors: 'Michael Kors',
  steve_madden: 'Steve Madden',
  tommy_hilfiger: 'Tommy Hilfiger',
  anne_klein: 'Anne Klein',
  christian_dior: 'Dior',
  juicy_couture: 'Juicy Couture',
  calvin_klein: 'Calvin Klein',
};

// Prototype collections keep the live handles, including the duplicated ones,
// so URL continuity can be reviewed. Titles follow the storefront menus.
const COLLECTIONS = [
  { handle: 'guess', title: 'Bolsas', kind: 'category', category: 'bolsa', liveHandle: 'guess' },
  { handle: 'carteras-1', title: 'Carteras', kind: 'category', category: 'cartera', liveHandle: 'carteras-1' },
  { handle: 'carteras', title: 'Carteras', kind: 'category', category: 'cartera', liveHandle: 'carteras', aliasOf: 'carteras-1' },
  { handle: 'relojes', title: 'Relojes', kind: 'category', category: 'reloj', liveHandle: 'relojes' },
  { handle: 'relojes-1', title: 'Relojes', kind: 'category', category: 'reloj', liveHandle: 'relojes-1', aliasOf: 'relojes' },
  { handle: 'crossbodys', title: 'Crossbodys', kind: 'style', parent: 'guess', liveHandle: 'crossbodys' },
  { handle: 'totes', title: 'Totes', kind: 'style', parent: 'guess', liveHandle: 'totes' },
  { handle: 'hombro', title: 'Hombro', kind: 'style', parent: 'guess', liveHandle: 'hombro' },
  { handle: 'coach', title: 'Coach', kind: 'brand', brand: 'coach', liveHandle: 'coach' },
  { handle: 'michael-kors', title: 'Michael Kors', kind: 'brand', brand: 'michael_kors', liveHandle: 'michael-kors' },
  { handle: 'guess-1', title: 'Guess', kind: 'brand', brand: 'guess', liveHandle: 'guess-1' },
  { handle: 'steve-madden', title: 'Steve Madden', kind: 'brand', brand: 'steve_madden', liveHandle: 'steve-madden' },
  { handle: 'tommy-hilfiger', title: 'Tommy Hilfiger', kind: 'brand', brand: 'tommy_hilfiger', liveHandle: 'tommy-hilfiger' },
];

const CATEGORY_PRIORITY = ['tarjetero', 'monedero', 'cartera', 'reloj', 'bolsa', 'cosmetiquera', 'set', 'perfume', 'accesorio'];

// The noun that opens a Monetta title ("Cartera Coach…", "Bolso Michael Kors
// Jet Set…") is the owner's explicit category. The app resolves tags first,
// which files "Jet Set" bags under `set`; the prototype prefers the title noun.
const TITLE_CATEGORY = [
  [/^(bolsa|bolso)\b/, 'bolsa'],
  [/^cartera\b/, 'cartera'],
  [/^reloj\b/, 'reloj'],
  [/^tarjetero\b/, 'tarjetero'],
  [/^set\b/, 'set'],
];
const SILHOUETTE_PRIORITY = ['wristlet', 'clutch', 'hobo', 'satchel', 'tote', 'shoulder', 'mini', 'crossbody'];

export function fold(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function compileVocabulary(vocabulary) {
  return Object.entries(vocabulary).map(([key, aliases]) => ({
    key,
    patterns: [...aliases]
      .map(fold)
      .sort((a, b) => b.length - a.length)
      .map((alias) => ({ length: alias.length, re: new RegExp(`(?:^|[^a-z0-9])${escapeRegExp(alias)}(?:$|[^a-z0-9])`) })),
  }));
}

function matchesIn(vocabulary, text) {
  const folded = fold(text);
  const hits = [];
  for (const entry of vocabulary) {
    const hit = entry.patterns.find((pattern) => pattern.re.test(folded));
    if (hit) hits.push({ key: entry.key, length: hit.length });
  }
  return hits;
}

/** First tier with any match wins; inside a tier, [priority] then alias length decide. */
function resolveSingle(vocabulary, tiers, priority) {
  for (const tier of tiers) {
    const hits = tier.flatMap((text) => matchesIn(vocabulary, text));
    if (hits.length === 0) continue;
    const rank = (key) => (priority ? priority.indexOf(key) : 0);
    hits.sort((a, b) => rank(a.key) - rank(b.key) || b.length - a.length);
    return hits[0].key;
  }
  return null;
}

/** All matches of the first tier that yields anything (the app's colour rule). */
function resolveMany(vocabulary, tiers) {
  for (const tier of tiers) {
    const keys = [...new Set(tier.flatMap((text) => matchesIn(vocabulary, text).map((hit) => hit.key)))];
    if (keys.length > 0) return keys;
  }
  return [];
}

const ENTITIES = { '&nbsp;': ' ', '&amp;': '&', '&quot;': '"', '&#39;': "'", '&lt;': '<', '&gt;': '>', '&times;': '×' };

function htmlToLines(html) {
  const text = String(html ?? '')
    .replace(/<\s*br\s*\/?\s*>/gi, '\n')
    .replace(/<\/\s*(p|div|li|h[1-6])\s*>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&[a-z#0-9]+;/gi, (entity) => ENTITIES[entity.toLowerCase()] ?? ' ');
  return text
    .split(/\n+/)
    .map((line) =>
      line
        .replace(/[\p{Extended_Pictographic}\u{FE0F}\u{200D}\u{1F3FB}-\u{1F3FF}]/gu, '')
        .replace(/^[\s•·*\-–]+/, '')
        .replace(/\s+/g, ' ')
        .replace(/\s+([:,.])/g, '$1')
        .trim(),
    )
    .filter(Boolean);
}

const FACT_LABELS = new Map([
  ['marca', 'Marca'],
  ['modelo', 'Modelo'],
  ['tipo', 'Tipo'],
  ['color', 'Color'],
  ['diseno', 'Diseño'],
  ['material', 'Material'],
  ['incluye correa crossbody', 'Incluye correa crossbody'],
  ['medidas', 'Medidas'],
  ['alto', 'Alto'],
  ['ancho', 'Ancho'],
  ['largo', 'Largo'],
]);

/** Splits Shopify description HTML into labelled facts and running copy. */
export function parseDescription(html) {
  const lines = htmlToLines(html);
  const facts = [];
  const paragraphs = [];
  let sobrePedido = false;
  for (const line of lines) {
    if (/sobre pedido/i.test(line)) {
      sobrePedido = true;
      continue;
    }
    const match = line.match(/^([^:]{2,32}):\s*(.*)$/);
    const label = match ? FACT_LABELS.get(fold(match[1])) : FACT_LABELS.get(fold(line));
    if (match && label) {
      if (match[2]) facts.push({ label, value: match[2].replace(/\s*×\s*/g, ' × ') });
      continue;
    }
    if (label === 'Incluye correa crossbody') {
      facts.push({ label, value: 'Sí' });
      continue;
    }
    if (label) continue; // A bare heading such as "Medidas".
    paragraphs.push(line);
  }
  // Group the loose Alto/Ancho/Largo rows under one "Medidas" fact.
  const dims = facts.filter((fact) => ['Alto', 'Ancho', 'Largo'].includes(fact.label));
  const rest = facts.filter((fact) => !['Alto', 'Ancho', 'Largo'].includes(fact.label));
  if (dims.length > 0 && !rest.some((fact) => fact.label === 'Medidas')) {
    rest.push({ label: 'Medidas', value: dims.map((fact) => `${fact.label} ${fact.value}`).join(' × ') });
  }
  return { facts: dedupeFacts(rest), paragraphs, sobrePedido };
}

function dedupeFacts(facts) {
  const seen = new Set();
  return facts.filter((fact) => {
    const key = fact.label;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function money(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number.toFixed(2) : null;
}

function optionLabel(name) {
  const folded = fold(name).replace(/[^a-z ]/g, '').trim();
  if (folded === 'title') return null;
  if (folded.includes('color')) return 'Color';
  return name.replace(/[^\p{L}\p{N} ]/gu, '').trim() || 'Opción';
}

function imagePath(handle, index) {
  return `/media/products/${handle}/${index + 1}.webp`;
}

function cdnUrl(src) {
  const url = new URL(src);
  url.searchParams.set('width', String(IMAGE_WIDTH));
  return url.toString();
}

async function exists(file) {
  try {
    await stat(file);
    return true;
  } catch {
    return false;
  }
}

async function main() {
  const download = process.argv.includes('--download');
  const source = JSON.parse(await readFile(path.join(root, SOURCE), 'utf8'));
  const rules = JSON.parse(await readFile(path.join(root, RULES), 'utf8'));
  const brands = compileVocabulary({ ...rules.brands, ...EXTRA_BRANDS });
  const categories = compileVocabulary(rules.categories);
  const silhouettes = compileVocabulary(rules.silhouettes);
  const colors = compileVocabulary(rules.colors);
  const patterns = compileVocabulary(rules.patterns);
  const storeVendors = new Set(rules.storeVendorAliases.map(fold));
  const captured = new Date(`${CAPTURE_DATE}T12:00:00-06:00`);

  const normalized = source.products.map((raw) => {
    const vendor = raw.vendor.trim();
    const vendorTier = storeVendors.has(fold(vendor)) ? [] : [vendor];
    const brand = resolveSingle(brands, [raw.tags, [raw.title], vendorTier]);
    const titleNoun = TITLE_CATEGORY.find(([re]) => re.test(fold(raw.title)))?.[1];
    const category =
      titleNoun ?? resolveSingle(categories, [raw.tags, [raw.product_type], [raw.title]], CATEGORY_PRIORITY) ?? 'bolsa';
    const silhouette =
      category === 'bolsa'
        ? resolveSingle(silhouettes, [raw.tags, [raw.product_type], [raw.title]], SILHOUETTE_PRIORITY)
        : null;
    const options = raw.options
      .map((option) => ({ name: optionLabel(option.name), values: option.values }))
      .filter((option) => option.name);
    const variantColors = options.length
      ? [...new Set(raw.variants.flatMap((variant) => resolveMany(colors, [[String(variant.option1 ?? '').split('/')[0]]])))]
      : [];
    const productColors = variantColors.length
      ? variantColors
      : resolveMany(colors, [raw.tags, [raw.title]]);
    const description = parseDescription(raw.body_html);
    const synthetic = SYNTHETIC[raw.handle] ?? null;

    const gallerySources = [];
    const add = (src) => {
      if (src && !gallerySources.includes(src)) gallerySources.push(src);
    };
    // Variant photos first so a selected colour always has its own picture.
    raw.variants.forEach((variant) => add(variant.featured_image?.src));
    raw.images.forEach((image) => add(image.src));
    const productImageOrder = raw.images.map((image) => image.src).filter((src) => gallerySources.includes(src));
    const ordered = [...new Set([...productImageOrder.slice(0, 1), ...gallerySources])].slice(
      0,
      Math.max(MAX_IMAGES, raw.variants.filter((variant) => variant.featured_image).length + 1),
    );

    const variants = raw.variants.map((variant) => {
      const featured = variant.featured_image?.src;
      return {
        id: variant.id,
        title: variant.title === 'Default Title' ? null : variant.title,
        options: [variant.option1, variant.option2, variant.option3].filter((value) => value && value !== 'Default Title'),
        price: money(variant.price),
        compareAtPrice: money(variant.compare_at_price),
        available: synthetic?.soldOut ? false : Boolean(variant.available),
        image: featured && ordered.includes(featured) ? ordered.indexOf(featured) : 0,
        ...(synthetic?.inventoryLimit ? { inventoryLimit: synthetic.inventoryLimit } : {}),
      };
    });

    const firstAvailable = variants.find((variant) => variant.available) ?? variants[0];
    const onSale = variants.some((variant) => variant.compareAtPrice && Number(variant.compareAtPrice) > Number(variant.price));
    const createdAt = new Date(raw.created_at);
    return {
      raw,
      id: raw.id,
      handle: raw.handle,
      title: raw.title.replace(/\s+/g, ' ').trim(),
      vendor,
      productType: raw.product_type,
      tags: raw.tags,
      brand,
      brandLabel: BRAND_LABELS[brand] ?? (vendorTier[0] || 'Monetta'),
      category,
      silhouette,
      colors: productColors,
      patterns: resolveMany(patterns, [raw.tags, [raw.title]]),
      flags: {
        onSale,
        sobrePedido: description.sobrePedido,
        envioInmediato: raw.tags.includes('Envío inmediato'),
        newArrival: (captured - createdAt) / 86400000 <= rules.newArrivalDays,
      },
      createdAt: raw.created_at,
      options,
      variants,
      defaultVariantId: firstAvailable.id,
      gallerySources: ordered,
      images: ordered.map((_, index) => imagePath(raw.handle, index)),
      description: { facts: description.facts, paragraphs: description.paragraphs },
      synthetic,
    };
  });

  // Curation: must-include first, then newest per brand, rotating product
  // types so each brand shows its range rather than twenty near-identical totes.
  const byHandle = new Map(normalized.map((product) => [product.handle, product]));
  const selected = new Map();
  for (const handle of MUST_INCLUDE) {
    const product = byHandle.get(handle);
    if (!product) throw new Error(`Must-include product missing from snapshot: ${handle}`);
    selected.set(handle, product);
  }
  for (const [brand, cap] of Object.entries(BRAND_CAPS)) {
    const pool = normalized
      .filter((product) => product.brand === brand && !selected.has(product.handle))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    const groups = new Map();
    for (const product of pool) {
      const key = `${product.category}:${product.silhouette ?? ''}`;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(product);
    }
    let count = [...selected.values()].filter((product) => product.brand === brand).length;
    const queues = [...groups.values()];
    while (count < cap && queues.some((queue) => queue.length)) {
      for (const queue of queues) {
        if (count >= cap) break;
        const next = queue.shift();
        if (next) {
          selected.set(next.handle, next);
          count += 1;
        }
      }
    }
  }

  const products = [...selected.values()].sort((a, b) => b.createdAt.localeCompare(a.createdAt) || a.handle.localeCompare(b.handle));
  const selectedIds = new Set(products.map((product) => product.id));
  const membership = source.collection_membership;
  const collections = COLLECTIONS.map((collection) => ({
    ...collection,
    productIds: (membership[collection.liveHandle] ?? []).filter((id) => selectedIds.has(id)),
    liveCount: (membership[collection.liveHandle] ?? []).length,
  }));

  const catalog = {
    capturedAt: source._captured_at,
    source: 'https://monetta.mx/products.json (snapshot público)',
    note: 'Datos de demostración. Precios, existencias y descripciones son una foto fechada, no una garantía en vivo.',
    totalLiveProducts: source.products.length,
    collections: collections.map(({ liveHandle, ...rest }) => rest),
    products: products.map(({ raw, gallerySources, ...product }) => product),
  };

  const manifest = {
    generatedBy: 'scripts/build-fixtures.mjs',
    capturedAt: source._captured_at,
    sources: {
      products: source._source,
      collections: source._collections_source,
      membership: source._collection_membership_source,
      rules: 'assets/rules/normalization_rules.json (app repository, copied to fixtures/source/)',
    },
    selection: { count: products.length, liveCount: source.products.length, mustInclude: MUST_INCLUDE, brandCaps: BRAND_CAPS },
    synthetic: Object.entries(SYNTHETIC).map(([handle, value]) => ({ handle, ...value })),
    images: products.flatMap((product) =>
      product.gallerySources.map((src, index) => ({
        file: `public${imagePath(product.handle, index)}`,
        source: cdnUrl(src),
        product: product.handle,
      })),
    ),
  };

  await mkdir(path.join(root, path.dirname(OUT_CATALOG)), { recursive: true });
  await writeFile(path.join(root, OUT_CATALOG), `${JSON.stringify(catalog, null, 1)}\n`);
  await writeFile(path.join(root, OUT_MANIFEST), `${JSON.stringify(manifest, null, 2)}\n`);

  const summary = {
    products: products.length,
    images: manifest.images.length,
    brands: Object.fromEntries([...new Set(products.map((p) => p.brandLabel))].map((b) => [b, products.filter((p) => p.brandLabel === b).length])),
    categories: Object.fromEntries([...new Set(products.map((p) => p.category))].map((c) => [c, products.filter((p) => p.category === c).length])),
    silhouettes: Object.fromEntries([...new Set(products.map((p) => p.silhouette))].map((s) => [s, products.filter((p) => p.silhouette === s).length])),
    noColor: products.filter((p) => p.colors.length === 0).map((p) => p.title),
    onSale: products.filter((p) => p.flags.onSale).length,
    sobrePedido: products.filter((p) => p.flags.sobrePedido).length,
    envioInmediato: products.filter((p) => p.flags.envioInmediato).length,
    multiVariant: products.filter((p) => p.variants.length > 1).length,
    collections: Object.fromEntries(collections.map((c) => [c.handle, c.productIds.length])),
  };
  console.log(JSON.stringify(summary, null, 2));

  if (download) {
    let fetched = 0;
    for (const image of manifest.images) {
      const target = path.join(root, image.file);
      if (await exists(target)) continue;
      await mkdir(path.dirname(target), { recursive: true });
      const response = await fetch(image.source, { headers: { Accept: 'image/webp,image/*;q=0.8' } });
      if (!response.ok) throw new Error(`${response.status} ${image.source}`);
      const type = response.headers.get('content-type') ?? '';
      if (!type.includes('webp')) throw new Error(`Expected WebP, got ${type} for ${image.source}`);
      await writeFile(target, Buffer.from(await response.arrayBuffer()));
      fetched += 1;
    }
    console.log(`Downloaded ${fetched} new images.`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  await main();
}
