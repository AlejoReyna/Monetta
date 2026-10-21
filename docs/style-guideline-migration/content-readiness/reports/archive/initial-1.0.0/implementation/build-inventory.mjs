#!/usr/bin/env node
// Rebuild only the inventory from the immutable local capture. No Shopify calls.
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { defaultDataDir as dataDir } from './capture-sources.mjs';

const manifest = JSON.parse(await readFile(path.join(dataDir, 'evidence/source-manifest.json'), 'utf8'));
const texts = {};
for (const source of manifest.sources) if (source.snapshot) texts[source.path] = await readFile(path.join(dataDir, 'evidence', source.snapshot), 'utf8');
const ref = (source, needle, value, method = 'literal') => {
  if (!texts[source]?.includes(needle)) throw new Error(`Missing anchor in ${source}: ${needle}`);
  return { source, needle, ...(value === undefined ? {} : { value, method }) };
};
const routes = [];
const add = (id, requestedByDesign, type, existing, sources, pdfPages, extra = {}) => {
  const row = { id, requestedByDesign, pdfPages, type, existing, representation: 'literal',
    status: existing ? 'verificado' : 'desconocido', sources, aliases: [],
    verification: { scope: 'local_reference_only', onlineIdentity: 'unknown', onlineAccess: 'not_checked' }, ...extra };
  routes.push(row);
  return row;
};
const H = 'lib/domain/home_content.dart';
const HS = 'lib/features/home/home_screen.dart';
const HEADER = 'storefront-theme/sections/monetta-header.liquid';
const INDEX = 'storefront-theme/templates/index.json';
const MAYOREO = 'storefront-theme/templates/page.mayoreo.json';
const CONTACT = 'storefront-theme/templates/page.contact.json';
const PARTNER = 'storefront-theme/templates/page.como-vender.json';
const EDITORIAL = 'lib/domain/editorial_content.dart';
const FOOTER = 'storefront-theme/sections/monetta-footer.liquid';
const liquid = (id, label, type, value, source, pages, extra = {}) => add(id, label, type, value,
  [ref(source, `href="{{ ${value} }}"`, value)], pages, { representation: 'liquid', ...extra });
const native = (id, label, type, value, source, needle, pages, extra = {}) => add(id, label, type, value,
  [ref(source, needle, value)], pages, { representation: 'flutter', ...extra });

liquid('home', 'Inicio', 'pagina_interna', 'routes.root_url', HEADER, [1, 3, 4, 17, 19], { nativeBinding: 'HomeScreen' });
native('welcome.native', 'Bienvenida', 'pagina_interna', 'WelcomeScreen', 'lib/features/welcome/welcome_screen.dart', 'class WelcomeScreen extends StatelessWidget', [1], { notes: ['Primera visita con WelcomeGate; la bienvenida web se adapta al hero.'] });
native('preferences.native', 'Personalización', 'pagina_interna', 'OnboardingSheet', 'lib/features/onboarding/onboarding_sheet.dart', 'class OnboardingSheet extends StatefulWidget', [2, 13], { issues: ['Tipo de compra del PDF ausente de preferencias actuales.'] });
add('catalog.all', 'Todos los productos', 'coleccion', '/collections/all', [ref(INDEX, '"button_2_link": "/collections/all"', '/collections/all')], [3, 4, 18, 19], {
  nativeBinding: 'openCatalogBrowse', aliases: [{ value: '/collections/todos-los-productos-1', equivalent: null, rewriteAllowed: false, reason: 'Handle heredado; equivalencia con all sin probar.', sources: [ref(MAYOREO, '"collection": "todos-los-productos-1"')] }] });
liquid('navigation.categories', 'Pestaña Categorías / directorio', 'coleccion', 'routes.all_products_collection_url', 'storefront-theme/snippets/monetta-dock.liquid', Array.from({ length: 18 }, (_, i) => i + 2), {
  status: 'pendiente', desiredType: 'pagina_interna', proposed: '/collections', nativeBinding: 'MonettaBottomDestination.catalog -> openCatalogBrowse',
  issues: ['El dock abre todos los productos. El PDF pide un directorio. list-collections.json existe con layout Atelier; contenido/publicación sin confirmar.'] });
add('brands.directory', 'Todas las marcas', 'pagina_interna', null, [], [3, 18, 19], { notes: ['onCatalog abre todos los productos; sin directorio dedicado confirmado.'] });
add('selection.newest', 'Nueva colección / novedades', 'coleccion', '/collections/all?sort_by=created-descending', [ref(INDEX, '"button_1_link": "/collections/all?sort_by=created-descending"', '/collections/all?sort_by=created-descending')], [3, 4], {
  issues: ['El enlace ordena por fecha; el carrusel usa el orden de la colección. Colección de campaña curada sin confirmar.'] });
