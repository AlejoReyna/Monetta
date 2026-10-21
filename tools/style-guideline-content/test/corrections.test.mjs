import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { audit, sha256 } from '../lib/auditor.mjs';
import { validateSchema } from '../lib/schema.mjs';
import { loadInputs } from '../audit.mjs';
import { defaultDataDir, repoRoot } from '../capture-sources.mjs';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures');
const families = JSON.parse(await readFile(path.join(dir, 'content-families.json'), 'utf8'));
const small = JSON.parse(await readFile(path.join(dir, 'minimal.json'), 'utf8'));
const frozen = await loadInputs(defaultDataDir);
const realSchema = frozen.contract;
const fresh = () => structuredClone(frozen);
const findings = (data, code) => audit(data).findings.filter(f => f.code === code);
const at = (data, code, expectedPath) => {
  const matches = findings(data, code);
  assert.ok(matches.some(f => f.path === expectedPath), `Expected ${code} at ${expectedPath}; got ${JSON.stringify(matches)}`);
  return matches.find(f => f.path === expectedPath);
};
const catalogIndex = (data, id) => data.baseline.content.catalogs.findIndex(c => c.id === id);
const route = (data, id) => data.routeMap.routes.find(r => r.id === id);
const selectionData = source => {
  const data = fresh();
  data.baseline.content.productSelections['todays-picks'].source = structuredClone(source);
  return data;
};
const descriptor = (kind, extra = {}) => ({ kind, provider: kind === 'recommendations' ? 'shopify_recommendations' : 'storefront_collection', ordering: kind === 'recommendations' ? 'provider_defined' : 'editorial', ...extra });
const sourcePath = '/content/productSelections/todays-picks/source';

function moduleData() {
  const data = fresh();
  const content = data.baseline.content;
  content.campaigns.fixture = structuredClone(families.campaign);
  content.productSelections.newest = structuredClone(families.selection);
  for (const key of ['categories', 'brands', 'wholesale', 'services', 'signup', 'footer']) content[key] = structuredClone(families[key]);
  // Candidate preference IDs are unrelated to these deliberately small lists.
  content.preferences.brandOptionIds = ['guess'];
  content.preferences.categoryOptionIds = ['bags'];
  content.home = { moduleOrder: structuredClone(families.modules) };
  return data;
}
const moduleErrors = data => audit(data).findings.filter(f => f.code.startsWith('HOME_MODULE_') && f.severity === 'error');

