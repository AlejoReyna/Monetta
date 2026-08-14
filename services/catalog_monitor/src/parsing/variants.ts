import * as cheerio from 'cheerio';
import { parsePriceUsd } from './price.js';
import type {
  Availability,
  ExtractedProductVariant,
} from '../domain/types.js';

interface VariantDefaults {
  readonly externalId: string;
  readonly canonicalUrl: string;
  readonly imageUrl: string | null;
  readonly priceUsd: number | null;
  readonly availability: Availability;
}

function nonEmptyString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed === '' ? null : trimmed;
}

function firstString(
  object: Record<string, unknown>,
  keys: readonly string[],
): string | null {
  for (const key of keys) {
    const value = nonEmptyString(object[key]);
    if (value) return value;
  }
  return null;
}

function nestedString(value: unknown): string | null {
  const direct = nonEmptyString(value);
  if (direct) return direct;
  if (Array.isArray(value)) {
    for (const item of value) {
      const candidate = nestedString(item);
      if (candidate) return candidate;
    }
  }
  if (value && typeof value === 'object') {
    return firstString(value as Record<string, unknown>, [
      'url',
      'src',
      'large',
      'medium',
      'value',
    ]);
  }
  return null;
}

function priceFromUnknown(value: unknown): number | null {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  const direct = nonEmptyString(value);
  if (direct) return parsePriceUsd(direct);
  if (value && typeof value === 'object') {
    const object = value as Record<string, unknown>;
    for (const key of ['sales', 'current', 'value', 'amount', 'price']) {
      const parsed = priceFromUnknown(object[key]);
      if (parsed !== null) return parsed;
    }
  }
  return null;
}

function availabilityFromUnknown(
  value: unknown,
  fallback: Availability,
): Availability {
  if (value === true) return 'inStock';
  if (value === false) return 'outOfStock';
  const raw = nonEmptyString(value) ?? '';
  if (/in.?stock|available|selectable/i.test(raw)) return 'inStock';
  if (/out.?of.?stock|sold.?out|unavailable|disabled/i.test(raw)) {
    return 'outOfStock';
  }
  return fallback;
}

function absoluteMerchantUrl(raw: string | null, canonicalUrl: string): string {
  if (!raw) return canonicalUrl;
  try {
    const resolved = new URL(raw, canonicalUrl);
    const canonical = new URL(canonicalUrl);
    if (resolved.protocol !== 'https:' || resolved.hostname !== canonical.hostname) {
      return canonicalUrl;
    }
    return resolved.toString();
  } catch {
    return canonicalUrl;
  }
}

function cleanColorName(raw: string | null): string | null {
  if (!raw) return null;
  const cleaned = raw
    .replace(/^(select|choose)\s+(a\s+)?colou?r[:\s-]*/i, '')
    .replace(/\s+(selected|unavailable)$/i, '')
    .trim();
  return cleaned || null;
}

/**
 * Extracts color choices from the two common shapes used by Coach/MK:
 * embedded JSON variation data and SFCC-style color swatch elements. It is
 * deliberately key-based rather than brand-text-based so the same parser can
 * tolerate storefront markup changes and can be exercised with sanitized
 * fixtures.
 */