add('selection.todays-picks', 'Catálogo de hoy', 'coleccion', '/collections/monetta-todays-picks', [ref('lib/data/shopify/featured_catalog_repository.dart', "'handle': 'monetta-todays-picks'", 'monetta-todays-picks', 'collection_handle')], [3, 4, 11], {
  status: 'pendiente', requiresEntityVerification: true, issues: ['Flutter usa monetta-todays-picks; Selección en templates/index.json usa all. No son equivalentes.'] });
add('selection.popular', 'Lo más buscado / populares', 'coleccion', null, [], [4], { notes: ['Sin selección compartida ni autoridad de ranking confirmada.'] });

// Restrict extraction to static fallbacks, never constructors/copyWith methods.
const homeSeeds = texts[H].split('static const fallback = HomeContent(')[1];
if (!homeSeeds) throw new Error('HomeContent fallback marker changed.');
export const blocks = (text, name, spaces) => [...text.matchAll(new RegExp(`${name}\\(\\n([\\s\\S]*?)\\n {${spaces}}\\),`, 'gu'))].map(match => match[1]);
export const stringField = (block, name) => {
  const value = block.match(new RegExp(`${name}:\\s*'([^']+)'`, 'u'))?.[1];
  if (!value) throw new Error(`Missing literal ${name} in seed.`);
  return value;
};
const categories = blocks(homeSeeds, 'HomeCollectionCard', 6);
const categoryIds = ['bags', 'wallets', 'watches', 'tote', 'crossbody', 'shoulder', 'satchel', 'hobo'];
if (categories.length !== categoryIds.length) throw new Error('Review category seed changes before rebuilding.');
for (const [index, block] of categories.entries()) {
  const id = categoryIds[index];
  const handle = stringField(block, 'handle');
  const row = add(`category.${id}`, stringField(block, 'title'), 'coleccion', `/collections/${handle}`,
    [ref(H, block.trim().split('fallbackAsset:')[0].trimEnd(), handle, 'collection_handle')], [2, 3, 5, 6, 9, 18, 19], {
      status: 'pendiente', requiresEntityVerification: true,
      nativeBinding: 'CollectionFilter(collectionHandle, category, silhouette); menú principal filtra category',
      entityObservations: [{ store: 'monetta-staging.myshopify.com', observedAt: '2026-10-19', state: 'dated_report_only', observation: 'Entrega informa ausencia de colecciones de navegación; no es una consulta actual.', source: 'docs/web-redesign/shopify-staging/ENTREGA.md' }] });
  if (id === 'bags') Object.assign(row, { mustDifferFrom: ['brand.guess'], issues: ['guess es Bolsas; guess-1 es la marca Guess. No fusionar.'] });
  if (['wallets', 'watches'].includes(id)) {
    const alias = id === 'wallets' ? 'carteras' : 'relojes-1';
    const key = id === 'wallets' ? '4' : '5';
    row.aliases = [{ value: `/collections/${alias}`, equivalent: null, rewriteAllowed: false, reason: 'Handle heredado distinto; confirmar identidad y redirección.', sources: [ref(PARTNER, `"collection_${key}": "${alias}"`)] }];
  }
  if (['satchel', 'hobo'].includes(id)) row.issues = [`Fallback reutiliza arte de ${id === 'satchel' ? 'tote' : 'shoulder'}; falta arte específico aprobado.`];
}
for (const [id, label] of [['handbags', 'Handbags'], ['accessories', 'Accesorios']]) add(`category.${id}`, label, 'coleccion', null, [], [2, 6, 9, 18], { notes: ['Sin handle o filtro dedicado respaldado; no inferirlo del PDF.'] });
native('category.perfume.native', 'Perfumes: listado nativo', 'coleccion', '_openCatalogSection', HS, "onPerfumes: () => _openCatalogSection(\n        title: 'Perfumes',\n        queryTerms: const ['perfume', 'fragancia'],", [2, 5, 18, 19], {
  issues: ['Búsqueda de productos propios por términos; no acredita /collections/perfumes ni equivalencia con el catálogo PDF externo.'] });
native('category.beauty.native', 'Maquillaje y skincare: listado nativo', 'coleccion', '_openCatalogSection', HS, "onBeauty: () => _openCatalogSection(\n        title: 'Maquillaje y skincare',\n        queryTerms: const ['maquillaje', 'skincare'],", [19], {
  issues: ['Productos propios y catálogos externos de beauty son destinos distintos.'] });
