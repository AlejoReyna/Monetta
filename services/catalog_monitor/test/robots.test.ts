import { describe, expect, it } from 'vitest';
import { isAllowedByRobots, parseRobotsTxt } from '../src/robots/robotsTxt.js';
import { readFixture } from './support/fixtures.js';

const mkRobotsTxt = readFixture('michael_kors/robots.txt');

describe('parseRobotsTxt + isAllowedByRobots (michaelkors.com sanitized fixture)', () => {
  const rules = parseRobotsTxt(mkRobotsTxt);

  it('disallows account, cart and wishlist paths', () => {
    expect(isAllowedByRobots(rules, '/account/orders')).toBe(false);
    expect(isAllowedByRobots(rules, '/cart/')).toBe(false);
    expect(isAllowedByRobots(rules, '/wishlist/')).toBe(false);
    expect(isAllowedByRobots(rules, '/Product-ShowQuickView')).toBe(false);
  });

  it('disallows demandware private endpoints via the wildcard rule', () => {
    expect(
      isAllowedByRobots(rules, '/on/demandware.store/Sites-MK_US-Site/default/Cart-AddProduct'),
    ).toBe(false);
  });

  it('allows an ordinary product-detail path', () => {
    expect(
      isAllowedByRobots(rules, '/14k-gold-plated-sterling-silver-pave-alphabet-charm/MKC1096AN.html'),
    ).toBe(true);
  });

  it('does not apply a disallow rule scoped to a different user agent', () => {
    // `/product/` is disallowed only for the "botify" agent, not "*".
    expect(isAllowedByRobots(rules, '/product/anything')).toBe(true);
  });
});
