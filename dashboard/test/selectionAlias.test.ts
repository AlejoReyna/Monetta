import { describe, expect, it } from 'vitest';
import { parseSelectionDocument, isSelectionError } from '@selection/index.js';

// The shared-rule coupling (CATALOG_DASHBOARD § 7.2, WP-68 acceptance): the
// dashboard resolves the server's validator through the `@selection` alias.
// If this import breaks, the dashboard job must fail too.
describe('shared selection module via @selection alias', () => {
  it('validates a document with the same rules as the server', () => {
    const parsed = parseSelectionDocument({
      version: 1,
      sources: {
        coach_us: {
          enabled: true,
          include: [{ id: 'all-coach', kind: 'all' }],
        },
      },
    });
    expect(isSelectionError(parsed)).toBe(false);
  });

  it('rejects an invalid document with a typed error', () => {
    const parsed = parseSelectionDocument({ version: 1 });
    expect(isSelectionError(parsed)).toBe(true);
  });
});