for (const block of blocks(homeSeeds, 'HomeBrandCard', 6)) {
  const handle = stringField(block, 'handle');
  const id = ({ 'guess-1': 'guess', olalplex: 'olaplex', 'christian-dior': 'dior' })[handle] ?? handle;
  const row = add(`brand.${id}`, stringField(block, 'title'), 'coleccion', `/collections/${handle}`,
    [ref(H, block.trim().split('fallbackAsset:')[0].trimEnd(), handle, 'collection_handle')], [2, 3, 6, 9, 18, 19], {
      status: 'pendiente', requiresEntityVerification: true, catalogBrandKey: stringField(block, 'brand'),
      nativeBinding: `CollectionFilter(brand: ${stringField(block, 'brand')})` });
  if (id === 'guess') Object.assign(row, { mustDifferFrom: ['category.bags'], issues: ['guess-1 es marca Guess. El clic nativo filtra brand: Guess.'] });
  if (id === 'olaplex') Object.assign(row, { issues: ['El valor configurado es olalplex; no corregir sin comprobar la entidad.'], aliases: [{ value: '/collections/olaplex', equivalent: null, rewriteAllowed: false, reason: 'Candidato ortográfico, sin prueba de equivalencia.', sources: [ref(H, "handle: 'olalplex'")] }] });
  if (id === 'dior') row.issues = ['Dior es etiqueta visible; Christian Dior es clave de marca. No sustituir taxonomía por etiqueta.'];
}
for (const [id, label] of [['tory-burch', 'Tory Burch'], ['kate-spade', 'Kate Spade'], ['marc-jacobs', 'Marc Jacobs'], ['ch', 'CH (identidad comercial por confirmar)']]) add(`brand.${id}`, label, 'coleccion', null, [], [2, 3, 18], { notes: ['Ilustrada en el PDF; surtido, handle y logo autorizado sin evidencia.'] });

liquid('search', 'Búsqueda', 'pagina_interna', 'routes.search_url', HEADER, [5], { nativeBinding: 'openSearch', issues: ['GET /search existe; la entrega del tema excluye predictive search.'] });
add('product.detail', 'Ficha de producto real', 'producto', 'product.url', [ref('storefront-theme/snippets/monetta-card.liquid', 'product.url', 'product.url')], [7, 8, 17], { representation: 'liquid', notes: ['URL desde producto real de cada tienda. Ningún precio/producto ilustrativo se fija en el contrato.'] });
native('product.preview.native', 'Preview del producto', 'producto', 'showProductQuickView', 'lib/features/product/quick_view.dart', 'Future<void> showProductQuickView(', [7], { issues: ['Existe nativo; quick view Shopify pendiente. Sin cantidad nativa fiable para urgencia numérica.'] });
liquid('cart', 'Carrito / bolsa', 'pagina_interna', 'routes.cart_url', HEADER, [7, 8, 17], { nativeBinding: 'openBag' });
add('wholesale.web', 'Mayoreo', 'pagina_interna', '/pages/mayoreo', [ref(CONTACT, '"button_link": "shopify://pages/mayoreo"', 'mayoreo', 'page_handle')], [4, 10, 11, 13], { issues: ['Plantilla con layout Atelier; asignación y reglas comerciales pendientes por tienda.'] });
add('partner.web', 'Vende con Monetta / compartir catálogos', 'pagina_interna', '/pages/como-vender', [ref(MAYOREO, '"button_link": "shopify://pages/como-vender"', 'como-vender', 'page_handle')], [10, 11, 15, 19], { issues: ['como-vender es página; vende-con-monetta es handle del metaobject. No implica atribución o comisiones.'] });
native('partner.native', 'Hub de catálogos y cotización', 'pagina_interna', 'PartnerHubScreen', HS, 'builder: (_) => PartnerHubScreen(', [10, 11, 15, 19], { issues: ['Home abre PartnerHubScreen, sin abrir WholesaleScreen.'] });
native('wholesale.native', 'Pantalla de mayoreo', 'pagina_interna', 'WholesaleScreen', 'lib/features/wholesale/wholesale_screen.dart', 'class WholesaleScreen extends StatelessWidget', [10, 11], { status: 'pendiente', issues: ['Clase existente; sin invocación activa encontrada desde home/cuenta. Revisar unificación con PartnerHubScreen.'] });
add('contact.web', 'Contacto', 'pagina_interna', 'https://monetta.mx/pages/contact', [ref('lib/features/contact/contact_screen.dart', "Uri.parse('https://monetta.mx/pages/contact')", 'https://monetta.mx/pages/contact')], [11, 16, 19], {
  aliases: [{ value: '/pages/contact', equivalent: null, rewriteAllowed: false, reason: 'Candidato relativo para conservar tienda activa; nativo actual apunta a producción.', sources: [ref(PARTNER, '"button_link": "shopify://pages/contact"')] }],
  issues: ['Evitar salto a producción desde tema staging; contact usa Atelier.'] });