test('regression: bags-suggested cannot route to bags-wholesale or share its wholesale target', () => {
  const data = fresh();
  const index = catalogIndex(data, 'bags-suggested');
  data.baseline.content.catalogs[index].destination.routeId = 'catalog.bags-wholesale';
  const mismatch = at(data, 'CATALOG_MODE_MISMATCH', `/content/catalogs/${index}/destination`);
  assert.equal(mismatch.routeId, 'catalog.bags-wholesale');
  assert.equal(mismatch.catalogId, 'bags-suggested');
  at(data, 'WHOLESALE_DESTINATION_PUBLIC_SHARE', `/content/catalogs/${index}/shareable`);
});
test('regression: bags-wholesale cannot route to perfume-wholesale', () => {
  const data = fresh();
  const index = catalogIndex(data, 'bags-wholesale');
  data.baseline.content.catalogs[index].destination.routeId = 'catalog.perfume-wholesale';
  const mismatch = at(data, 'CATALOG_CATEGORY_MISMATCH', `/content/catalogs/${index}/destination`);
  assert.equal(mismatch.routeId, 'catalog.perfume-wholesale');
  assert.equal(mismatch.catalogId, 'bags-wholesale');
  assert.equal(findings(data, 'CATALOG_MODE_MISMATCH').length, 0);
});
test('all nine original category/mode pairs are preserved without identity/share validation errors', () => {
  const data = fresh();
  const expected = [
    ['bags-wholesale', 'bags', 'wholesale'], ['bags-suggested', 'bags', 'suggested_prices'], ['bags-no-prices', 'bags', 'no_prices'],
    ['beauty-wholesale', 'beauty', 'wholesale'], ['beauty-suggested', 'beauty', 'suggested_prices'], ['beauty-no-prices', 'beauty', 'no_prices'],
    ['perfume-wholesale', 'perfume', 'wholesale'], ['perfume-suggested', 'perfume', 'suggested_prices'], ['perfume-no-prices', 'perfume', 'no_prices'],
  ];
  assert.deepEqual(data.baseline.content.catalogs.map(c => [c.id, c.category, c.mode]), expected);
  for (const catalog of data.baseline.content.catalogs) {
    const target = route(data, catalog.destination.routeId);
    assert.equal(target.catalogCategory, catalog.category);
    assert.equal(target.catalogMode, catalog.mode);
  }
  const newCodes = ['CATALOG_MODE_MISMATCH', 'CATALOG_CATEGORY_MISMATCH', 'CATALOG_IDENTITY_UNCONFIRMED', 'CATALOG_SHAREABILITY_UNCONFIRMED', 'WHOLESALE_DESTINATION_PUBLIC_SHARE'];
  assert.deepEqual(audit(data).findings.filter(f => newCodes.includes(f.code)), []);
});
test('missing catalog destination metadata reports uncertainty instead of equivalence', () => {
  const data = fresh();
  const index = catalogIndex(data, 'bags-suggested');
  const target = route(data, 'catalog.bags-suggested');
  delete target.catalogCategory;
  delete target.catalogMode;
  at(data, 'CATALOG_IDENTITY_UNCONFIRMED', `/content/catalogs/${index}/destination`);
  at(data, 'CATALOG_SHAREABILITY_UNCONFIRMED', `/content/catalogs/${index}/shareable`);
  assert.equal(findings(data, 'CATALOG_MODE_MISMATCH').length, 0);
  assert.equal(findings(data, 'CATALOG_CATEGORY_MISMATCH').length, 0);
});
test('reduced fixture still detects category, mode and real-target share mismatches', () => {
  const data = fresh();
  data.contract = { type: 'object' };
  data.baseline.content = { catalogs: [{ id: 'test', category: 'bags', mode: 'suggested_prices', shareable: true, destination: { routeId: small.externalCatalog.id } }] };
  data.routeMap.routes = [{ ...structuredClone(small.externalCatalog), catalogMode: 'wholesale' }];
  at(data, 'CATALOG_CATEGORY_MISMATCH', '/content/catalogs/0/destination');
  at(data, 'CATALOG_MODE_MISMATCH', '/content/catalogs/0/destination');
  at(data, 'WHOLESALE_DESTINATION_PUBLIC_SHARE', '/content/catalogs/0/shareable');
});

test('regression: the real V1 selection source schema rejects collection without routeId', () => {
  const errors = validateSchema(descriptor('collection'), realSchema.$defs.selectionSource, realSchema);
  assert.ok(errors.some(error => error.code === 'SCHEMA_ANY_OF_MISMATCH'));
});
test('regression: the exact todays-picks collection mutation reports a required route with real V1 schema', () => {
  const data = fresh();
  const source = data.baseline.content.productSelections['todays-picks'].source;
  source.kind = 'collection';
  delete source.routeId;
  at(data, 'SELECTION_ROUTE_REQUIRED', `${sourcePath}/routeId`);
  at(data, 'SCHEMA_ANY_OF_MISMATCH', sourcePath);
});
test('collection resolution requires a known route with an existing destination', () => {
  for (const kind of ['unknown-route', 'empty-destination', 'proposed-destination']) {
    const data = selectionData(descriptor('collection', { routeId: kind === 'unknown-route' ? 'absent' : 'catalog.all' }));
    if (kind === 'empty-destination') route(data, 'catalog.all').existing = null;
    if (kind === 'proposed-destination') route(data, 'catalog.all').status = 'propuesto';
    at(data, 'SELECTION_DESTINATION_UNRESOLVED', `${sourcePath}/routeId`);
  }
});
test('collection and curated routes must be collections, not product or page destinations', () => {
  for (const kind of ['collection', 'curated']) for (const routeId of ['product.detail', 'contact.web']) {
    const data = selectionData(descriptor(kind, { routeId }));
    at(data, 'SELECTION_DESTINATION_TYPE_MISMATCH', `${sourcePath}/routeId`);
  }
});
test('reduced selection fixture cannot bypass collection resolution', () => {
  const data = selectionData(descriptor('collection'));
  data.contract = { type: 'object' };
  at(data, 'SELECTION_ROUTE_REQUIRED', `${sourcePath}/routeId`);
});

