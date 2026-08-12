import { describe, expect, it } from 'vitest';
import { coachAdapter } from '../src/adapters/coach.js';
import { guessAdapter } from '../src/adapters/guess.js';
import { michaelKorsAdapter } from '../src/adapters/michaelKors.js';
import { steveMaddenAdapter } from '../src/adapters/steveMadden.js';

describe('coachAdapter.isProductUrl', () => {
  it.each([
    'https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html',
    'https://www.coach.com/products/tabby-shoulder-bag-26/CI032-B4YDT.html',
  ])('accepts real product-detail URL shape %s', (url) => {
    expect(coachAdapter.isProductUrl(url)).toBe(true);
  });

  it('accepts percent-encoded variant identifiers without throwing', () => {
    const url = 'https://www.coach.com/products/tabby-shoulder-bag-26/CEN52-B4%20YDT.html';
    expect(() => coachAdapter.isProductUrl(url)).not.toThrow();
    expect(coachAdapter.isProductUrl(url)).toBe(true);
    expect(() => coachAdapter.externalIdFromUrl(url)).not.toThrow();
    expect(coachAdapter.externalIdFromUrl(url)).toBe('CEN52-B4-YDT');
  });

  it.each([
    'https://www.coach.com/search/results',
    'https://www.coach.com/checkout/cart',
    'https://www.coach.com/account/wishlist',
    'https://www.coach.com/cart/add',
    'https://www.coach.com/wishlist/1234',
    'https://www.coach.com/handbags',
    'https://www.coach.com/on/demandware.store/Sites-coach-Site/default/Product-Variation',
    // Old invented `/{slug}/{style}.html` shape — not present in any
    // captured product sitemap, so it must not be treated as a product URL.
    'https://www.coach.com/tabby-shoulder-bag-26/CEN52.html',
  ])('rejects excluded, non-product, or unverified-shape path %s', (url) => {
    expect(coachAdapter.isProductUrl(url)).toBe(false);
  });

  it('rejects a Coach-shaped path hosted by a different domain', () => {
    expect(
      coachAdapter.isProductUrl('https://www.michaelkors.com/products/tabby-shoulder-bag-26/CEN52.html'),
    ).toBe(false);
    expect(
      coachAdapter.isProductUrl('https://coach.com.evil.example/products/tabby-shoulder-bag-26/CEN52.html'),
    ).toBe(false);
  });

  it('rejects a non-HTTPS scheme', () => {
    expect(
      coachAdapter.isProductUrl('http://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html'),
    ).toBe(false);
  });

  it('derives a stable, normalized source identifier from the final .html path segment', () => {
    expect(
      coachAdapter.externalIdFromUrl('https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html'),
    ).toBe('CEN52');
    expect(
      coachAdapter.externalIdFromUrl(
        'https://www.coach.com/products/tabby-shoulder-bag-26/CI032-B4YDT.html',
      ),
    ).toBe('CI032-B4YDT');
  });

  it('returns null for a URL on a different domain', () => {
    expect(
      coachAdapter.externalIdFromUrl('https://www.michaelkors.com/products/x/CEN52.html'),
    ).toBeNull();
  });
});

