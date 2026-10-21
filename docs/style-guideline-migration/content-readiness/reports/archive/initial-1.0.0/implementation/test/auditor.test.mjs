import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, mkdtemp, rm, access } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { audit, inferDestinationType, renderReport, sha256 } from '../lib/auditor.mjs';
import { validateSchema, parseShopifyJson } from '../lib/schema.mjs';
import { compareLive, loadInputs } from '../audit.mjs';
import { repoRoot, toolDir, defaultDataDir } from '../capture-sources.mjs';

const fixtureDir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures');
const source = await readFile(path.join(fixtureDir, 'fixture.dart'), 'utf8');
const fixture = JSON.parse(await readFile(path.join(fixtureDir, 'minimal.json'), 'utf8'));
const productionContract = JSON.parse(await readFile(path.join(defaultDataDir, 'content-contract.v1.schema.json'), 'utf8'));
const title = { type: 'string', minLength: 1 };
function input() {
  return {
    contract: { type: 'object', required: ['contractVersion', 'categories', 'brands'], properties: {
      contractVersion: { const: '1.0.0' },
      categories: { type: 'array', minItems: 1, items: { type: 'object', required: ['title'], properties: { title } } },
      brands: { type: 'array', minItems: 1, items: { type: 'object', required: ['title'], properties: { title } } },
    } },
    baseline: { content: structuredClone(fixture.content), assets: [], decisions: [], provenance: {}, capabilities: {} },
    routeMap: { routes: structuredClone(fixture.routes), supportLinks: [], trustedCatalogHosts: ['drive.google.com'] },
    requirements: { distinctDestinations: [['category.bags', 'brand.guess']], screens: Array.from({ length: 19 }, (_, i) => ({ page: i + 1, title: `Screen ${i + 1}`, requiredPaths: ['categories'], routeIds: ['category.bags'] })) },
    fieldMap: { fields: [] },
    manifest: { captureCompletedAt: '2026-10-20T23:00:00.000Z', sources: [{ path: 'fixture.dart', kind: 'text', capturedAt: '2026-10-20T23:00:00.000Z', sha256: sha256(source) }] },
    snapshots: { 'fixture.dart': source },
  };
}
const codes = report => report.findings.map(finding => finding.code);
const has = (report, code) => assert.ok(codes(report).includes(code), `Expected ${code}: ${codes(report).join(', ')}`);
const withCatalog = data => { data.routeMap.routes.push(structuredClone(fixture.externalCatalog)); return data; };