const invalidSources = [
  ['curated without either source', descriptor('curated')],
  ['curated with an empty list', descriptor('curated', { handles: [] })],
  ['curated with blank handles', descriptor('curated', { handles: [' '] })],
  ['curated with a string instead of a list', descriptor('curated', { handles: 'test' })],
  ['curated with non-string handles', descriptor('curated', { handles: [1] })],
  ['curated with duplicate handles', descriptor('curated', { handles: ['test', 'test'] })],
  ['curated with ambiguous collection and handles', descriptor('curated', { routeId: 'catalog.all', handles: ['test'] })],
  ['collection with a blank route', descriptor('collection', { routeId: ' ' })],
];
for (const [label, source] of invalidSources) test(`real V1 rejects ${label}`, () => {
  assert.ok(validateSchema(source, realSchema.$defs.selectionSource, realSchema).length > 0);
});
const validSources = [
  ['collection route', descriptor('collection', { routeId: 'catalog.all' })],
  ['curated collection', descriptor('curated', { routeId: 'catalog.all' })],
  ['curated explicit handles', descriptor('curated', { handles: ['fixture-product-a', 'fixture-product-b'] })],
  ['newest provider without route', descriptor('newest', { ordering: 'created_desc' })],
  ['recommendations provider without route', descriptor('recommendations')],
];
for (const [label, source] of validSources) test(`real V1 and semantic checks preserve ${label}`, () => {
  assert.deepEqual(validateSchema(source, realSchema.$defs.selectionSource, realSchema), []);
  const report = audit(selectionData(source));
  assert.deepEqual(report.findings.filter(f => f.code.startsWith('SELECTION_') && f.path.startsWith(sourcePath)), []);
});
test('curated without source is unresolved; using both alternatives is ambiguous even in a reduced fixture', () => {
  const empty = selectionData(descriptor('curated'));
  empty.contract = { type: 'object' };
  at(empty, 'SELECTION_SOURCE_UNRESOLVED', sourcePath);
  const both = selectionData(descriptor('curated', { routeId: 'catalog.all', handles: ['test'] }));
  both.contract = { type: 'object' };
  at(both, 'SELECTION_SOURCE_AMBIGUOUS', sourcePath);
});
test('anyOf accepts at least one branch and oneOf accepts exactly one, including nested local refs', () => {
  assert.ok(validateSchema({}, { anyOf: [{ required: ['routeId'] }, { required: ['handles'] }] }).some(e => e.code === 'SCHEMA_ANY_OF_MISMATCH'));
  assert.deepEqual(validateSchema({ routeId: 'x', handles: ['x'] }, { anyOf: [{ required: ['routeId'] }, { required: ['handles'] }] }), []);
  assert.ok(validateSchema({ routeId: 'x', handles: ['x'] }, { oneOf: [{ required: ['routeId'] }, { required: ['handles'] }] }).some(e => e.code === 'SCHEMA_ONE_OF_MISMATCH'));
  const schema = { $defs: { choice: { oneOf: [{ const: 'a' }, { const: 'b' }] } }, properties: { value: { $ref: '#/$defs/choice' } } };
  assert.deepEqual(validateSchema({ value: 'a' }, schema), []);
  assert.ok(validateSchema({ value: 'c' }, schema).some(e => e.path === '/value' && e.code === 'SCHEMA_ONE_OF_MISMATCH'));
});

