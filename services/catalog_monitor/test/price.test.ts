import { describe, expect, it } from 'vitest';
import { parsePriceUsd } from '../src/parsing/price.js';

describe('parsePriceUsd', () => {
  it.each([
    ['$350.00', 350],
    ['350.00', 350],
    ['$1,250.00', 1250],
    ['1,250', 1250],
    ['US$99.99', 99.99],
    ['USD 99.99', 99.99],
    [99.99, 99.99],
    [0, 0],
  ])('parses %p as %p', (input, expected) => {
    expect(parsePriceUsd(input)).toBe(expected);
  });

  it.each([
    [null],
    [undefined],
    [''],
    ['   '],
    ['€99,00'], // European-style, ambiguous decimal comma — never guess
    ['1.234,56'], // same ambiguity, no currency marker
    ['£120.00'],
    ['¥1200'],
    ['not a price'],
    [-10],
    ['-10.00'],
    ['10.999'], // three decimal places is not a valid USD amount
    ['1,25'], // two-digit group is not a valid US thousands group
  ])('rejects %p rather than guess', (input) => {
    expect(parsePriceUsd(input as never)).toBeNull();
  });

  it('rounds to two decimal places', () => {
    expect(parsePriceUsd(19.999)).toBe(20);
  });
});
