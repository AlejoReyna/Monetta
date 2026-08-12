import { describe, expect, it } from 'vitest';
import { coachAdapter } from '../src/adapters/coach.js';
import { validateFetchedMarket } from '../src/crawl/marketGuard.js';

const productUrl = 'https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html';

describe('validateFetchedMarket', () => {
  it('accepts an unchanged US product URL', () => {
    expect(validateFetchedMarket(coachAdapter, productUrl, productUrl)).toEqual({
      ok: true,
      finalUrl: productUrl,
    });
  });

  it('rejects a redirect to the Mexico storefront', () => {
    expect(
      validateFetchedMarket(
        coachAdapter,
        productUrl,
        'https://mx.coach.com/es_MX/productos/bolso.html',
      ),
    ).toEqual({ ok: false, reason: 'wrong_market' });
  });

  it('rejects a same-brand non-product landing page', () => {
    expect(
      validateFetchedMarket(coachAdapter, productUrl, 'https://www.coach.com/'),
    ).toEqual({ ok: false, reason: 'wrong_market' });
  });

  it('rejects non-HTTPS final URLs', () => {
    expect(
      validateFetchedMarket(
        coachAdapter,
        productUrl,
        'http://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html',
      ),
    ).toEqual({ ok: false, reason: 'wrong_market' });
  });
});
