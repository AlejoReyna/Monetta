import { describe, expect, it } from 'vitest';
import { extractProduct } from '../src/parsing/productExtractor.js';
import { extractProductFromJsonLd } from '../src/parsing/jsonld.js';
import { coachAdapter } from '../src/adapters/coach.js';
import { readFixture } from './support/fixtures.js';

const selectors = coachAdapter.selectors;
const base = { canonicalUrl: 'https://www.coach.com/x/C0000.html', externalId: 'C0000', fallbackBrand: 'Coach', selectors };

describe('extractProduct priority', () => {
  it('prefers JSON-LD when it has every required field', () => {
    const html = readFixture('coach/product_jsonld.html');
    const result = extractProduct(html, base);
    expect(result.method).toBe('jsonld');
    expect(result.complete).toBe(true);
    expect(result.product).toMatchObject({
      title: 'Tabby Shoulder Bag 26',
      brand: 'Coach',
      category: 'Handbags',
      priceUsd: 350,
      availability: 'inStock',
    });
  });

  it('falls back to Open Graph / product metadata when there is no JSON-LD', () => {
    const html = readFixture('coach/product_metadata_only.html');
    const result = extractProduct(html, base);
    expect(result.method).toBe('metadata');
    expect(result.complete).toBe(true);
    expect(result.product).toMatchObject({
      title: 'Pillow Tabby Crossbody',
      priceUsd: 295,
      availability: 'inStock',
      category: 'Crossbody Bags',
    });
  });

  it('falls back to adapter selectors when there is neither JSON-LD nor metadata', () => {
    const html = readFixture('coach/product_selectors_only.html');
    const result = extractProduct(html, base);
    expect(result.method).toBe('selectors');
    expect(result.complete).toBe(true);
    expect(result.product).toMatchObject({
      title: 'Rowan Satchel',
      priceUsd: 428,
      availability: 'inStock',
    });
  });

  it('tolerates malformed JSON-LD and falls through to metadata', () => {
    const html = readFixture('coach/product_malformed.html');
    const result = extractProduct(html, base);
    expect(result.method).toBe('metadata');
    expect(result.complete).toBe(true);
    expect(result.product?.priceUsd).toBe(199);
  });

  it('reports incomplete extraction when no tier has every required field', () => {
    const html = readFixture('coach/product_missing_fields.html');
    const result = extractProduct(html, base);
    expect(result.complete).toBe(false);
    expect(result.product?.priceUsd).toBeNull();
  });

  it('picks the current sale price, not a struck-through original price', () => {
    const html = readFixture('coach/product_sale_price.html');
    const result = extractProduct(html, base);
    expect(result.complete).toBe(true);
    expect(result.product?.priceUsd).toBe(149);
  });

  it('reports outOfStock availability for an unavailable product', () => {
    const html = readFixture('coach/product_unavailable.html');
    const result = extractProduct(html, base);
    expect(result.complete).toBe(true);
    expect(result.product?.availability).toBe('outOfStock');
  });
});

describe('extractProductFromJsonLd currency guard', () => {
  it('refuses to treat a non-USD offer price as a USD price', () => {
    const html = `<script type="application/ld+json">${JSON.stringify({
      '@type': 'Product',
      name: 'Euro Priced Bag',
      brand: 'Coach',
      offers: { price: '99.00', priceCurrency: 'EUR' },
    })}</script>`;
    const result = extractProductFromJsonLd(html, 'Coach');
    expect(result?.priceUsd).toBeNull();
  });

  it('returns null when there is no Product node at all', () => {
    expect(extractProductFromJsonLd('<html></html>', 'Coach')).toBeNull();
  });
});