native('contact.native', 'Contacto nativo', 'pagina_interna', 'openContact', 'lib/features/contact/contact_screen.dart', 'Future<void> openContact(', [16, 19], { issues: ['Cuenta abre ContactScreen; menú home abre WhatsApp. Grupos residen en PartnerHubScreen.'] });
liquid('account.hosted', 'Mi cuenta web', 'cuenta_alojada', 'routes.account_url', HEADER, [12, 13, 14], { issues: ['Resolver con routes.account_url. Configuración de cuentas, capacidades y Rewards web no certificados.'] });
native('account.native', 'Mi cuenta nativa', 'pagina_interna', 'openAccount', HS, 'openAccount(\n        context,', [13]);
native('orders.native', 'Mis pedidos', 'pagina_interna', 'openOrders', 'lib/features/orders/orders_screen.dart', 'Future<void> openOrders(', [12, 17]);
for (const [id, label] of [['orders.hosted', 'Pedidos web'], ['addresses.hosted', 'Direcciones'], ['payments.hosted', 'Métodos de pago']]) add(id, label, 'cuenta_alojada', null, [], id === 'orders.hosted' ? [12, 13, 17] : [13], { notes: ['Entrada account.hosted disponible; subdestino sin validar. No inventar subrutas de cuenta.'] });
native('rewards.native', 'Monetta Rewards en MXN', 'pagina_interna', 'RewardsSection', 'lib/features/rewards/rewards_section.dart', 'class RewardsSection extends StatefulWidget', [13, 14, 15], { issues: ['Autoridad accounts_orders. Sin conversión a puntos/niveles ni premios por compartir.'] });
add('rewards.hosted', 'Rewards web', 'cuenta_alojada', null, [], [13, 14], { notes: ['Sin extensión/destino autenticado probado.'] });
native('favorites.native', 'Favoritos', 'pagina_interna', 'openFavorites', 'lib/features/favorites/favorites_screen.dart', 'Future<void> openFavorites(', [6, 7, 8, 13]);
add('favorites.web', 'Favoritos web', 'pagina_interna', null, [], [6, 7, 8, 13], { status: 'propuesto', proposed: '/pages/favoritos', notes: ['Propuesto por prototipo/handoff, pendiente en entrega del tema.'] });
native('notifications.native', 'Notificaciones', 'pagina_interna', 'openAccountNotifications', 'lib/features/account/account_screen.dart', 'onTap: openAccountNotifications', [13, 19]);
add('preferences.web', 'Preferencias web', 'pagina_interna', null, [], [2, 13], { status: 'propuesto' });
native('confirmation.native', 'Confirmación real de compra', 'pagina_interna', 'OrderConfirmationScreen', 'lib/features/checkout/order_confirmation_screen.dart', 'class OrderConfirmationScreen extends StatelessWidget', [17], { notes: ['PDF 17 es confirmación, sin formulario de pago. Totales/número sólo desde pedido real.'] });
add('confirmation.hosted', 'Gracias / estado del pedido web', 'pagina_interna', null, [], [17], { status: 'pendiente', representation: 'capability', hosting: 'shopify_checkout_order_status', notes: ['Página alojada de Shopify/checkout fuera de Liquid; distinta de Customer Accounts. URL generada por pedido y capacidades sin verificar.'] });
liquid('footer.policies', 'Políticas publicadas', 'pagina_interna', 'policy.url', FOOTER, [4, 11], { issues: ['shop.policies dinámico; falta inventario de políticas publicadas por tienda.'] });
for (const [id, label] of [['faq', 'Preguntas frecuentes'], ['shipping', 'Envíos'], ['returns', 'Cambios y devoluciones'], ['privacy', 'Aviso de privacidad'], ['terms', 'Términos y condiciones'], ['purchase-policy', 'Política de compra'], ['distribution', 'Política de distribución']]) add(`help.${id}`, label, 'pagina_interna', null, [], [4, 11], { notes: ['Pie del PDF, sin destino/publicación respaldados. Usar sólo menús/políticas efectivamente publicados.'] });

