/**
 * Required audit personas (brief §4). Stubs / interfaces for seed tooling.
 * Synthetic passwords live ONLY in ignored local files under .audit-runs/.
 */

/** @typedef {'G'|'A'|'B'|'C'|'L'|'O'|'U'|'E'|'R'} PersonaCode */

/**
 * @type {Record<PersonaCode, {
 *   code: PersonaCode,
 *   name: string,
 *   setup: string,
 *   purpose: string,
 *   storage: 'flutter-isolated' | 'shopify-hosted' | 'local-pg' | 'server-principal',
 *   seedKind: 'local-stub' | 'hosted-manual' | 'admin-api' | 'pg-synthetic',
 * }>}
 */
export const PERSONAS = {
  G: {
    code: 'G',
    name: 'Guest',
    setup: 'Fresh app installation with no account',
    purpose: 'Guest browsing, wishlist, bag, and checkout',
    storage: 'flutter-isolated',
    seedKind: 'local-stub',
  },
  A: {
    code: 'A',
    name: 'Shopify customer A',
    setup: 'New customer via actual hosted sign-in/sign-up with controlled inbox',
    purpose: 'First-time onboarding and real authentication',
    storage: 'shopify-hosted',
    seedKind: 'hosted-manual',
  },
  B: {
    code: 'B',
    name: 'Shopify customer B',
    setup: 'Separate controlled inbox and Shopify identity',
    purpose: 'Cross-account isolation and account switching',
    storage: 'shopify-hosted',
    seedKind: 'hosted-manual',
  },
  C: {
    code: 'C',
    name: 'Existing customer C',
    setup: 'Development-store customer with test orders before first app login',
    purpose: 'Historical order / backfill verification',
    storage: 'shopify-hosted',
    seedKind: 'admin-api',
  },
  L: {
    code: 'L',
    name: 'Legacy customer L',
    setup: 'Synthetic legacy Monetta account in disposable PostgreSQL',
    purpose: 'Password migration, session, and identity-linking tests',
    storage: 'local-pg',
    seedKind: 'pg-synthetic',
  },
  O: {
    code: 'O',
    name: 'Owner O',
    setup: 'Explicitly provisioned principal tied to a verified identity',
    purpose: 'Administrative capabilities and operational tests',
    storage: 'server-principal',
    seedKind: 'pg-synthetic',
  },
  U: {
    code: 'U',
    name: 'Ordinary user U',
    setup: 'Valid authenticated non-owner',
    purpose: 'Authorization-negative tests',
    storage: 'local-pg',
    seedKind: 'pg-synthetic',
  },
  E: {
    code: 'E',
    name: 'Unverified user E',
    setup: 'Synthetic local account whose email matches a configured owner email',
    purpose: 'Reproduce and close unverified-email privilege escalation',
    storage: 'local-pg',
    seedKind: 'pg-synthetic',
  },
  R: {
    code: 'R',
    name: 'Revoked owner R',
    setup: 'Previously authorized test principal explicitly deactivated',
    purpose: 'Verify revocation is durable',
    storage: 'server-principal',
    seedKind: 'pg-synthetic',
  },
};

export function personaResourceId(code) {
  return `persona:${code}`;
}

/**
 * Plan persona rows for a manifest (no remote writes).
 */
export function planPersonaResources(prefix) {
  return Object.values(PERSONAS).map((p) => ({
    id: personaResourceId(p.code),
    kind: 'persona',
    status: 'planned',
    meta: {
      code: p.code,
      name: p.name,
      setup: p.setup,
      purpose: p.purpose,
      storage: p.storage,
      seedKind: p.seedKind,
      tag: `${prefix}-persona-${p.code}`,
      note:
        p.seedKind === 'hosted-manual'
          ? 'Hosted auth must be completed by authorized tester; Admin API create ≠ login proof.'
          : p.seedKind === 'pg-synthetic'
            ? 'Seed into disposable local PostgreSQL only; passwords in ignored secrets file.'
            : 'Isolated Flutter storage / app clear — no remote account.',
    },
  }));
}