test('small explicit fixture is ready and keeps bags and Guess separate', () => {
  const report = audit(input());
  assert.equal(report.ready, true);
  assert.equal(report.findings.length, 0);
  assert.equal(report.coverage.length, 19);
});
test('missing and blank required fields are reported', () => {
  const data = input();
  delete data.baseline.content.categories[0].title;
  data.baseline.content.brands[0].title = '  ';
  const report = audit(data);
  has(report, 'REQUIRED_FIELD_MISSING');
  has(report, 'REQUIRED_FIELD_EMPTY');
});
test('incorrect collection group type is reported without crashing', () => {
  const data = input();
  data.baseline.content.categories = {};
  has(audit(data), 'INVALID_FIELD_TYPE');
});
test('unsupported contract version is rejected', () => {
  const data = input();
  data.baseline.content.contractVersion = '2.0.0';
  has(audit(data), 'INVALID_FIELD_VALUE');
});
test('a path cannot claim account type when it is a collection', () => {
  const data = input();
  data.routeMap.routes[0].type = 'cuenta_alojada';
  const report = audit(data);
  has(report, 'DESTINATION_TYPE_MISMATCH');
  has(report, 'CONTENT_DESTINATION_TYPE_MISMATCH');
});
test('category hub design is distinct from the existing all-products link', () => {
  const data = input();
  data.routeMap.routes[0].desiredType = 'pagina_interna';
  has(audit(data), 'DESIGN_DESTINATION_TYPE_GAP');
});
test('an anchor elsewhere in a source does not back a different handle', () => {
  const data = input();
  data.routeMap.routes[0].existing = '/collections/guessed-bags';
  has(audit(data), 'DESTINATION_UNSUPPORTED');
});
test('missing evidence and tampered snapshots are detected', () => {
  const data = input();
  data.snapshots['fixture.dart'] = 'unrelated source';
  const report = audit(data);
  has(report, 'SOURCE_SNAPSHOT_CHANGED');
  has(report, 'EVIDENCE_NOT_FOUND');
});
test('a missing frozen file is a finding, not an implicit live read', () => {
  const data = input();
  delete data.snapshots['fixture.dart'];
  has(audit(data), 'SOURCE_SNAPSHOT_MISSING');
});
test('bags and Guess cannot collapse even if route-local guards are removed', () => {
  const data = input();
  data.routeMap.routes[1].existing = '/collections/guess';
  data.routeMap.routes[1].sources = data.routeMap.routes[0].sources;
  has(audit(data), 'SEMANTIC_ROUTE_COLLISION');
});
test('an alias cannot assert equivalence without independent support', () => {
  const data = input();
  data.routeMap.routes[0].aliases = [{ value: '/collections/bags', equivalent: true }];
  has(audit(data), 'ALIAS_EQUIVALENCE_UNSUPPORTED');
});
test('proposed routes remain missing destinations', () => {
  const data = input();
  Object.assign(data.routeMap.routes[0], { existing: null, proposed: '/collections/bags', status: 'propuesto' });
  const report = audit(data);
  has(report, 'DESTINATION_MISSING');
  has(report, 'CONTENT_DESTINATION_PENDING');
});
test('a referenced collection does not prove target-store membership', () => {
  const data = input();
  data.routeMap.routes[0].requiresEntityVerification = true;
  has(audit(data), 'ENTITY_UNCONFIRMED');
});
test('wrong catalog URL is unsupported and exact host allowlist is enforced', () => {
  const data = withCatalog(input());
  data.routeMap.routes.at(-1).existing = 'https://drive.google.com.evil.invalid/file/d/test/view';
  const report = audit(data);
  has(report, 'UNTRUSTED_CATALOG_URL');
  has(report, 'DESTINATION_UNSUPPORTED');
});
test('HTTP, credentials and executable URL schemes are refused', () => {
  for (const url of ['http://drive.google.com/file/x', 'https://user:password@drive.google.com/file/x', 'javascript:alert(1)']) {
    const data = withCatalog(input());
    data.routeMap.routes.at(-1).existing = url;
    has(audit(data), 'UNTRUSTED_CATALOG_URL');
    has(audit(data), 'INVALID_DESTINATION_URL');
  }
});
test('HTTP 200 cannot certify the catalog identity or content', () => {
  const data = withCatalog(input());
  Object.assign(data.routeMap.routes.at(-1), { httpStatus: 200, remoteContentReview: 'verified' });
  const report = audit(data);
  has(report, 'CATALOG_REVIEW_UNSUPPORTED');
  has(report, 'CATALOG_CONTENT_UNCONFIRMED');
});
test('a catalog document can use the exact trusted Monetta host without becoming a page', () => {
  const data = withCatalog(input());
  const url = 'https://monetta.mx/files/catalogo.pdf';
  data.routeMap.trustedCatalogHosts.push('monetta.mx');
  data.snapshots['fixture.dart'] += `\nCatalog(url: '${url}');\n`;
  data.manifest.sources[0].sha256 = sha256(data.snapshots['fixture.dart']);
  Object.assign(data.routeMap.routes.at(-1), { existing: url, sources: [{ source: 'fixture.dart', needle: url, value: url, method: 'literal' }] });
  const report = audit(data);
  assert.ok(!codes(report).includes('DESTINATION_TYPE_MISMATCH'));
  assert.ok(!codes(report).includes('UNTRUSTED_CATALOG_URL'));
  has(report, 'CATALOG_CONTENT_UNCONFIRMED');
});
test('restricted access leaves catalog content unknown; no broken-link assertion', () => {
  const data = withCatalog(input());
  data.routeMap.routes.at(-1).httpStatus = 403;
  const report = audit(data);
  has(report, 'CATALOG_CONTENT_UNCONFIRMED');
  assert.ok(!codes(report).some(code => code.includes('BROKEN')));
});
test('catalog slots cannot point to collections; wholesale catalogs cannot be default public shares', () => {
  const data = input();
  data.baseline.content.catalogs = [{ id: 'private', mode: 'wholesale', shareable: true, destination: { routeId: 'category.bags' } }];
  const report = audit(data);
  has(report, 'CONTENT_DESTINATION_TYPE_MISMATCH');
  has(report, 'WHOLESALE_CATALOG_PUBLIC_SHARE');
});
test('unknown route and visual resources are detected', () => {
  const data = input();
  data.baseline.content.categories[0].destination.routeId = 'missing';
  data.baseline.content.categories[0].imageAssetId = 'missing-art';
  const report = audit(data);
  has(report, 'UNKNOWN_ROUTE_REFERENCE');
  has(report, 'VISUAL_ASSET_MISSING');
});
test('a brand logo does not fulfill the required listing campaign cover', () => {
  const data = input();
  data.requirements.requiredListingCovers = [{ routeId: 'brand.guess', pdfPages: [6, 9] }];
  data.baseline.content.brands[0].imageAssetId = 'logo-only';
  has(audit(data), 'LISTING_COVER_MISSING');
});
test('privacy/policy routes and preference options resolve to typed known IDs', () => {
  const data = input();
  data.baseline.content.signup = { privacyRouteId: 'brand.guess' };
  data.baseline.content.footer = { policyRouteIds: ['absent-policy'] };
  data.baseline.content.preferences = { brandOptionIds: ['unbacked-brand'] };
  const report = audit(data);
  has(report, 'CONTENT_DESTINATION_TYPE_MISMATCH');
  has(report, 'UNKNOWN_ROUTE_REFERENCE');
  has(report, 'UNKNOWN_PREFERENCE_OPTION');
});
test('module content references and catalog file ID changes are detected', () => {
  const data = withCatalog(input());
  data.baseline.content.home = { moduleOrder: [{ id: 'hero', contentRef: 'campaigns.missing' }] };
  data.routeMap.routes.at(-1).existing = fixture.externalCatalog.existing.replace('test-perfume', 'Test-Perfume');
  const report = audit(data);
  has(report, 'HOME_MODULE_CONTENT_MISSING');
  has(report, 'DESTINATION_UNSUPPORTED');
});
test('real v1 media schema requires each size and normalized focal points', () => {
  const media = { alt: '', decorative: true, sources: { compact: { assetId: 'real', focal: { x: 1.5, y: 0.5 } } } };
  const errors = validateSchema(media, productionContract.$defs.media, productionContract);
  assert.ok(errors.some(error => error.path === '/sources/compact/focal/x' && error.code === 'INVALID_FIELD_VALUE'));
  assert.ok(errors.some(error => error.path === '/sources/medium' && error.code === 'REQUIRED_FIELD_MISSING'));
  assert.ok(errors.some(error => error.path === '/sources/expanded'));
});
test('real v1 contract forbids invented price fields and changing the Rewards policy', () => {
  const tile = { id: 'bags', title: 'Bolsas', imageAssetId: 'legacy', alt: 'Bolsas', destination: { routeId: 'category.bags' }, price: 100 };
  assert.ok(validateSchema(tile, productionContract.$defs.tile, productionContract).some(error => error.code === 'UNKNOWN_FIELD'));
  const rewards = { model: 'mxn_balance_v1', currency: 'MXN', authority: 'accounts_orders', policyRef: 'new-rules', capabilitySource: 'runtime' };
  assert.ok(validateSchema(rewards, productionContract.$defs.rewards, productionContract).some(error => error.path === '/policyRef'));
});
test('editorial commerce values and points/tier conversion are rejected', () => {
  const data = input();
  data.baseline.content.categories[0].stockQuantity = 3;
  data.baseline.content.rewards = { model: 'points', currency: 'USD', authority: 'marketing' };
  const report = audit(data);
  has(report, 'COMMERCE_DATA_IN_EDITORIAL');
  has(report, 'REWARDS_CONTRACT_CHANGED');
});
test('requirements expose missing brands and invalid selection ordering', () => {
  const data = input();
  data.requirements.requiredItems = { brands: ['tory-burch'] };
  data.requirements.selectionPolicies = [{ id: 'newest', expectedOrdering: 'created_desc' }];
  const report = audit(data);
  has(report, 'DESIGN_CONTENT_MISSING');
  has(report, 'PRODUCT_SELECTION_ORDER_MISMATCH');
});
test('Shopify leading block comment is accepted without damaging HTTPS URLs', () => {
  assert.deepEqual(parseShopifyJson('/* generated */\n{"url":"https://monetta.mx"}'), { url: 'https://monetta.mx' });
  assert.throws(() => parseShopifyJson('/* generated */ {bad}'));
});
test('legacy template layout is a readiness gap', () => {
  const data = input();
  data.snapshots['page.json'] = '/* generated */ {"sections":{}}';
  data.requirements.templateRequirements = [{ source: 'page.json', layout: 'monetta', pdfPages: [16] }];
  has(audit(data), 'TEMPLATE_LAYOUT_PENDING');
});
test('support URLs and ID references must agree with source inventory', () => {
  const data = input();
  data.routeMap.supportLinks = [{ id: 'instagram', kind: 'social', url: 'https://evil.invalid', sources: [{ source: 'fixture.dart', needle: 'https://www.instagram.com/_monetta.mx' }] }];
  data.baseline.content.contact = { channels: [{ id: 'instagram', kind: 'social', url: 'https://different.invalid' }], groupLinkIds: ['absent'] };
  const report = audit(data);
  has(report, 'SUPPORT_LINK_UNSUPPORTED');
  has(report, 'CONTENT_LINK_UNSUPPORTED');
  has(report, 'UNKNOWN_SUPPORT_REFERENCE');
});
test('missing PDF pages are caught and evidence includes capture hash/date/line', () => {
  const data = input();
  data.requirements.screens.pop();
  data.routeMap.routes[0].requiresEntityVerification = true;
  const report = audit(data);
  has(report, 'PDF_COVERAGE_INCOMPLETE');
  const evidence = report.findings.find(f => f.code === 'ENTITY_UNCONFIRMED').evidence[0];
  assert.equal(evidence.line, 1);
  assert.equal(evidence.sha256, sha256(source));
  assert.equal(evidence.capturedAt, '2026-10-20T23:00:00.000Z');
});
test('live comparison reports drift/missing files without changing frozen evidence', async () => {
  const data = input();
  data.manifest.sources[0].sha256 = 'outdated';
  data.manifest.sources.push({ path: 'missing.json', sha256: 'missing' });
  const before = JSON.stringify(data.manifest);
  const result = await compareLive(data.manifest, fixtureDir);
  assert.deepEqual(result.sources.map(s => s.status), ['changed_since_capture', 'missing_locally']);
  assert.equal(JSON.stringify(data.manifest), before);
});
test('destination inference distinguishes collection, product, account and external catalog', () => {
  assert.equal(inferDestinationType('/collections/guess-1'), 'coleccion');
  assert.equal(inferDestinationType('/products/real-handle'), 'producto');
  assert.equal(inferDestinationType('routes.account_url', 'liquid'), 'cuenta_alojada');
  assert.equal(inferDestinationType('https://drive.google.com/collections/anything'), 'catalogo_externo');
  assert.equal(inferDestinationType('openOrders', 'flutter'), null);
});
test('offline delivery reproduces exactly with network unavailable', async () => {
  const previousFetch = globalThis.fetch;
  globalThis.fetch = () => { throw new Error('Network must not be used.'); };
  try {
    const data = await loadInputs(defaultDataDir);
    const first = audit(data);
    assert.deepEqual(first, audit(await loadInputs(defaultDataDir)));
    assert.equal(first.coverage.length, 19);
    assert.equal(first.summary.routes.total, 78);
    assert.ok(!codes(first).some(code => /EVIDENCE_|SOURCE_SNAPSHOT_|DESTINATION_UNSUPPORTED|ASSET_UNSUPPORTED/u.test(code)));
    assert.ok(renderReport(first).includes('Monetta'));
  } finally { globalThis.fetch = previousFetch; }
});
test('CLI writes both reports; strict readiness exits 1; invalid option exits 2', async () => {
  const output = await mkdtemp(path.join(toolDir, '.test-output-'));
  try {
    const result = spawnSync(process.execPath, [path.join(toolDir, 'audit.mjs'), '--strict', '--out-dir', output], { cwd: repoRoot, encoding: 'utf8' });
    assert.equal(result.status, 1, result.stderr);
    await access(path.join(output, 'audit.json'));
    await access(path.join(output, 'audit.md'));
    const bad = spawnSync(process.execPath, [path.join(toolDir, 'audit.mjs'), '--remote'], { cwd: repoRoot, encoding: 'utf8' });
    assert.equal(bad.status, 2);
    assert.match(bad.stderr, /Unknown argument/);
  } finally { await rm(output, { recursive: true, force: true }); }
});