describe('michaelKorsAdapter.isProductUrl', () => {
  it.each([
    'https://www.michaelkors.com/14k-gold-plated-sterling-silver-pave-alphabet-charm/MKC1096AN.html',
    'https://www.michaelkors.com/product/scoop-back-swimsuit/_/R-US_MM1Q843',
  ])('accepts real product-detail URL shape %s', (url) => {
    expect(michaelKorsAdapter.isProductUrl(url)).toBe(true);
  });

  it.each([
    'https://www.michaelkors.com/Product-ShowQuickView?pid=193256767226',
    'https://www.michaelkors.com/wishlist/add',
    'https://www.michaelkors.com/cart',
    'https://www.michaelkors.com/search?q=bag',
    'https://www.michaelkors.com/on/demandware.store/Sites-MK_US-Site/default/Cart-AddProduct',
  ])('rejects excluded or non-product path %s', (url) => {
    expect(michaelKorsAdapter.isProductUrl(url)).toBe(false);
  });

  it('rejects an identical-looking path hosted by a different domain', () => {
    expect(
      michaelKorsAdapter.isProductUrl(
        'https://www.coach.com/14k-gold-plated-sterling-silver-pave-alphabet-charm/MKC1096AN.html',
      ),
    ).toBe(false);
    expect(
      michaelKorsAdapter.isProductUrl(
        'https://michaelkors.com.evil.example/product/scoop-back-swimsuit/_/R-US_MM1Q843',
      ),
    ).toBe(false);
  });

  it('rejects a non-HTTPS scheme', () => {
    expect(
      michaelKorsAdapter.isProductUrl(
        'http://www.michaelkors.com/14k-gold-plated-sterling-silver-pave-alphabet-charm/MKC1096AN.html',
      ),
    ).toBe(false);
  });

  it('normalizes the legacy .html shape to a stable source identifier', () => {
    expect(
      michaelKorsAdapter.externalIdFromUrl(
        'https://www.michaelkors.com/14k-gold-plated-sterling-silver-pave-alphabet-charm/MKC1096AN.html',
      ),
    ).toBe('MKC1096AN');
  });

  it('normalizes the /product/.../R-US_ shape to a stable source identifier', () => {
    expect(
      michaelKorsAdapter.externalIdFromUrl(
        'https://www.michaelkors.com/product/scoop-back-swimsuit/_/R-US_MM1Q843',
      ),
    ).toBe('MM1Q843');
  });

  it('returns null for a URL on a different domain', () => {
    expect(
      michaelKorsAdapter.externalIdFromUrl(
        'https://www.coach.com/product/scoop-back-swimsuit/_/R-US_MM1Q843',
      ),
    ).toBeNull();
  });
});

describe('guessAdapter.isProductUrl', () => {
  it.each([
    'https://www.guess.com/en-us/noelle-shoulder-bag-brown/BS967218-LLU.html',
    'https://www.guess.com/us/en/handbags/all-handbags/satchels/elowen-satchel-brown/BG992506-ESP.html',
  ])('accepts a verified US product-detail URL %s', (url) => {
    expect(guessAdapter.isProductUrl(url)).toBe(true);
  });

  it.each([
    'https://www.guess.com/en-us/guess/women/bags',
    'https://www.guess.com/en-us/shoppingbag',
    'https://www.guess.com/en-us/legal/privacy-policy.html',
    'https://www.guess.com/mx/es/mujer/bolsos/producto/BS967218-LLU.html',
    'https://guess.com.evil.example/en-us/noelle-bag/BS967218-LLU.html',
    'http://www.guess.com/en-us/noelle-bag/BS967218-LLU.html',
  ])('rejects a non-product, wrong-market, spoofed, or non-HTTPS URL %s', (url) => {
    expect(guessAdapter.isProductUrl(url)).toBe(false);
  });

  it('derives the color/style identifier from the final path segment', () => {
    expect(
      guessAdapter.externalIdFromUrl(
        'https://www.guess.com/en-us/guess/women/bags/handbags/maxine-shoulder-bag-black/QG973320-BLA.html',
      ),
    ).toBe('QG973320-BLA');
  });
});

describe('steveMaddenAdapter.isProductUrl', () => {
  it.each([
    'https://www.stevemadden.com/products/bmakia-black',
    'https://stevemadden.com/products/briggs-banana-leather/',
  ])('accepts a verified product-detail URL %s', (url) => {
    expect(steveMaddenAdapter.isProductUrl(url)).toBe(true);
  });

  it.each([
    'https://www.stevemadden.com/collections/all-handbags',
    'https://www.stevemadden.com/cart',
    'https://stevemadden.com.evil.example/products/bmakia-black',
    'http://www.stevemadden.com/products/bmakia-black',
  ])('rejects a collection, excluded, spoofed, or non-HTTPS URL %s', (url) => {
    expect(steveMaddenAdapter.isProductUrl(url)).toBe(false);
  });

  it('normalizes the Shopify product handle to a stable source identifier', () => {
    expect(
      steveMaddenAdapter.externalIdFromUrl(
        'https://www.stevemadden.com/products/bjuliana-black-patent?variant=123',
      ),
    ).toBe('BJULIANA-BLACK-PATENT');
  });
});
