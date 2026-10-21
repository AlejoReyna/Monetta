import { createHash } from 'node:crypto';
import { validateSchema, parseShopifyJson } from './schema.mjs';

export const sha256 = value => createHash('sha256').update(value).digest('hex');
export const AUDIT_VERSION = '1.0.1';
export const routeTypes = ['coleccion', 'producto', 'pagina_interna', 'cuenta_alojada', 'catalogo_externo'];
const statuses = ['verificado', 'propuesto', 'desconocido', 'pendiente'];
const nonEmpty = value => value !== undefined && value !== null && value !== '' && (!Array.isArray(value) || value.length > 0);
const list = value => Array.isArray(value) ? value : [];
const text = value => typeof value === 'string' && value.trim().length > 0;
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const catalogModes = ['wholesale', 'suggested_prices', 'no_prices'];
const moduleFamilies = {
  campaign: { pattern: /^campaigns\.[^.]+$/u, definition: 'campaign' },
  product_selection: { pattern: /^productSelections\.[^.]+$/u, definition: 'selection' },
  categories: { pattern: /^categories$/u, property: 'categories' },
  brands: { pattern: /^brands$/u, property: 'brands' },
  wholesale: { pattern: /^wholesale$/u, definition: 'wholesale' },
  services: { pattern: /^services$/u, property: 'services' },
  signup: { pattern: /^signup$/u, definition: 'signup' },
  footer: { pattern: /^footer$/u, definition: 'footer' },
};
export const getPath = (object, dotted) => typeof dotted === 'string' ? dotted.split('.').reduce((node, key) => node?.[key], object) : undefined;
const escapePointer = value => String(value).replaceAll('~', '~0').replaceAll('/', '~1');

export function inferDestinationType(value, representation = 'literal') {
  if (!value || typeof value !== 'string' || representation === 'flutter' || representation === 'capability') return null;
  if (representation === 'liquid') {
    if (/^routes\.account(_login)?_url$/u.test(value)) return 'cuenta_alojada';
    if (value === 'routes.all_products_collection_url') return 'coleccion';
    if (value === 'product.url') return 'producto';
    if (['routes.root_url', 'routes.search_url', 'routes.cart_url'].includes(value)) return 'pagina_interna';
    return null;
  }
  let url;
  try { url = new URL(value, 'https://monetta.invalid'); } catch { return null; }
  if (url.hostname !== 'monetta.invalid' && !['monetta.mx', 'www.monetta.mx'].includes(url.hostname)) return 'catalogo_externo';
  if (/^\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?collections\/.+/u.test(url.pathname)) return 'coleccion';
  if (/^\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?products\/.+/u.test(url.pathname)) return 'producto';
  if (/^\/account(?:\/|$)/u.test(url.pathname)) return 'cuenta_alojada';
  // A trusted Monetta host can also serve catalog documents. Unknown paths
  // do not become internal-page proof solely because the host is Monetta.
  if (['monetta.mx', 'www.monetta.mx'].includes(url.hostname) && !/^\/(?:pages\/|policies\/|search(?:\/|$)|cart(?:\/|$)|$)/u.test(url.pathname)) return null;
  return 'pagina_interna';
}

function supportedValue(ref) {
  if (ref.method === 'collection_handle') return `/collections/${ref.value}`;
  if (ref.method === 'page_handle') return `/pages/${ref.value}`;
  return ref.value;
}