const editorialSeeds = texts[EDITORIAL].split('static const fallback = MonettaEditorialContent(')[1];
if (!editorialSeeds) throw new Error('Editorial fallback marker changed.');
const catalogBlocks = blocks(editorialSeeds, 'PartnerCatalog', 8);
if (catalogBlocks.length !== 9) throw new Error('Review catalog changes before rebuilding.');
for (const block of catalogBlocks) {
  const url = stringField(block, 'url');
  const wire = block.match(/mode: PartnerCatalogMode\.(\w+)/u)?.[1];
  const mode = ({ wholesale: 'wholesale', suggestedPrices: 'suggested_prices', noPrices: 'no_prices' })[wire];
  add(`catalog.${stringField(block, 'id')}`, `${stringField(block, 'categoryLabel')} / ${mode}`, 'catalogo_externo', url,
    [ref(EDITORIAL, url, url), ref(PARTNER, url, url)], [10, 11, 15, 18, 19], {
      catalogMode: mode, catalogCategory: stringField(block, 'category'), remoteContentReview: 'unknown',
      notes: ['URL coincide entre fallback nativo y tema heredado. Acceso, identidad y vigencia del documento remoto sin comprobar.'] });
}

const supportLinks = [];
const link = (id, label, url, kind, sources, extra = {}) => supportLinks.push({ id, label, url, kind, sources, ...extra });
link('whatsapp', 'WhatsApp 826 106 6868', 'https://wa.me/528261066868', 'whatsapp', [ref('lib/app/shopper_copy.dart', "const String kWhatsAppE164 = '528261066868';"), ref('storefront-theme/sections/monetta-footer-group.json', '"whatsapp_number": "528261066868"')], { uriConstruction: 'conciergeWhatsAppUri: Uri.https(wa.me, /kWhatsAppE164, text)' });
for (const [id, label, url] of [
  ['group-whatsapp-1', 'Grupo 1', 'https://chat.whatsapp.com/CFdzcaBHZlsJqtETPHvtec'],
  ['group-whatsapp-2', 'Grupo 2', 'https://chat.whatsapp.com/Kob3rTxvWzO53KVtXxS9DC'],
  ['group-facebook', 'Grupo de Facebook', 'https://www.facebook.com/share/g/1937VZAXta/'],
]) link(id, label, url, 'group', [ref('lib/features/partner/partner_hub_screen.dart', url), ref(CONTACT, url)], { remoteMembership: 'not_checked' });
for (const block of blocks(homeSeeds, 'HomeSocialLink', 6)) {
  const url = stringField(block, 'url');
  link(stringField(block, 'id'), stringField(block, 'label'), url, 'social', [ref(H, url), ref(CONTACT, url)], { notes: ['Contact añade tracking. Mantener el query id de Facebook porque identifica el perfil.'] });
}
const result = {
  schemaVersion: '1.0.0', capturedFrom: 'evidence/source-manifest.json',
  statusDefinitions: {
    verificado: 'Referencia exacta comprobada contra fuente local congelada. No certifica publicación, membresía, acceso ni contenido remoto.',
    pendiente: 'Requiere implementación, alineación de destino o confirmación por tienda.',
    propuesto: 'Alternativa sin asumir entidad/ruta desplegada.', desconocido: 'Sin evidencia de destino exacto.',
  },
  types: { coleccion: 'Listado/selección de productos, incluido filtro nativo (no infiere handle Shopify).', producto: 'Producto real o preview.', pagina_interna: 'Pantalla, búsqueda, bolsa, política o confirmación; hosting se indica aparte.', cuenta_alojada: 'Cuenta web y sus pedidos; no asume subrutas/capacidades y no equivale al checkout.', catalogo_externo: 'Documento público externo; no implica importar productos a Shopify.' },
  trustedCatalogHosts: ['canva.link', 'canva.com', 'www.canva.com', 'drive.google.com', 'docs.google.com', 'monetta.mx', 'www.monetta.mx'],
  routePolicy: { internalShopify: 'Resolver en tienda/locale activos con routes y resource URLs. Contacto absoluto describe sólo enlace nativo actual.', externalCatalogs: 'Preservar IDs, mayúsculas y queries significativos. Sin reescritura o confianza automática en redirecciones.', pdfExamples: 'monetta.com/catalogo/bolsos y /perfumes son ilustrativos.', retiredMonitor: 'ENABLE_EXTERNAL_CATALOG es el agregador retirado; distinto de reseller_catalog. No reactivar.' },
  routes, supportLinks,
};
await writeFile(path.join(dataDir, 'route-map.json'), `${JSON.stringify(result, null, 2)}\n`);
console.log(`${routes.length} routes; ${supportLinks.length} support/social links. Inventory rebuilt from frozen sources.`);
