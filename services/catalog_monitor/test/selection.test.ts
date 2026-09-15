import { createHash } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  compileSelection,
  isSelectionError,
  parseSelectionDocument,
  type MinimalProduct,
  type SelectionDocument,
} from '../src/selection/index.js';
import { compileGlobToRegExp, validateGlobPattern } from '../src/selection/glob.js';
import { matchExternalIdInUrl } from '../src/selection/engine.js';
import {
  canonicalJsonStringify,
  canonicalizeValue,
  hashSelectionDocument,
  sha256Hex,
} from '../src/selection/hash.js';

describe('WP-11 Selection Engine', () => {
  describe('1. Precedence: pinned include beats a matching exclusion', () => {
    it('selects candidate when pinned include matches despite a broad exclude', () => {
      const parsed = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'coach-tabby-pin',
                kind: 'urlPattern',
                value: '/products/*tabby*',
                tier: 'pinned',
                placements: ['home_rail'],
                priority: 50,
              },
            ],
            exclude: [
              {
                id: 'coach-exclude-all-products',
                kind: 'urlPattern',
                value: '/products/**',
              },
            ],
          },
        },
      });

      expect(isSelectionError(parsed)).toBe(false);
      const compiled = compileSelection(parsed as SelectionDocument);

      const decision = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/products/tabby-bag.html'
      );

      expect(decision.selected).toBe(true);
      if (decision.selected) {
        expect(decision.ruleId).toBe('coach-tabby-pin');
        expect(decision.tier).toBe('pinned');
        expect(decision.priority).toBe(50);
        expect(decision.placements).toEqual(['home_rail']);
      }
    });

    it('pinned include beats exclude in matchProduct as well', () => {
      const parsed = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'pin-cu068',
                kind: 'externalId',
                value: 'CU068',
                tier: 'pinned',
                placements: ['catalog_browse'],
              },
            ],
            exclude: [
              {
                id: 'exclude-bags',
                kind: 'category',
                value: 'Handbags',
              },
            ],
          },
        },
      });

      const compiled = compileSelection(parsed as SelectionDocument);
      const product: MinimalProduct = {
        externalId: 'CU068',
        canonicalUrl: 'https://www.coach.com/products/tabby/CU068.html',
        title: 'Tabby Shoulder Bag',
        category: 'Handbags',
        priceUsd: 450,
        availability: 'inStock',
      };

      const decision = compiled.matchProduct('coach_us', product);
      expect(decision.selected).toBe(true);
      if (decision.selected) {
        expect(decision.ruleId).toBe('pin-cu068');
        expect(decision.tier).toBe('pinned');
      }
    });
  });

  describe('2. Precedence: exclusion beats normal matching include', () => {
    it('rejects candidate when exclude matches even if normal include matches', () => {
      const parsed = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'coach-tabby-std',
                kind: 'urlPattern',
                value: '/products/*tabby*',
                tier: 'standard',
                placements: ['catalog_browse'],
              },
            ],
            exclude: [
              {
                id: 'no-mens',
                kind: 'urlPattern',
                value: '/products/*mens*',
              },
            ],
          },
        },
      });

      const compiled = compileSelection(parsed as SelectionDocument);

      const decision = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/products/mens-tabby-bag.html'
      );

      expect(decision.selected).toBe(false);
      expect(decision.ruleId).toBe('no-mens');
    });
  });

  describe('3. Zero include rules select nothing', () => {
    it('rejects every URL and product when include array is empty', () => {
      const parsed = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [],
            exclude: [],
          },
        },
      });

      const compiled = compileSelection(parsed as SelectionDocument);

      const urlDecision = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/products/tabby.html'
      );
      expect(urlDecision.selected).toBe(false);
      expect(urlDecision.reason).toBe('zero_include_rules');

      const productDecision = compiled.matchProduct('coach_us', {
        externalId: '123',
        canonicalUrl: 'https://www.coach.com/products/123.html',
        title: 'Any product',
        category: 'Bags',
        priceUsd: 100,
        availability: 'inStock',
      });
      expect(productDecision.selected).toBe(false);
      expect(productDecision.reason).toBe('zero_include_rules');
    });
  });

  describe('4. Explicit all rule selects every valid candidate for an enabled source', () => {
    it('selects any valid URL and product under kind: all', () => {
      const parsed = parseSelectionDocument({
        version: 1,
        sources: {
          kate_spade_us: {
            enabled: true,
            include: [
              {
                id: 'select-all-kate-spade',
                kind: 'all',
                placements: ['catalog_browse'],
                priority: 1,
              },
            ],
            exclude: [],
          },
        },
      });

      const compiled = compileSelection(parsed as SelectionDocument);

      const urlDecision = compiled.matchUrl(
        'kate_spade_us',
        'https://www.katespade.com/products/sam-bag/KB123.html'
      );
      expect(urlDecision.selected).toBe(true);
      if (urlDecision.selected) {
        expect(urlDecision.ruleId).toBe('select-all-kate-spade');
      }

      const prodDecision = compiled.matchProduct('kate_spade_us', {
        externalId: 'KB123',
        canonicalUrl: 'https://www.katespade.com/products/sam-bag/KB123.html',
        title: 'Sam Icon Shoulder Bag',
        category: 'Totes',
        priceUsd: 298,
        availability: 'inStock',
      });
      expect(prodDecision.selected).toBe(true);
    });

    it('all rule can be constrained by an exclude rule', () => {
      const parsed = parseSelectionDocument({
        version: 1,
        sources: {
          kate_spade_us: {
            enabled: true,
            include: [{ id: 'all-kate', kind: 'all' }],
            exclude: [
              {
                id: 'no-clearance',
                kind: 'urlPattern',
                value: '/products/*clearance*',
              },
            ],
          },
        },
      });

      const compiled = compileSelection(parsed as SelectionDocument);

      expect(
        compiled.matchUrl(
          'kate_spade_us',
          'https://www.katespade.com/products/regular.html'
        ).selected
      ).toBe(true);

      expect(
        compiled.matchUrl(
          'kate_spade_us',
          'https://www.katespade.com/products/clearance-bag.html'
        ).selected
      ).toBe(false);
    });
  });

  describe('5. Disabled and unknown sources select nothing', () => {
    it('disabled source never selects', () => {
      const parsed = parseSelectionDocument({
        version: 1,
        sources: {
          guess_us: {
            enabled: false,
            include: [{ id: 'all-guess', kind: 'all' }],
            exclude: [],
          },
        },
      });

      const compiled = compileSelection(parsed as SelectionDocument);
      const urlDecision = compiled.matchUrl(
        'guess_us',
        'https://www.guess.com/us/en/women/handbags/crossbody.html'
      );
      expect(urlDecision.selected).toBe(false);
      expect(urlDecision.reason).toBe('source_disabled');
    });

    it('unknown source never selects and does not throw', () => {
      const parsed = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [{ id: 'all-coach', kind: 'all' }],
          },
        },
      });

      const compiled = compileSelection(parsed as SelectionDocument);
      const decision = compiled.matchUrl(
        'unregistered_merchant',
        'https://www.example.com/product.html'
      );
      expect(decision.selected).toBe(false);
      expect(decision.reason).toBe('unknown_source');
    });
  });

  describe('6. Malformed documents return a typed error and never throw', () => {
    it.each([
      ['empty string', ''],
      ['whitespace only', '   \n\t  '],
      ['malformed JSON syntax', '{"version": 1, "sources": '],
      ['number', 12345],
      ['boolean', true],
      ['null', null],
      ['array', [1, 2, 3]],
      ['negative version', { version: -1, sources: {} }],
      ['fractional version', { version: 1.5, sources: {} }],
      ['missing version', { sources: {} }],
      ['missing sources', { version: 1 }],
      ['note is not a string', { version: 1, note: 42, sources: {} }],
      ['unknown root property', { version: 1, sources: {}, extra: 'bad' }],
    ])('rejects %s with a typed SelectionError', (_, input) => {
      let result: ReturnType<typeof parseSelectionDocument>;
      expect(() => {
        result = parseSelectionDocument(input);
      }).not.toThrow();

      expect(isSelectionError(result!)).toBe(true);
      if (isSelectionError(result!)) {
        expect(result!.error).toBe('selection_invalid');
        expect(typeof result!.message).toBe('string');
      }
    });
  });

  describe('7. Rejections for specific semantic violations', () => {
    it('rejects unknown source ID', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          not_a_valid_merchant: {
            enabled: true,
            include: [],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('invalid_source');
      }
    });

    it('rejects duplicate rule ID across include and exclude', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [{ id: 'rule-dup', kind: 'all' }],
            exclude: [{ id: 'rule-dup', kind: 'urlExact', value: '/products/x' }],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('duplicate_rule_id');
      }
    });

    it('rejects duplicate rule ID within include', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              { id: 'rule-1', kind: 'all' },
              { id: 'rule-1', kind: 'urlExact', value: '/products/a' },
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('duplicate_rule_id');
      }
    });

    it.each([
      ['unknown string', 'featured_rail'],
      ['empty collection slug', 'collection:'],
      ['collection slug with uppercase/space', 'collection:Summer Sale'],
      ['collection slug with slash', 'collection:foo/bar'],
      ['number in array', 123 as unknown as string],
    ])('rejects invalid placement: %s', (_, placement) => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'p1',
                kind: 'all',
                placements: [placement],
              },
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('invalid_placement');
      }
    });

    it.each([
      ['min > max', [500, 100]],
      ['negative value', [-10, 50]],
      ['non-numeric elements', ['100', '200'] as unknown as [number, number]],
      ['three elements', [10, 20, 30] as unknown as [number, number]],
      ['single element', [50] as unknown as [number, number]],
      ['NaN or Infinity', [NaN, 100]],
    ])('rejects invalid priceUsdRange: %s', (_, range) => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'price-bad',
                kind: 'priceUsdRange',
                value: range,
              },
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('invalid_price_range');
      }
    });

    it.each([
      ['empty pattern', ''],
      ['does not start with / or **', 'products/*'],
      ['triple asterisk', '/products/***tabby'],
      ['query string in glob', '/products/*?ref=home'],
      ['fragment in glob', '/products/*#hash'],
      ['whitespace in glob', '/products/ *tabby*'],
    ])('rejects invalid glob: %s', (_, glob) => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'glob-bad',
                kind: 'urlPattern',
                value: glob,
              },
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('invalid_glob');
      }
    });

    it('rejects unknown property on source object', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [],
            extraSourceField: 123,
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('unknown_key');
      }
    });

    it('rejects unknown property on rule object', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'rule-bad-key',
                kind: 'all',
                someInventedKey: true,
              },
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('unknown_key');
      }
    });

    it('rejects placements/priority/tier on an exclude rule', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [{ id: 'rule-inc', kind: 'all' }],
            exclude: [
              {
                id: 'rule-exc',
                kind: 'urlPattern',
                value: '/products/*mens*',
                tier: 'pinned', // illegal on exclude
              } as unknown as Record<string, unknown>,
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('unknown_key');
      }
    });

    it('rejects value on kind: all', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'all-rule',
                kind: 'all',
                value: 'everything',
              } as unknown as Record<string, unknown>,
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
    });

    it('rejects tier: "pinned" on Stage-B rules', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'b-pinned',
                kind: 'priceUsdRange',
                value: [100, 300],
                tier: 'pinned',
              } as unknown as Record<string, unknown>,
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('unknown_key');
      }
    });

    it('rejects tier: "pinned" on Stage-C rules', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'c-pinned',
                kind: 'availability',
                value: 'inStock',
                tier: 'pinned',
              } as unknown as Record<string, unknown>,
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('unknown_key');
      }
    });

    it('rejects placements and priority on Stage-B rules', () => {
      const res = parseSelectionDocument({
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'b-metadata',
                kind: 'titleKeyword',
                value: 'Tabby',
                placements: ['home_rail'],
                priority: 10,
              } as unknown as Record<string, unknown>,
            ],
          },
        },
      });
      expect(isSelectionError(res)).toBe(true);
      if (isSelectionError(res)) {
        expect(res.code).toBe('unknown_key');
      }
    });
  });

  describe('8. Glob semantics: * does not cross /, ** does, regex metacharacters escaped', () => {
    it('* matches zero or more non-/ characters only', () => {
      const re = compileGlobToRegExp('/products/*tabby*');

      // Matches within single path segment
      expect(re.test('/products/tabby.html')).toBe(true);
      expect(re.test('/products/leather-tabby-shoulder-bag.html')).toBe(true);
      expect(re.test('/products/tabby')).toBe(true);

      // Does NOT cross path separators
      expect(re.test('/products/sub-category/tabby.html')).toBe(false);
      expect(re.test('/products/mens/bags/tabby')).toBe(false);
    });

    it('** matches zero or more characters across / boundaries', () => {
      const re = compileGlobToRegExp('/products/**tabby*');

      expect(re.test('/products/tabby.html')).toBe(true);
      expect(re.test('/products/women/handbags/crossbody/tabby-26.html')).toBe(true);
      expect(re.test('/products/deeply/nested/path/to/my-tabby')).toBe(true);
    });

    it('regex metacharacters in literal glob cannot alter regex matching', () => {
      // Pattern contains regex metacharacters: +, (, ), [, ], $, ^, .
      const pattern = '/products/c++/[sale]-(1|2)/item.$1.html';
      const re = compileGlobToRegExp(pattern);

      // Exact match with metacharacters as literals
      expect(re.test('/products/c++/[sale]-(1|2)/item.$1.html')).toBe(true);

      // Must not match regex interpretations like repetition or alternation
      expect(re.test('/products/c/[sale]-(1|2)/item.$1.html')).toBe(false);
      expect(re.test('/products/c+++/[sale]-(1|2)/item.$1.html')).toBe(false);
      expect(re.test('/products/c++/sale-(1|2)/item.$1.html')).toBe(false);
      expect(re.test('/products/c++/[sale]-1/item.$1.html')).toBe(false);
      expect(re.test('/products/c++/[sale]-2/item.$1.html')).toBe(false);
      expect(re.test('/products/c++/[sale]-(1|2)/item.X1.html')).toBe(false);
    });

    it('anchors regex so partial matches fail', () => {
      const re = compileGlobToRegExp('/products/*');
      expect(re.test('/prefix/products/item')).toBe(false);
      expect(re.test('/products/item/suffix')).toBe(false);
      expect(re.test('/products/item')).toBe(true);
    });

    it('glob validation helper tests', () => {
      expect(validateGlobPattern('/valid/*').valid).toBe(true);
      expect(validateGlobPattern('/**').valid).toBe(true);
      expect(validateGlobPattern('**').valid).toBe(true);
      expect(validateGlobPattern('/has?query=1').valid).toBe(false);
      expect(validateGlobPattern('/has#fragment').valid).toBe(false);
      expect(validateGlobPattern('/triple/***').valid).toBe(false);
      expect(validateGlobPattern('').valid).toBe(false);
    });
  });

  describe('9. URL/external-ID matching: positive and boundary non-match cases', () => {
    it('matches exact external ID separated by standard path/delimiter boundaries (positive)', () => {
      // Coach style: /products/{slug}/{identifier}.html
      expect(
        matchExternalIdInUrl(
          'https://www.coach.com/products/tabby-26/CU068.html',
          'CU068'
        )
      ).toBe(true);

      // Coach variant hyphen delimiter: CU068-B4YDT
      expect(
        matchExternalIdInUrl(
          'https://www.coach.com/products/tabby-26/CU068-B4YDT.html',
          'CU068'
        )
      ).toBe(true);

      // Case-insensitivity in URL
      expect(
        matchExternalIdInUrl(
          'https://www.coach.com/products/tabby-26/cu068.html',
          'CU068'
        )
      ).toBe(true);

      // Query param match
      expect(
        matchExternalIdInUrl(
          'https://www.example.com/detail?sku=CU068&color=black',
          'CU068'
        )
      ).toBe(true);
    });

    it('does NOT match when external ID is part of a longer alphanumeric token (boundary non-match)', () => {
      // Suffix collision: CU0689 must NOT match CU068
      expect(
        matchExternalIdInUrl(
          'https://www.coach.com/products/tabby-26/CU0689.html',
          'CU068'
        )
      ).toBe(false);

      // Prefix collision: XCU068 must NOT match CU068
      expect(
        matchExternalIdInUrl(
          'https://www.coach.com/products/tabby-26/XCU068.html',
          'CU068'
        )
      ).toBe(false);

      // Infix collision: ACU068Z must NOT match CU068
      expect(
        matchExternalIdInUrl(
          'https://www.coach.com/products/tabby-26/ACU068Z-B4.html',
          'CU068'
        )
      ).toBe(false);

      // Query param suffix collision: sku=CU06800
      expect(
        matchExternalIdInUrl(
          'https://www.example.com/detail?sku=CU06800',
          'CU068'
        )
      ).toBe(false);
    });

    it('handles malformed candidate URLs by failing closed (returns false)', () => {
      expect(matchExternalIdInUrl('not a valid url', 'CU068')).toBe(false);
      expect(matchExternalIdInUrl('http://', 'CU068')).toBe(false);
    });
  });

  describe('10. Stage-B and Stage-C matching: title, category, price, and availability', () => {
    const doc: SelectionDocument = {
      version: 1,
      sources: {
        coach_us: {
          enabled: true,
          include: [
            {
              id: 'coach-all-products',
              kind: 'urlPattern',
              value: '/products/**',
              placements: ['home_rail', 'catalog_browse'],
              priority: 10,
            },
            {
              id: 'by-title',
              kind: 'titleKeyword',
              value: 'Tabby',
            },
            {
              id: 'by-cat',
              kind: 'category',
              value: 'Handbags',
            },
            {
              id: 'by-price',
              kind: 'priceUsdRange',
              value: [200, 600],
            },
          ],
          exclude: [
            {
              id: 'no-wallet',
              kind: 'titleKeyword',
              value: 'Wallet',
            },
          ],
        },
      },
    };

    const compiled = compileSelection(doc);

    it('Stage-B rules never create candidates in matchUrl; only Stage A gates candidates', () => {
      // Unrelated path does not match Stage A include (/products/**)
      const decision = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/about-us.html'
      );
      expect(decision.selected).toBe(false);
      expect(decision.reason).toBe('no_match');
    });

    it('evaluates titleKeyword positively and exclusion properly in matchProduct', () => {
      const match = compiled.matchProduct('coach_us', {
        externalId: '1',
        canonicalUrl: 'https://www.coach.com/products/tabby.html',
        title: 'Coach Tabby Shoulder Bag 26',
        category: null,
        priceUsd: null,
        availability: 'unknown',
      });
      expect(match.selected).toBe(true);
      if (match.selected) {
        // Winning Stage-A include owns metadata
        expect(match.ruleId).toBe('coach-all-products');
        expect(match.placements).toEqual(['home_rail', 'catalog_browse']);
        expect(match.priority).toBe(10);
      }

      // Excluded by Stage-B exclude titleKeyword: "Wallet"
      const excluded = compiled.matchProduct('coach_us', {
        externalId: '2',
        canonicalUrl: 'https://www.coach.com/products/wallet.html',
        title: 'Tabby Small Wallet',
        category: null,
        priceUsd: null,
        availability: 'unknown',
      });
      expect(excluded.selected).toBe(false);
      expect(excluded.ruleId).toBe('no-wallet');
    });

    it('evaluates category in matchProduct (case-insensitive and slugified)', () => {
      const match = compiled.matchProduct('coach_us', {
        externalId: '3',
        canonicalUrl: 'https://www.coach.com/products/item.html',
        title: 'Unbranded Leather Item',
        category: 'handbags',
        priceUsd: null,
        availability: 'unknown',
      });
      expect(match.selected).toBe(true);
      if (match.selected) {
        expect(match.ruleId).toBe('coach-all-products');
      }
    });

    it('evaluates priceUsdRange in matchProduct', () => {
      // In range: 350 in [200, 600]
      const match = compiled.matchProduct('coach_us', {
        externalId: '4',
        canonicalUrl: 'https://www.coach.com/products/item.html',
        title: 'Item',
        category: null,
        priceUsd: 350,
        availability: 'unknown',
      });
      expect(match.selected).toBe(true);
      if (match.selected) {
        expect(match.ruleId).toBe('coach-all-products');
      }

      // Out of range: 150 < 200, and does not match other Stage B rules
      const noMatch = compiled.matchProduct('coach_us', {
        externalId: '5',
        canonicalUrl: 'https://www.coach.com/products/item.html',
        title: 'Item',
        category: null,
        priceUsd: 150,
        availability: 'unknown',
      });
      expect(noMatch.selected).toBe(false);
    });

    it('evaluates availability in matchProduct', () => {
      const docWithAvail: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              { id: 'all-products', kind: 'all' },
              { id: 'in-stock-only', kind: 'availability', value: 'inStock' },
            ],
            exclude: [],
          },
        },
      };
      const engine = compileSelection(docWithAvail);

      const inStock = engine.matchProduct('coach_us', {
        externalId: '6',
        canonicalUrl: 'https://www.coach.com/products/item.html',
        title: 'Item',
        category: null,
        priceUsd: null,
        availability: 'inStock',
      });
      expect(inStock.selected).toBe(true);
      if (inStock.selected) {
        expect(inStock.ruleId).toBe('all-products');
      }

      const outOfStock = engine.matchProduct('coach_us', {
        externalId: '7',
        canonicalUrl: 'https://www.coach.com/products/item.html',
        title: 'Item',
        category: null,
        priceUsd: null,
        availability: 'outOfStock',
      });
      expect(outOfStock.selected).toBe(false);
    });
  });

  describe('11. Hash and canonicalization: identical hashes regardless of key order', () => {
    it('produces identical hash for semantically equivalent documents with different key order', () => {
      const docA: SelectionDocument = {
        version: 2,
        note: 'Key order test',
        sources: {
          coach_us: {
            enabled: true,
            maxSelectedUrls: 500,
            include: [
              {
                id: 'coach-tabby',
                kind: 'urlPattern',
                value: '/products/*tabby*',
                placements: ['home_rail', 'catalog_browse'],
                priority: 10,
                tier: 'standard',
              },
            ],
            exclude: [
              {
                id: 'no-mens',
                kind: 'urlPattern',
                value: '/products/*mens*',
              },
            ],
          },
        },
      };

      // Inverted key ordering at root, source, and rule levels
      const docB = {
        sources: {
          coach_us: {
            exclude: [
              {
                value: '/products/*mens*',
                kind: 'urlPattern',
                id: 'no-mens',
              },
            ],
            include: [
              {
                priority: 10,
                tier: 'standard',
                placements: ['home_rail', 'catalog_browse'],
                value: '/products/*tabby*',
                kind: 'urlPattern',
                id: 'coach-tabby',
              },
            ],
            maxSelectedUrls: 500,
            enabled: true,
          },
        },
        note: 'Key order test',
        version: 2,
      } as unknown as SelectionDocument;

      const hashA = hashSelectionDocument(docA);
      const hashB = hashSelectionDocument(docB);

      expect(hashA).toBe(hashB);
      expect(hashA).toHaveLength(64);
      expect(/^[0-9a-f]{64}$/.test(hashA)).toBe(true);

      const compiledA = compileSelection(docA);
      const compiledB = compileSelection(docB);
      expect(compiledA.hash).toBe(compiledB.hash);
    });

    it('pure TypeScript SHA-256 matches Node.js crypto SHA-256 bit-for-bit', () => {
      const testStrings = [
        '',
        'hello world',
        'a'.repeat(64),
        'b'.repeat(128),
        'c'.repeat(1000),
        '{"version":1,"sources":{"coach_us":{"enabled":true,"include":[]}}}',
        'Unicode characters: ñ, ü, 💼, 🛍️, 🚀',
      ];

      for (const str of testStrings) {
        const pureTsHash = sha256Hex(str);
        const nodeHash = createHash('sha256').update(str).digest('hex');
        expect(pureTsHash).toBe(nodeHash);
      }
    });

    it('canonicalJsonStringify recursively sorts keys but preserves array order', () => {
      const input = {
        z: 1,
        a: [{ y: 2, x: 1 }, { b: 4, a: 3 }],
        m: { k: 'val', j: 'other' },
      };

      const json = canonicalJsonStringify(input);
      expect(json).toBe(
        '{"a":[{"x":1,"y":2},{"a":3,"b":4}],"m":{"j":"other","k":"val"},"z":1}'
      );
    });
  });

  describe('12. Decisions expose winning rule metadata without exposing mutable input', () => {
    it('freezes placements and protects rule metadata against caller mutations', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'rule-safe',
                kind: 'all',
                placements: ['home_rail', 'catalog_browse'],
                priority: 15,
                tier: 'standard',
              },
            ],
            exclude: [],
          },
        },
      };

      const compiled = compileSelection(doc);
      const decision1 = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/products/bag.html'
      );

      expect(decision1.selected).toBe(true);
      if (decision1.selected) {
        expect(decision1.ruleId).toBe('rule-safe');
        expect(decision1.placements).toEqual(['home_rail', 'catalog_browse']);
        expect(decision1.priority).toBe(15);
        expect(decision1.tier).toBe('standard');

        // Mutating placements throws in strict mode or is prevented
        expect(Object.isFrozen(decision1.placements)).toBe(true);
        expect(() => {
          (decision1.placements as string[]).push('tampered_placement');
        }).toThrow();
      }

      // Subsequent evaluation remains completely unaffected
      const decision2 = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/products/bag.html'
      );
      if (decision2.selected) {
        expect(decision2.placements).toEqual(['home_rail', 'catalog_browse']);
      }
    });

    it('tie-breaking preserves source rule order within the same precedence class', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'first-include',
                kind: 'urlPattern',
                value: '/products/**',
                priority: 1,
              },
              {
                id: 'second-include',
                kind: 'urlPattern',
                value: '/products/**',
                priority: 2,
              },
            ],
            exclude: [],
          },
        },
      };

      const compiled = compileSelection(doc);
      const decision = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/products/tabby.html'
      );

      expect(decision.selected).toBe(true);
      if (decision.selected) {
        // First rule in source rule order wins
        expect(decision.ruleId).toBe('first-include');
        expect(decision.priority).toBe(1);
      }
    });

    it('tie-breaking between multiple pinned rules preserves source rule order', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'pin-1',
                kind: 'urlPattern',
                value: '/products/**',
                tier: 'pinned',
                priority: 10,
              },
              {
                id: 'pin-2',
                kind: 'urlPattern',
                value: '/products/**',
                tier: 'pinned',
                priority: 20,
              },
            ],
            exclude: [],
          },
        },
      };

      const compiled = compileSelection(doc);
      const decision = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/products/tabby.html'
      );

      expect(decision.selected).toBe(true);
      if (decision.selected) {
        expect(decision.ruleId).toBe('pin-1');
      }
    });

    it('malformed candidate URLs in matchUrl fail closed and never throw', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [{ id: 'all-rule', kind: 'all' }],
            exclude: [],
          },
        },
      };

      const compiled = compileSelection(doc);

      expect(() => compiled.matchUrl('coach_us', 'not a url')).not.toThrow();
      const decision = compiled.matchUrl('coach_us', 'not a url');
      expect(decision.selected).toBe(false);
      expect(decision.reason).toBe('malformed_url');
    });
  });

  describe('13. Stage-composition semantics (Stage-A gating, Stage-B/C filtering, and pinned override)', () => {
    it('URL matching Stage A but failing priceUsdRange is rejected by matchProduct', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'tabby-urls',
                kind: 'urlPattern',
                value: '/products/*tabby*',
                placements: ['catalog_browse'],
                priority: 5,
              },
              {
                id: 'price-filter',
                kind: 'priceUsdRange',
                value: [250, 600],
              },
            ],
            exclude: [],
          },
        },
      };

      const compiled = compileSelection(doc);

      // Stage A candidate URL check
      const urlDecision = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/products/tabby-26.html'
      );
      expect(urlDecision.selected).toBe(true);
      if (urlDecision.selected) {
        expect(urlDecision.requiresProductEvaluation).toBe(true);
      }

      // matchProduct with price below min (195 < 250)
      const productDecision = compiled.matchProduct('coach_us', {
        externalId: 'CEN52',
        canonicalUrl: 'https://www.coach.com/products/tabby-26.html',
        title: 'Tabby Shoulder Bag 26',
        category: 'Handbags',
        priceUsd: 195,
        availability: 'inStock',
      });
      expect(productDecision.selected).toBe(false);
    });

    it('URL/product matching Stage A and the price range is selected', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'tabby-urls',
                kind: 'urlPattern',
                value: '/products/*tabby*',
                placements: ['catalog_browse'],
                priority: 5,
              },
              {
                id: 'price-filter',
                kind: 'priceUsdRange',
                value: [250, 600],
              },
            ],
            exclude: [],
          },
        },
      };

      const compiled = compileSelection(doc);
      const productDecision = compiled.matchProduct('coach_us', {
        externalId: 'CEN52',
        canonicalUrl: 'https://www.coach.com/products/tabby-26.html',
        title: 'Tabby Shoulder Bag 26',
        category: 'Handbags',
        priceUsd: 450,
        availability: 'inStock',
      });

      expect(productDecision.selected).toBe(true);
      if (productDecision.selected) {
        expect(productDecision.ruleId).toBe('tabby-urls');
        expect(productDecision.placements).toEqual(['catalog_browse']);
        expect(productDecision.priority).toBe(5);
        expect(productDecision.requiresProductEvaluation).toBe(false);
      }
    });

    it('product matching price/category/title but not Stage A is rejected', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'brooklyn-only',
                kind: 'urlPattern',
                value: '/products/*brooklyn*',
              },
              {
                id: 'price-filter',
                kind: 'priceUsdRange',
                value: [200, 600],
              },
              {
                id: 'cat-filter',
                kind: 'category',
                value: 'Handbags',
              },
            ],
            exclude: [],
          },
        },
      };

      const compiled = compileSelection(doc);

      // Product matches category ("Handbags") and price ($350 in [200, 600]),
      // but its URL is tabby-26.html which does NOT match /products/*brooklyn*
      const decision = compiled.matchProduct('coach_us', {
        externalId: 'CU068',
        canonicalUrl: 'https://www.coach.com/products/tabby-26.html',
        title: 'Coach Tabby',
        category: 'Handbags',
        priceUsd: 350,
        availability: 'inStock',
      });
      expect(decision.selected).toBe(false);
    });

    it('{ kind: "all" } plus a Stage-B price rule fetches all candidates but only selects products inside the price range', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          michael_kors_us: {
            enabled: true,
            include: [
              { id: 'mk-all', kind: 'all', placements: ['catalog_browse'] },
              { id: 'mk-price', kind: 'priceUsdRange', value: [150, 400] },
            ],
            exclude: [],
          },
        },
      };

      const compiled = compileSelection(doc);

      // All candidate URLs match in matchUrl with requiresProductEvaluation: true
      const url1 = compiled.matchUrl(
        'michael_kors_us',
        'https://www.michaelkors.com/product/tote-1.html'
      );
      expect(url1.selected).toBe(true);
      if (url1.selected) {
        expect(url1.requiresProductEvaluation).toBe(true);
      }

      // Inside price range: selected
      const p1 = compiled.matchProduct('michael_kors_us', {
        externalId: 'MK-1',
        canonicalUrl: 'https://www.michaelkors.com/product/tote-1.html',
        title: 'Jet Set Tote',
        category: 'Totes',
        priceUsd: 228,
        availability: 'inStock',
      });
      expect(p1.selected).toBe(true);
      if (p1.selected) {
        expect(p1.ruleId).toBe('mk-all');
        expect(p1.placements).toEqual(['catalog_browse']);
      }

      // Outside price range: rejected
      const p2 = compiled.matchProduct('michael_kors_us', {
        externalId: 'MK-2',
        canonicalUrl: 'https://www.michaelkors.com/product/luxury-coat.html',
        title: 'Collection Coat',
        category: 'Clothing',
        priceUsd: 1200,
        availability: 'inStock',
      });
      expect(p2.selected).toBe(false);
    });

    it('a pinned Stage-A external-ID rule bypasses a matching Stage-B/C exclusion', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              {
                id: 'pin-cu068',
                kind: 'externalId',
                value: 'CU068',
                tier: 'pinned',
                placements: ['home_rail'],
                priority: 100,
              },
              {
                id: 'std-tabby',
                kind: 'urlPattern',
                value: '/products/*tabby*',
              },
            ],
            exclude: [
              // Stage-B exclusion on title and Stage-C exclusion on availability
              { id: 'no-mens', kind: 'titleKeyword', value: 'Mens' },
              { id: 'no-out-of-stock', kind: 'availability', value: 'outOfStock' },
            ],
          },
        },
      };

      const compiled = compileSelection(doc);

      // Product has externalId "CU068", but is "Mens" and "outOfStock"
      // Pinned Stage A MUST bypass both Stage B and Stage C exclusions!
      const product: MinimalProduct = {
        externalId: 'CU068',
        canonicalUrl: 'https://www.coach.com/products/mens-tabby-cu068.html',
        title: 'Mens Tabby Bag',
        category: 'Bags',
        priceUsd: 395,
        availability: 'outOfStock',
      };

      const decision = compiled.matchProduct('coach_us', product);
      expect(decision.selected).toBe(true);
      if (decision.selected) {
        expect(decision.ruleId).toBe('pin-cu068');
        expect(decision.tier).toBe('pinned');
        expect(decision.placements).toEqual(['home_rail']);
        expect(decision.priority).toBe(100);
      }
    });

    it('Stage-B/C rules set requiresProductEvaluation: true on a Stage-A URL candidate', () => {
      const docWithStageB: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              { id: 'tabby-urls', kind: 'urlPattern', value: '/products/**' },
              { id: 'price-filter', kind: 'priceUsdRange', value: [100, 500] },
            ],
            exclude: [],
          },
        },
      };
      const engineWithB = compileSelection(docWithStageB);
      const decB = engineWithB.matchUrl(
        'coach_us',
        'https://www.coach.com/products/tabby.html'
      );
      expect(decB.selected).toBe(true);
      if (decB.selected) {
        expect(decB.requiresProductEvaluation).toBe(true);
      }

      const docStageAOnly: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              { id: 'tabby-urls', kind: 'urlPattern', value: '/products/**' },
            ],
            exclude: [],
          },
        },
      };
      const engineAOnly = compileSelection(docStageAOnly);
      const decA = engineAOnly.matchUrl(
        'coach_us',
        'https://www.coach.com/products/tabby.html'
      );
      expect(decA.selected).toBe(true);
      if (decA.selected) {
        expect(decA.requiresProductEvaluation).toBe(false);
      }
    });

    it('source with no Stage-A include produces no candidates, even if it has Stage-B/C rules', () => {
      const doc: SelectionDocument = {
        version: 1,
        sources: {
          coach_us: {
            enabled: true,
            include: [
              { id: 'only-stage-b', kind: 'priceUsdRange', value: [100, 500] },
            ],
            exclude: [],
          },
        },
      };

      const compiled = compileSelection(doc);
      const urlDec = compiled.matchUrl(
        'coach_us',
        'https://www.coach.com/products/item.html'
      );
      expect(urlDec.selected).toBe(false);
      expect(urlDec.reason).toBe('zero_stage_a_include_rules');

      const prodDec = compiled.matchProduct('coach_us', {
        externalId: '123',
        canonicalUrl: 'https://www.coach.com/products/item.html',
        title: 'Item',
        category: null,
        priceUsd: 250,
        availability: 'inStock',
      });
      expect(prodDec.selected).toBe(false);
      expect(prodDec.reason).toBe('zero_stage_a_include_rules');
    });
  });
});