export function audit(input) {
  const { contract, baseline, routeMap, requirements, fieldMap, manifest, snapshots } = input;
  const findings = [];
  const sourceByPath = new Map((manifest.sources ?? []).map(source => [source.path, source]));
  const routeById = new Map();
  const content = baseline.content ?? {};
  const assets = new Map();
  const add = (code, severity, at, message, extra = {}) => findings.push({ code, severity, path: at, message, ...extra });
  const evidence = ref => {
    if (!ref || !sourceByPath.has(ref.source)) return false;
    if (!ref.needle) return sourceByPath.get(ref.source).kind === 'binary';
    return typeof snapshots[ref.source] === 'string' && snapshots[ref.source].includes(ref.needle);
  };
  const checkedEvidence = (refs, at) => {
    if (!Array.isArray(refs) || refs.length === 0) { add('EVIDENCE_MISSING', 'error', at, 'No local source supports this value.'); return false; }
    let valid = true;
    for (const ref of refs) if (!evidence(ref)) { valid = false; add('EVIDENCE_NOT_FOUND', 'error', at, 'Source or exact excerpt does not match the frozen capture.', { evidence: [ref] }); }
    return valid;
  };

  for (const source of manifest.sources ?? []) {
    if (source.kind !== 'text') continue;
    if (typeof snapshots[source.path] !== 'string') add('SOURCE_SNAPSHOT_MISSING', 'error', source.path, 'Frozen text source is unavailable.');
    else if (sha256(snapshots[source.path]) !== source.sha256) add('SOURCE_SNAPSHOT_CHANGED', 'error', source.path, 'Frozen source hash does not match its manifest.');
  }
  for (const error of validateSchema(content, contract)) {
    const visual = error.code === 'REQUIRED_FIELD_MISSING' && /\/media\/sources\/(compact|medium|expanded)$/u.test(error.path);
    add(visual ? 'RESPONSIVE_VISUAL_MISSING' : error.code, 'error', `/content${error.path}`, error.message);
  }
  const pdf = sourceByPath.get(requirements.designSource);
  if (requirements.designSource && (!pdf || pdf.sha256 !== requirements.designSha256)) add('DESIGN_SOURCE_MISMATCH', 'error', '/requirements/designSource', 'Design requirements do not match the captured PDF identity.');

  for (const [index, route] of (routeMap.routes ?? []).entries()) {
    const at = `/routes/${index}`;
    if (routeById.has(route.id)) add('DUPLICATE_ROUTE_ID', 'error', at, `Duplicate route ${route.id}.`);
    routeById.set(route.id, route);
    if (!routeTypes.includes(route.type)) add('INVALID_DESTINATION_TYPE', 'error', at, `Unsupported type ${route.type}.`, { routeId: route.id });
    if (!statuses.includes(route.status)) add('INVALID_ROUTE_STATUS', 'error', at, `Unsupported status ${route.status}.`, { routeId: route.id });
    if (route.desiredType && route.desiredType !== route.type) add('DESIGN_DESTINATION_TYPE_GAP', 'warning', at, `Design requires ${route.desiredType}; current destination is ${route.type}.`, { routeId: route.id });
    if (nonEmpty(route.existing) && typeof route.existing !== 'string') add('INVALID_DESTINATION_VALUE', 'error', at, 'Existing destination must be a string or null.', { routeId: route.id });
    if (!nonEmpty(route.existing)) {
      add('DESTINATION_MISSING', 'warning', at, `No evidenced destination for ${route.requestedByDesign}.`, { routeId: route.id, status: route.status });
      // Proposed paths are not promoted into existing routes.
      if (route.status === 'verificado') add('VERIFICATION_UNSUPPORTED', 'error', at, 'A verified route must have an existing destination.', { routeId: route.id });
    } else {
      const backed = checkedEvidence(route.sources, at);
      if (backed && !route.sources.some(ref => evidence(ref) && typeof ref.value === 'string' && ref.needle?.includes(ref.value) && supportedValue(ref) === route.existing)) {
        add('DESTINATION_UNSUPPORTED', 'error', at, 'The evidence does not establish the exact destination/handle.', { routeId: route.id, evidence: route.sources });
      }
      const inferred = inferDestinationType(route.existing, route.representation);
      if (inferred && inferred !== route.type) add('DESTINATION_TYPE_MISMATCH', 'error', at, `Destination resolves as ${inferred}; declared ${route.type}.`, { routeId: route.id });
      if (route.representation === 'literal' && typeof route.existing === 'string') {
        let uri;
        try { uri = new URL(route.existing, 'https://monetta.invalid'); } catch { /* Report below. */ }
        if (!uri || uri.protocol !== 'https:' || uri.username || uri.password || route.existing.startsWith('//')) add('INVALID_DESTINATION_URL', 'error', at, 'Destination must be an HTTPS URL or a store-relative path without credentials.', { routeId: route.id });
      }
      if (route.type === 'catalogo_externo') {
        let uri;
        try { uri = new URL(route.existing); } catch { /* Report below. */ }
        if (!uri || uri.protocol !== 'https:' || uri.username || uri.password || !(routeMap.trustedCatalogHosts ?? []).includes(uri.hostname)) add('UNTRUSTED_CATALOG_URL', 'error', at, 'Catalog must use HTTPS and an exact trusted host, without credentials.', { routeId: route.id });
        const review = route.contentReview;
        const reviewed = route.remoteContentReview === 'verified' && review?.scope === 'document_content' && review.category === route.catalogCategory && review.mode === route.catalogMode && review.reviewer && review.reviewedAt && list(review.sources).some(ref => sourceByPath.get(ref.source)?.role === 'remote_catalog_snapshot' && evidence(ref));
        if (route.remoteContentReview === 'verified' && !reviewed) add('CATALOG_REVIEW_UNSUPPORTED', 'error', at, 'A verified catalog content claim needs a dated document review, matching category/mode, and a captured remote_catalog_snapshot source.', { routeId: route.id });
        if (!reviewed) add('CATALOG_CONTENT_UNCONFIRMED', 'warning', at, 'Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.', { routeId: route.id });
      }
      if (route.status !== 'verificado') add('DESTINATION_NOT_READY', 'warning', at, `Destination status: ${route.status}.`, { routeId: route.id });
    }
    if (route.requiresEntityVerification) add('ENTITY_UNCONFIRMED', 'warning', at, 'A local reference does not establish collection membership/publication in the target store.', { routeId: route.id, evidence: route.sources, observations: route.entityObservations ?? [] });
    for (const issue of route.issues ?? []) add('KNOWN_ROUTE_INCONSISTENCY', 'warning', at, issue, { routeId: route.id, evidence: route.sources });
    for (const alias of route.aliases ?? []) {
      if (alias.sources) checkedEvidence(alias.sources, at);
      if (alias.equivalent === true && !alias.equivalenceEvidence?.length) add('ALIAS_EQUIVALENCE_UNSUPPORTED', 'error', at, `Alias ${alias.value} has no evidence of equivalence.`, { routeId: route.id });
      if (alias.equivalenceEvidence) checkedEvidence(alias.equivalenceEvidence, at);
    }
  }
  for (const route of routeMap.routes ?? []) {
    for (const distinctId of route.mustDifferFrom ?? []) {
      const other = routeById.get(distinctId);
      if (route.existing && other?.existing === route.existing) add('SEMANTIC_ROUTE_COLLISION', 'error', `/routes/${route.id}`, `${route.id} must remain distinct from ${distinctId}.`, { routeId: route.id });
    }
  }
  const supportById = new Map();
  for (const [index, link] of list(routeMap.supportLinks).entries()) {
    const at = `/supportLinks/${index}`;
    if (supportById.has(link.id)) add('DUPLICATE_SUPPORT_LINK_ID', 'error', at, `Duplicate support link ${link.id}.`);
    supportById.set(link.id, link);
    const valid = checkedEvidence(link.sources, at);
    let exact = list(link.sources).some(ref => evidence(ref) && ref.needle?.includes(link.url));
    if (link.kind === 'whatsapp' && /^https:\/\/wa\.me\/\d+$/u.test(link.url ?? '')) {
      const phone = new URL(link.url).pathname.slice(1);
      exact ||= list(link.sources).some(ref => evidence(ref) && ref.needle?.includes(`'${phone}'`));
    }
    if (valid && !exact) add('SUPPORT_LINK_UNSUPPORTED', 'error', at, 'The exact support/social destination is not backed by its evidence.');
  }
  for (const pair of requirements.distinctDestinations ?? []) {
    const [left, right] = pair.map(id => routeById.get(id));
    if (left?.existing && left.existing === right?.existing) add('SEMANTIC_ROUTE_COLLISION', 'error', `/requirements/distinctDestinations/${pair.join(':')}`, `${pair.join(' and ')} must not share a destination.`, { routeId: pair[0] });
  }
  for (const asset of baseline.assets ?? []) {
    if (contract.$defs?.asset) for (const error of validateSchema(asset, contract.$defs.asset, contract)) add(error.code, 'error', `/assets/${asset.id}${error.path}`, error.message);
    if (assets.has(asset.id)) add('DUPLICATE_ASSET_ID', 'error', `/assets/${asset.id}`, 'Duplicate asset identifier.');
    assets.set(asset.id, asset);
    const source = sourceByPath.get(asset.path);
    if (!source || source.kind !== 'binary' || source.sha256 !== asset.sha256 || source.size === 0) add('ASSET_UNSUPPORTED', 'error', `/assets/${asset.id}`, 'Asset is not backed by a non-empty captured local resource.');
  }

  const walk = (node, at = '/content') => {
    if (!node || typeof node !== 'object') return;
    if (!Array.isArray(node) && typeof node.id === 'string') { /* IDs are checked per array below. */ }
    if (Array.isArray(node)) {
      const ids = node.filter(item => item && typeof item.id === 'string').map(item => item.id);
      if (new Set(ids).size !== ids.length) add('DUPLICATE_CONTENT_ID', 'error', at, 'Content IDs must be unique within a group.');
    }
    for (const [key, value] of Object.entries(node)) {
      const here = `${at}/${escapePointer(key)}`;
      if (key === 'routeId' && typeof value === 'string') {
        const route = routeById.get(value);
        if (!route) add('UNKNOWN_ROUTE_REFERENCE', 'error', here, `Unknown route ${value}.`);
        else if (!route.existing || route.status !== 'verificado') add('CONTENT_DESTINATION_PENDING', 'warning', here, `Content references ${value}, whose destination is not ready.`, { routeId: value });
      }
      if ((key === 'assetId' || key === 'imageAssetId') && typeof value === 'string') {
        const asset = assets.get(value);
        if (!asset) add('VISUAL_ASSET_MISSING', 'error', here, `Unknown/missing resource ${value}.`);
        else if (asset.approval !== 'approved_for_migration') add('VISUAL_APPROVAL_PENDING', 'warning', here, `${value} is a legacy fallback; the PDF composition/crop is not approved.`, { assetId: value });
      }
      if (['price', 'compareAtPrice', 'stockQuantity', 'discountPercent', 'availableCents', 'points', 'tier'].includes(key)) add('COMMERCE_DATA_IN_EDITORIAL', 'error', here, 'Commercial/account values must come from the authoritative runtime source.');
      walk(value, here);
    }
    if (node.media?.sources) {
      if (node.media.decorative !== true && !nonEmpty(node.media.alt)) add('VISUAL_ALT_MISSING', 'error', `${at}/media/alt`, 'Non-decorative image needs an alternative description.');
    }
    if (node.routeId && Array.isArray(node.allowedTypes)) {
      const route = routeById.get(node.routeId);
      if (route && !node.allowedTypes.includes(route.type)) add('CONTENT_DESTINATION_TYPE_MISMATCH', 'error', at, `Slot accepts ${node.allowedTypes.join(', ')}; ${node.routeId} is ${route.type}.`, { routeId: node.routeId });
    }
    if (node.mode && node.shareable === true && node.mode === 'wholesale') add('WHOLESALE_CATALOG_PUBLIC_SHARE', 'error', at, 'Wholesale price catalog must not be the default customer-facing share destination.');
    for (const key of ['supportLinkId', 'groupLinkIds', 'socialLinkIds']) {
      if (!Object.hasOwn(node, key)) continue;
      for (const id of key.endsWith('Ids') ? list(node[key]) : [node[key]]) if (!supportById.has(id)) add('UNKNOWN_SUPPORT_REFERENCE', 'error', `${at}/${key}`, `Unknown support/social/group reference ${id}.`);
    }
    if (node.campaignId && !content.campaigns?.[node.campaignId]) add('UNKNOWN_CAMPAIGN_REFERENCE', 'error', `${at}/campaignId`, `Unknown campaign ${node.campaignId}.`);
    if (node.coverCampaignId && !content.campaigns?.[node.coverCampaignId]) add('UNKNOWN_CAMPAIGN_REFERENCE', 'error', `${at}/coverCampaignId`, `Unknown cover campaign ${node.coverCampaignId}.`);
    for (const [key, value] of Object.entries(node)) if (/RouteIds?$/u.test(key)) {
      for (const id of key.endsWith('Ids') ? list(value) : [value]) {
        const route = routeById.get(id);
        if (!route) add('UNKNOWN_ROUTE_REFERENCE', 'error', `${at}/${key}`, `Unknown route ${id}.`);
        else if (route.type !== 'pagina_interna') add('CONTENT_DESTINATION_TYPE_MISMATCH', 'error', `${at}/${key}`, 'Policy/privacy destinations must reference an internal page.', { routeId: id });
        else if (!route.existing || route.status !== 'verificado') add('CONTENT_DESTINATION_PENDING', 'warning', `${at}/${key}`, `Policy route ${id} is not established.`, { routeId: id });
      }
    }
    if (node.catalogIds) for (const id of list(node.catalogIds)) if (!list(content.catalogs).some(catalog => catalog.id === id)) add('UNKNOWN_CATALOG_REFERENCE', 'error', `${at}/catalogIds`, `Unknown catalog ${id}.`);
    for (const [key, group] of [['brandOptionIds', 'brands'], ['categoryOptionIds', 'categories']]) if (node[key]) for (const id of list(node[key])) if (!list(content[group]).some(item => item?.id === id)) add('UNKNOWN_PREFERENCE_OPTION', 'error', `${at}/${key}`, `Unknown ${group} option ${id}.`);
    if (['social', 'group', 'whatsapp', 'web_contact'].includes(node.kind) && typeof node.url === 'string') {
      const backed = supportById.get(node.id)?.url === node.url || [...routeById.values()].some(route => route.existing === node.url);
      if (!backed) add('CONTENT_LINK_UNSUPPORTED', 'error', `${at}/url`, 'Content link differs from the evidenced route/support inventory.');
    }
  };
  walk(content);
  // Slot rules are held by the contract/auditor, not solely by editable input.
  for (const group of ['categories', 'brands']) {
    for (const [index, item] of list(content[group]).entries()) {
      const route = routeById.get(item?.destination?.routeId);
      const allowed = group === 'brands' ? ['coleccion'] : ['coleccion', 'catalogo_externo'];
      if (route && !allowed.includes(route.type)) add('CONTENT_DESTINATION_TYPE_MISMATCH', 'error', `/content/${group}/${index}/destination`, `A ${group} tile cannot target ${route.type}.`, { routeId: route.id });
    }
  }
  for (const [index, catalog] of list(content.catalogs).entries()) {
    const route = routeById.get(catalog?.destination?.routeId);
    if (route && route.type !== 'catalogo_externo') add('CONTENT_DESTINATION_TYPE_MISMATCH', 'error', `/content/catalogs/${index}/destination`, 'Catalogs must reference a catalogo_externo destination.', { routeId: route.id });
    if (!catalog || route?.type !== 'catalogo_externo') continue;
    const at = `/content/catalogs/${index}`;
    const context = { catalogId: catalog.id, routeId: route.id };
    const unknown = [];
    if (!text(catalog.category)) unknown.push('catalog.category');
    if (!text(route.catalogCategory)) unknown.push('route.catalogCategory');
    if (!catalogModes.includes(catalog.mode)) unknown.push('catalog.mode');
    if (!catalogModes.includes(route.catalogMode)) unknown.push('route.catalogMode');
    if (unknown.length) add('CATALOG_IDENTITY_UNCONFIRMED', 'warning', `${at}/destination`, 'Category/mode identity cannot be established from incomplete or non-canonical metadata.', { ...context, missingMetadata: unknown });
    if (text(catalog.category) && text(route.catalogCategory) && catalog.category !== route.catalogCategory) add('CATALOG_CATEGORY_MISMATCH', 'error', `${at}/destination`, `Catalog category ${catalog.category} differs from destination category ${route.catalogCategory}.`, { ...context, expectedCategory: catalog.category, destinationCategory: route.catalogCategory });
    if (catalogModes.includes(catalog.mode) && catalogModes.includes(route.catalogMode) && catalog.mode !== route.catalogMode) add('CATALOG_MODE_MISMATCH', 'error', `${at}/destination`, `Catalog mode ${catalog.mode} differs from destination mode ${route.catalogMode}.`, { ...context, expectedMode: catalog.mode, destinationMode: route.catalogMode });
    // Sharing is governed by the destination, even if the visible label lies.
    if (catalog.shareable === true && route.catalogMode === 'wholesale') add('WHOLESALE_DESTINATION_PUBLIC_SHARE', 'error', `${at}/shareable`, 'A shareable catalog cannot send customers to a wholesale destination.', context);
    if (catalog.shareable === true && !catalogModes.includes(route.catalogMode)) add('CATALOG_SHAREABILITY_UNCONFIRMED', 'warning', `${at}/shareable`, 'Destination mode is unknown; customer-facing sharing cannot be certified.', context);
  }
  for (const [id, selection] of Object.entries(record(content.productSelections) ? content.productSelections : {})) {
    const source = selection?.source;
    // Missing/malformed source descriptors are already required by the V1
    // schema. Resolve references only after there is a descriptor to inspect.
    if (!record(source)) continue;
    const at = `/content/productSelections/${escapePointer(id)}/source`;
    const hasRoute = text(source.routeId);
    const routeField = Object.hasOwn(source, 'routeId');
    const handlesField = Object.hasOwn(source, 'handles');
    const validHandles = Array.isArray(source.handles) && source.handles.length > 0 && source.handles.every(text) && new Set(source.handles).size === source.handles.length;
    if (source.kind === 'collection' && !hasRoute) add('SELECTION_ROUTE_REQUIRED', 'error', `${at}/routeId`, 'A collection selection requires a non-empty collection routeId.');
    if (source.kind === 'curated') {
      if (routeField && handlesField) add('SELECTION_SOURCE_AMBIGUOUS', 'error', at, 'Curated selections must choose a collection route or explicit handles, not both.');
      if (!hasRoute && !validHandles) add('SELECTION_SOURCE_UNRESOLVED', 'error', at, 'Curated selection needs a collection route or a non-empty unique list of product handles.');
      if (handlesField && !validHandles) add('SELECTION_HANDLES_INVALID', 'error', `${at}/handles`, 'Product handles must be a non-empty list of unique non-blank strings.');
    }
    if (hasRoute && ['collection', 'curated', 'newest'].includes(source.kind)) {
      const route = routeById.get(source.routeId);
      if (!route || !text(route.existing) || ['propuesto', 'desconocido'].includes(route.status)) add('SELECTION_DESTINATION_UNRESOLVED', 'error', `${at}/routeId`, 'Selection route must identify an existing destination in the inventory.', { routeId: source.routeId });
      if (route && route.type !== 'coleccion') add('SELECTION_DESTINATION_TYPE_MISMATCH', 'error', `${at}/routeId`, `Selection destination is ${route.type}; a collection is required.`, { routeId: route.id });
    }
  }
  for (const [key, capability] of Object.entries(baseline.capabilities ?? {})) checkedEvidence(capability.evidence, `/capabilities/${key}`);
  for (const policy of requirements.selectionPolicies ?? []) {
    const actual = content.productSelections?.[policy.id]?.source?.ordering;
    if (actual !== policy.expectedOrdering) add('PRODUCT_SELECTION_ORDER_MISMATCH', 'error', `/content/productSelections/${policy.id}/source/ordering`, `Required ${policy.expectedOrdering}; available ${actual ?? 'unknown'}.`);
  }
  for (const cover of requirements.requiredListingCovers ?? []) {
    const tile = [...list(content.categories), ...list(content.brands)].find(tile => tile?.destination?.routeId === cover.routeId);
    if (!tile?.coverCampaignId || !content.campaigns?.[tile.coverCampaignId]) add('LISTING_COVER_MISSING', 'error', `/content/cover/${cover.routeId}`, 'The listing needs campaign art/copy distinct from its brand logo or category tile.', { routeId: cover.routeId, screens: cover.pdfPages });
  }
  const modules = list(content.home?.moduleOrder);
  for (const id of requirements.requiredHomeModules ?? []) if (!modules.some(module => module.id === id)) add('HOME_MODULE_MISSING', 'warning', '/content/home/moduleOrder', `Missing shared home module ${id}.`);
  for (const [index, module] of modules.entries()) {
    const at = `/content/home/moduleOrder/${index}/contentRef`;
    const reference = module?.contentRef;
    const value = getPath(content, reference);
    const context = { moduleId: module?.id, kind: module?.kind, contentRef: reference };
    if (!nonEmpty(value)) { add('HOME_MODULE_CONTENT_MISSING', 'error', at, `Module refers to unavailable content ${reference}.`, context); continue; }
    const family = Object.hasOwn(moduleFamilies, module.kind) ? moduleFamilies[module.kind] : null;
    if (!family) { add('HOME_MODULE_KIND_UNKNOWN', 'error', at, `Unknown module kind ${module.kind}.`, context); continue; }
    if (typeof reference !== 'string' || !family.pattern.test(reference)) { add('HOME_MODULE_FAMILY_MISMATCH', 'error', at, `Module kind ${module.kind} cannot reference family ${reference}.`, context); continue; }
    const schema = family.definition ? contract.$defs?.[family.definition] : contract.properties?.[family.property];
    if (!schema) { add('HOME_MODULE_SCHEMA_MISSING', 'error', at, `No schema is available to validate module family ${module.kind}.`, context); continue; }
    const targetPath = `/content/${reference.split('.').map(escapePointer).join('/')}`;
    const errors = validateSchema(value, schema, contract, targetPath);
    if (errors.length) add('HOME_MODULE_CONTENT_INVALID', 'error', at, `Referenced ${module.kind} content does not satisfy its V1 structure.`, { ...context, validationErrors: errors });
  }
  if (content.rewards && (content.rewards.model !== 'mxn_balance_v1' || content.rewards.currency !== 'MXN' || content.rewards.authority !== 'accounts_orders')) add('REWARDS_CONTRACT_CHANGED', 'error', '/content/rewards', 'Keep the implemented MXN balance model and accounts_orders authority.');
  for (const claim of baseline.decisions ?? []) {
    checkedEvidence(claim.sources, `/decisions/${claim.id}`);
    if (claim.status !== 'resolved') add('COMMERCIAL_DECISION_REQUIRED', 'warning', `/decisions/${claim.id}`, claim.summary, { decisionId: claim.id, evidence: claim.sources });
  }
  for (const [at, refs] of Object.entries(baseline.provenance ?? {})) checkedEvidence(refs, `/provenance/${at}`);
  for (const mapping of fieldMap.fields ?? []) {
    checkedEvidence(mapping.sources, `/fieldMap/${mapping.id}`);
    if (mapping.status !== 'existing') add('CONTENT_CONTRACT_GAP', 'warning', `/fieldMap/${mapping.id}`, `${mapping.status}: ${mapping.summary}`, { fieldId: mapping.id, screens: mapping.pdfPages });
  }
  for (const requirement of requirements.templateRequirements ?? []) {
    const text = snapshots[requirement.source];
    if (!text) { add('TEMPLATE_SOURCE_MISSING', 'error', requirement.source, 'Required template has no captured source.'); continue; }
    try {
      const template = parseShopifyJson(text);
      if (template.layout !== requirement.layout) add('TEMPLATE_LAYOUT_PENDING', 'warning', requirement.source, `Current layout ${template.layout ?? 'theme (default)'}; required ${requirement.layout}.`, { screens: requirement.pdfPages });
    } catch { add('TEMPLATE_INVALID_JSON', 'error', requirement.source, 'Cannot parse captured Shopify template.'); }
  }
  for (const [group, ids] of Object.entries(requirements.requiredItems ?? {})) {
    const available = new Set(list(content[group]).map(item => item.id));
    for (const id of ids) if (!available.has(id)) add('DESIGN_CONTENT_MISSING', 'error', `/content/${group}/${id}`, `Required design item ${id} is absent; no business/catalog data is inferred.`);
  }
  const coverage = [];
  for (const screen of requirements.screens ?? []) {
    const missing = [];
    for (const dotted of screen.requiredPaths ?? []) if (!nonEmpty(getPath(content, dotted))) {
      missing.push(dotted);
      const at = `/content/${dotted.replaceAll('.', '/')}`;
      if (!findings.some(finding => finding.path === at && finding.severity === 'error')) add('SCREEN_CONTENT_MISSING', 'error', at, `PDF ${screen.page}: required content ${dotted} is unavailable.`, { screens: [screen.page] });
    }
    for (const key of screen.requiredCapabilities ?? []) {
      if (baseline.capabilities?.[key]?.status !== 'available') add('CAPABILITY_NOT_READY', 'warning', `/capabilities/${key}`, `PDF ${screen.page}: ${key} is ${baseline.capabilities?.[key]?.status ?? 'unknown'}.`, { screens: [screen.page] });
    }
    const problems = findings.filter(finding => finding.screens?.includes(screen.page) || (finding.routeId && (screen.routeIds ?? []).includes(finding.routeId)) || (screen.requiredPaths ?? []).some(dotted => finding.path === `/content/${dotted.replaceAll('.', '/')}` || finding.path.startsWith(`/content/${dotted.replaceAll('.', '/')}/`)));
    coverage.push({ page: screen.page, title: screen.title, status: problems.length ? 'pending' : 'available_in_snapshot', missingPaths: missing, findingCount: problems.length });
  }
  const pages = (requirements.screens ?? []).map(screen => screen.page);
  if (pages.length !== 19 || new Set(pages).size !== 19 || pages.some(page => !Number.isInteger(page) || page < 1 || page > 19)) add('PDF_COVERAGE_INCOMPLETE', 'error', '/requirements/screens', 'Requirements must cover exactly PDF pages 1-19.');

  for (const finding of findings) if (finding.evidence) finding.evidence = finding.evidence.map(ref => {
    const source = sourceByPath.get(ref.source);
    const text = snapshots[ref.source];
    const start = ref.needle && typeof text === 'string' ? text.indexOf(ref.needle) : -1;
    return { ...ref, ...(source ? { capturedAt: source.capturedAt, sha256: source.sha256 } : {}), ...(start >= 0 ? { line: text.slice(0, start).split('\n').length } : {}) };
  });
  findings.sort((a, b) => a.code.localeCompare(b.code, 'en') || a.path.localeCompare(b.path, 'en') || a.message.localeCompare(b.message, 'en'));
  const unique = findings.filter((finding, index) => index === 0 || JSON.stringify(finding) !== JSON.stringify(findings[index - 1]));
  const counts = { error: 0, warning: 0, info: 0 };
  const byCode = {};
  for (const finding of unique) { counts[finding.severity]++; byCode[finding.code] = (byCode[finding.code] ?? 0) + 1; }
  const routesByStatus = Object.fromEntries(statuses.map(status => [status, (routeMap.routes ?? []).filter(route => route.status === status).length]));
  return { auditVersion: AUDIT_VERSION, mode: 'offline-frozen-sources', contractVersion: content.contractVersion,
    sourceCaptureCompletedAt: manifest.captureCompletedAt,
    inputSha256: sha256(JSON.stringify({ contract, baseline, routeMap, requirements, fieldMap, manifest })),
    ready: counts.error === 0 && counts.warning === 0, summary: { ...counts, total: unique.length, byCode, routes: { total: routeMap.routes?.length ?? 0, byStatus: routesByStatus }, screens: { total: coverage.length, pending: coverage.filter(screen => screen.status === 'pending').length } },
    coverage, findings: unique };
}

