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

describe('color variant extraction', () => {
  it('extracts Coach/MK-style embedded color variations with independent commerce fields', () => {
    const html = `
      <script type="application/ld+json">${JSON.stringify({
        '@type': 'Product',
        name: 'Brooklyn Shoulder Bag 28',
        brand: 'Coach',
        category: 'Handbags',
        image: 'https://coach.scene7.com/is/image/Coach/cu068_b4bk_a0',
        offers: {
          price: '295',
          priceCurrency: 'USD',
          availability: 'https://schema.org/InStock',
        },
      })}</script>
      <script type="application/json">${JSON.stringify({
        colorVariations: [
          {
            id: 'CU068:B4BK',
            sku: 'CU068 B4/BK',
            displayValue: 'Brass/Black',
            value: 'B4BK',
            image: { url: 'https://coach.scene7.com/is/image/Coach/cu068_b4bk_a0' },
            price: { sales: { value: 295 } },
            available: true,
            url: '/products/brooklyn-shoulder-bag-28/CU068-B4%2FBK.html',
          },
          {
            id: 'CU068:B4TF',
            sku: 'CU068 B4/TF',
            displayValue: 'Brass/Toffee',
            value: 'B4TF',
            price: { sales: { value: 206.5 } },
            available: false,
            url: '/products/brooklyn-shoulder-bag-28/CU068%20B4%2FTF.html',
          },
        ],
      })}</script>`;

    const result = extractProduct(html, {
      ...base,
      canonicalUrl: 'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068.html',
      externalId: 'CU068',
    });

    expect(result.complete).toBe(true);
    expect(result.product?.variants).toHaveLength(2);
    expect(result.product?.variants).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          variantId: 'CU068:B4BK',
          colorName: 'Brass/Black',
          colorCode: 'B4BK',
          priceUsd: 295,
          availability: 'inStock',
        }),
        expect.objectContaining({
          variantId: 'CU068:B4TF',
          colorName: 'Brass/Toffee',
          priceUsd: 206.5,
          availability: 'outOfStock',
        }),
      ]),
    );
  });
});