test('regression: a product_selection module pointing to existing rewards is incompatible', () => {
  const data = fresh();
  data.baseline.content.home = { moduleOrder: [{ id: 'newest', kind: 'product_selection', contentRef: 'rewards' }] };
  const finding = at(data, 'HOME_MODULE_FAMILY_MISMATCH', '/content/home/moduleOrder/0/contentRef');
  assert.equal(finding.contentRef, 'rewards');
});
test('all eight module kinds accept their corresponding real V1 structures', () => {
  const data = moduleData();
  assert.deepEqual(validateSchema(data.baseline.content.home, realSchema.properties.home, realSchema), []);
  assert.deepEqual(moduleErrors(data), []);
  // A dot in a family reference is a literal separator, never a wildcard.
  const descriptor = { id: 'hero', kind: 'campaign', contentRef: 'campaignsXfixture' };
  assert.ok(validateSchema(descriptor, realSchema.properties.home.properties.moduleOrder.items, realSchema).length > 0);
});
const wrongRefs = { campaign: 'productSelections.newest', product_selection: 'rewards', categories: 'brands', brands: 'categories', wholesale: 'rewards', services: 'categories', signup: 'footer', footer: 'signup' };
for (const [kind, wrong] of Object.entries(wrongRefs)) test(`${kind} rejects an existing reference to another family`, () => {
  const data = moduleData();
  const index = data.baseline.content.home.moduleOrder.findIndex(m => m.kind === kind);
  data.baseline.content.home.moduleOrder[index].contentRef = wrong;
  at(data, 'HOME_MODULE_FAMILY_MISMATCH', `/content/home/moduleOrder/${index}/contentRef`);
});
const invalidate = {
  campaign: c => { delete c.campaigns.fixture.headline; },
  product_selection: c => { delete c.productSelections.newest.source.routeId; },
  categories: c => { c.categories = [{}]; }, brands: c => { c.brands = [{}]; },
  wholesale: c => { c.wholesale.body = 1; }, services: c => { c.services = [{}]; },
  signup: c => { delete c.signup.submissionAdapter; }, footer: c => { c.footer.columns = {}; },
};
for (const [kind, change] of Object.entries(invalidate)) test(`${kind} rejects its own family when the real V1 structure is invalid`, () => {
  const data = moduleData();
  change(data.baseline.content);
  const index = data.baseline.content.home.moduleOrder.findIndex(m => m.kind === kind);
  const finding = at(data, 'HOME_MODULE_CONTENT_INVALID', `/content/home/moduleOrder/${index}/contentRef`);
  assert.ok(finding.validationErrors.length > 0);
});
test('missing, empty and non-leaf module references stay invalid', () => {
  for (const ref of ['campaigns.absent', 'campaigns.fixture.headline', 'productSelections']) {
    const data = moduleData();
    data.baseline.content.home.moduleOrder[0].contentRef = ref;
    const code = ref === 'campaigns.absent' ? 'HOME_MODULE_CONTENT_MISSING' : 'HOME_MODULE_FAMILY_MISMATCH';
    at(data, code, '/content/home/moduleOrder/0/contentRef');
  }
  const data = moduleData();
  data.baseline.content.services = [];
  const index = data.baseline.content.home.moduleOrder.findIndex(m => m.kind === 'services');
  at(data, 'HOME_MODULE_CONTENT_MISSING', `/content/home/moduleOrder/${index}/contentRef`);
});
test('a reduced schema reports missing structure definitions rather than silently certifying a module', () => {
  const data = moduleData();
  data.contract = { type: 'object' };
  at(data, 'HOME_MODULE_SCHEMA_MISSING', '/content/home/moduleOrder/0/contentRef');
});
test('the original baseline, source manifest, snapshots and 35-test file remain byte-identical', async () => {
  const original = JSON.parse(await readFile(path.join(defaultDataDir, 'reports/archive/initial-1.0.0/archive-manifest.json'), 'utf8'));
  for (const item of [...original.frozenInputs, original.unchangedOriginalTest]) assert.equal(sha256(await readFile(path.join(repoRoot, item.path))), item.sha256, item.path);
});