export function extractProductVariants(
  html: string,
  defaults: VariantDefaults,
): ExtractedProductVariant[] {
  const $ = cheerio.load(html);
  const byId = new Map<string, ExtractedProductVariant>();

  const add = (candidate: {
    variantId?: string | null;
    sku?: string | null;
    colorName?: string | null;
    colorCode?: string | null;
    imageUrl?: string | null;
    priceUsd?: number | null;
    availability?: Availability;
    detailUrl?: string | null;
  }): void => {
    const colorName = cleanColorName(candidate.colorName ?? null);
    const colorCode = nonEmptyString(candidate.colorCode) ?? null;
    const sku = nonEmptyString(candidate.sku) ?? null;
    const variantId =
      nonEmptyString(candidate.variantId) ??
      sku ??
      (colorCode ? `${defaults.externalId}:${colorCode}` : null) ??
      (colorName ? `${defaults.externalId}:${colorName.toLowerCase()}` : null);
    if (!variantId) return;

    const next: ExtractedProductVariant = {
      variantId,
      sku,
      colorName,
      colorCode,
      imageUrl: nonEmptyString(candidate.imageUrl) ?? defaults.imageUrl,
      priceUsd: candidate.priceUsd ?? defaults.priceUsd,
      availability: candidate.availability ?? defaults.availability,
      detailUrl: absoluteMerchantUrl(candidate.detailUrl ?? null, defaults.canonicalUrl),
    };
    const previous = byId.get(variantId);
    byId.set(variantId, previous ? preferFilled(previous, next) : next);
  };

  const visitJson = (node: unknown, parentKey = ''): void => {
    if (Array.isArray(node)) {
      node.forEach((item) => visitJson(item, parentKey));
      return;
    }
    if (!node || typeof node !== 'object') return;
    const object = node as Record<string, unknown>;
    const explicitColorName = firstString(object, [
      'colorName',
      'colourName',
      'color_name',
      'colour_name',
    ]);
    const explicitColorCode = firstString(object, [
      'colorCode',
      'colourCode',
      'color_code',
      'colour_code',
      'colorId',
    ]);
    const colorContext = /colou?r|swatch|variation/i.test(parentKey);
    const contextualName = colorContext
      ? firstString(object, ['displayValue', 'displayName', 'label', 'name'])
      : null;
    const contextualCode = colorContext
      ? firstString(object, ['value', 'id', 'code'])
      : null;
    const colorName = explicitColorName ?? contextualName;
    const colorCode = explicitColorCode ?? contextualCode;

    if (colorName || colorCode) {
      const sku = firstString(object, ['sku', 'SKU', 'productId', 'pid']);
      const id = firstString(object, ['variantId', 'variant_id', 'id']);
      const image = nestedString(
        object.imageUrl ?? object.image ?? object.images ?? object.swatchImage,
      );
      const detailUrl = firstString(object, [
        'detailUrl',
        'productUrl',
        'url',
        'href',
      ]);
      const availabilityValue =
        object.availableForSale ??
        object.available ??
        object.selectable ??
        object.availability;
      add({
        variantId: id ?? sku,
        sku,
        colorName,
        colorCode,
        imageUrl: image,
        priceUsd: priceFromUnknown(
          object.salesPrice ?? object.currentPrice ?? object.price,
        ),
        availability: availabilityFromUnknown(
          availabilityValue,
          defaults.availability,
        ),
        detailUrl,
      });
    }

    for (const [key, value] of Object.entries(object)) visitJson(value, key);
  };

  $('script[type="application/json"], script[type="application/ld+json"]').each(
    (_, element) => {
      try {
        visitJson(JSON.parse($(element).contents().text()));
      } catch {
        // One malformed block must not hide valid swatches elsewhere.
      }
    },
  );

  const swatchSelector = [
    '[data-color-code]',
    '[data-color-name]',
    '[data-attribute-id="color"] [data-attr-value]',
    '[data-attr="color"] [data-attr-value]',
    '.color-attribute [data-attr-value]',
  ].join(', ');

  $(swatchSelector).each((_, element) => {
    const swatch = $(element);
    const image = swatch.find('img').first();
    const className = swatch.attr('class') ?? '';
    add({
      variantId:
        swatch.attr('data-variant-id') ??
        swatch.attr('data-pid') ??
        swatch.attr('data-product-id'),
      sku: swatch.attr('data-sku'),
      colorName:
        swatch.attr('data-color-name') ??
        swatch.attr('data-display-value') ??
        swatch.attr('aria-label') ??
        swatch.attr('title') ??
        image.attr('alt'),
      colorCode:
        swatch.attr('data-color-code') ??
        swatch.attr('data-color') ??
        swatch.attr('data-attr-value'),
      imageUrl:
        swatch.attr('data-image-url') ??
        image.attr('data-src') ??
        image.attr('src'),
      priceUsd: priceFromUnknown(swatch.attr('data-price')),
      availability:
        swatch.is('[disabled]') ||
        swatch.attr('aria-disabled') === 'true' ||
        /unavailable|disabled|sold-out/i.test(className)
          ? 'outOfStock'
          : defaults.availability,
      detailUrl:
        swatch.attr('data-url') ?? swatch.attr('href') ?? undefined,
    });
  });

  // A page may expose only the currently selected color. Preserve it as a
  // real variant so price/stock changes are still tracked at color level.
  if (byId.size === 0) {
    const currentColor =
      $('meta[property="product:color"]').attr('content') ??
      $('[data-selected-color]').first().attr('data-selected-color') ??
      $('[data-color-name].selected, [data-color-name][aria-checked="true"]')
        .first()
        .attr('data-color-name');
    add({
      variantId: `${defaults.externalId}:default`,
      sku: defaults.externalId,
      colorName: currentColor,
    });
  }

  return [...byId.values()].sort((a, b) => a.variantId.localeCompare(b.variantId));
}

function preferFilled(
  previous: ExtractedProductVariant,
  next: ExtractedProductVariant,
): ExtractedProductVariant {
  return {
    variantId: previous.variantId,
    sku: next.sku ?? previous.sku,
    colorName: next.colorName ?? previous.colorName,
    colorCode: next.colorCode ?? previous.colorCode,
    imageUrl: next.imageUrl ?? previous.imageUrl,
    priceUsd: next.priceUsd ?? previous.priceUsd,
    availability:
      next.availability === 'unknown' ? previous.availability : next.availability,
    detailUrl: next.detailUrl || previous.detailUrl,
  };
}