export function renderReport(report) {
  const lines = ['# Monetta: auditoría de contenido', '', `Auditor: ${report.auditVersion}. Contrato: ${report.contractVersion}. Modo: ${report.mode}.`,
    `Cierre de captura: ${report.sourceCaptureCompletedAt}.`, `Huella de entradas: \`${report.inputSha256}\`.`, '',
    `Resultado: ${report.ready ? 'listo en la instantánea' : 'pendiente'}. ${report.summary.error} errores de preparación, ${report.summary.warning} pendientes/avisos.`, '',
    'Los errores describen contenido/contrato faltante, no fallos del proceso. No se consultó Shopify ni se ejecutaron builds.', '',
    '| PDF | Pantalla | Estado | Hallazgos |', '| --- | --- | --- | --- |',
    ...report.coverage.map(screen => `| ${screen.page} | ${screen.title} | ${screen.status} | ${screen.findingCount} |`), '',
    '| Código | Cantidad |', '| --- | --- |', ...Object.entries(report.summary.byCode).map(([code, count]) => `| ${code} | ${count} |`), '',
    '## Hallazgos', ''];
  for (const finding of report.findings) {
    lines.push(`- **${finding.severity} · ${finding.code}** — \`${finding.path}\`: ${finding.message}`);
    for (const ref of finding.evidence ?? []) lines.push(`  Fuente: \`${ref.source}\`${ref.needle ? `; extracto: ${JSON.stringify(ref.needle)}` : ''}.`);
  }
  if (report.liveComparison) {
    lines.push('', '## Comparación local posterior', '', 'Esta sección compara huellas; conserva los hallazgos de la captura original.', '');
    for (const source of report.liveComparison.sources) if (source.status !== 'unchanged') lines.push(`- ${source.status}: \`${source.path}\`.`);
    lines.push(`Fuentes sin cambio: ${report.liveComparison.sources.filter(source => source.status === 'unchanged').length}.`);
  }
  return `${lines.join('\n')}\n`;
}
