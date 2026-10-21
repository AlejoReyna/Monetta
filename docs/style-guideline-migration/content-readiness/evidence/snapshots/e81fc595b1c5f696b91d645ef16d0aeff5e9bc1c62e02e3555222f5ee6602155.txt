// Editorial copy and configuration. Every block names its source so the
// handoff can map it to Shopify settings, metaobjects or theme locales.

/** lib/features/catalog/search_screen.dart (kSearchPrompts) */
export const SEARCH_PROMPTS = [
  'Encuentra algo muy tú',
  'Tu próxima favorita espera',
  'Date un gusto, empieza por aquí',
  'Hoy es día de estrenarte',
  'Descubre una pieza para ti',
];

/** lib/domain/home_content.dart (HomeContent.fallback.bagTypes); handles verified live. */
export const STYLE_TILES = [
  { title: 'Totes', handle: 'totes', image: '/media/editorial/home_bag_tote.webp' },
  { title: 'Crossbodys', handle: 'crossbodys', image: '/media/editorial/home_bag_crossbody.webp' },
  { title: 'Hombro', handle: 'hombro', image: '/media/editorial/home_bag_shoulder.webp' },
];

/** lib/domain/home_content.dart (collections) with focal points for cover crops. */
export const COLLECTION_CARDS = [
  { title: 'Bolsas', handle: 'guess', image: '/media/editorial/home_collection_bags.webp', focal: '50% 38%', width: 800, height: 930 },
  { title: 'Carteras', handle: 'carteras-1', image: '/media/editorial/home_collection_wallets.webp', focal: '50% 55%', width: 800, height: 1000 },
  { title: 'Relojes', handle: 'relojes', image: '/media/editorial/home_collection_watches.webp', focal: '50% 50%', width: 800, height: 815 },
];

/**
 * Logo artwork bounds inside the 600px squares, from home_screen.dart
 * (_brandLogoBounds): left, top, right, bottom.
 */
const LOGO_BOUNDS = {
  anne_klein: [68, 269, 546, 320],
  coach: [127, 262, 480, 318],
  dior: [153, 247, 460, 334],
  guess: [127, 254, 486, 330],
  laneige: [87, 260, 514, 331],
  michael_kors: [75, 272, 532, 322],
  olaplex: [88, 262, 525, 338],
  rhode: [120, 233, 491, 336],
  steve_madden: [84, 259, 533, 334],
  summer_fridays: [97, 230, 508, 358],
  the_ordinary: [144, 227, 484, 364],
  tommy_hilfiger: [118, 232, 494, 352],
};

function brand(slug, title, handle) {
  return { slug, title, handle, logo: `/media/brands/${slug}.webp`, bounds: LOGO_BOUNDS[slug] };
}

/** Brands with products in the snapshot: they open their collection. */
export const FASHION_BRANDS = [
  brand('coach', 'Coach', 'coach'),
  brand('michael_kors', 'Michael Kors', 'michael-kors'),
  brand('guess', 'Guess', 'guess-1'),
  brand('steve_madden', 'Steve Madden', 'steve-madden'),
  brand('tommy_hilfiger', 'Tommy Hilfiger', 'tommy-hilfiger'),
];

/** App brands whose Shopify collections have no products: external catalogs. */
export const BEAUTY_BRANDS = [
  brand('christian_dior', 'Dior', null),
  brand('the_ordinary', 'The Ordinary', null),
  brand('laneige', 'Laneige', null),
  brand('rhode', 'Rhode', null),
  brand('summer_fridays', 'Summer Fridays', null),
  brand('olaplex', 'Olaplex', null),
].map((entry) => ({ ...entry, logo: `/media/brands/${entry.slug === 'christian_dior' ? 'dior' : entry.slug}.webp`, bounds: LOGO_BOUNDS[entry.slug === 'christian_dior' ? 'dior' : entry.slug] }));

/** Catalog destinations that still live outside Shopify (plan §1, partner hub). */
export const EXTERNAL_CATALOGS = [
  { id: 'perfumes', title: 'Perfumes', host: 'Google Drive', note: 'Perfumes árabes y de diseñador.' },
  { id: 'beauty', title: 'Maquillaje y skincare', host: 'Google Drive', note: 'Skincare y makeup de marcas como The Ordinary, Laneige y Rhode.' },
];

/** lib/domain/editorial_content.dart (MonettaEditorialContent.fallback.about) */
export const ABOUT = {
  eyebrow: 'Nuestra historia',
  headline: 'Tu boutique y proveedor de confianza.',
  body:
    'Somos una boutique mexicana especializada en productos originales de tus marcas favoritas. Elegimos piezas importadas de Estados Unidos y las acercamos a todo México, tanto para consentirte como para ayudarte a crecer tu negocio.',
  image: '/media/editorial/home_about.webp',
  milestones: [
    { year: '2023', title: 'Aquí comenzó todo', body: 'Abrimos nuestra boutique física en Montemorelos, Nuevo León, y llegaron las primeras ventas a mayoreo.' },
    { year: '2024', title: 'Nos convertimos en boutique online', body: 'Llevamos la experiencia completamente a internet e integramos bolsos, carteras y perfumes.' },
    { year: '2025', title: 'Ampliamos la selección', body: 'Sumamos skincare y maquillaje para ofrecer más formas de comprar y emprender con Monetta.' },
    { year: '2026', title: 'Una nueva era en casa', body: 'Hoy reunimos más de 3,000 productos en nuestros catálogos y enviamos a todo México.' },
    // The app says "Monetta también vive en tu teléfono"; the web uses the live site's wording.
    { year: 'Ahora', title: 'Nuestro sitio web', body: 'Compra tus modelos favoritos con tu proveedor de confianza, disponible 24/7.' },
  ],
  trustFacts: [
    'Productos originales importados de Estados Unidos',
    'Mayoreo y menudeo en un mismo proveedor',
    'Envíos a todo México',
    'Atención personalizada por WhatsApp',
  ],
};

/** lib/domain/editorial_content.dart (partner) and lib/features/partner/partner_hub_screen.dart */
export const PARTNER = {
  eyebrow: 'Vende con Monetta',
  headline: 'Convierte tu buen gusto en un negocio.',
  body:
    'Comparte más de 3,000 productos originales con tus clientes y accede a precios de mayoreo desde tres piezas. Tú eliges qué vender; Monetta te acompaña para hacerlo crecer.',
  note: 'Mayoreo desde 3 piezas · Sin monto mínimo',
  discountTitle: 'Compra más. Tu precio mejora solo.',
  discountBody:
    'Añade al carrito todos los modelos que quieras. El descuento de mayoreo se aplica automáticamente a cada producto antes de pagar.',
  steps: [
    { number: '01', title: 'Elige tu catálogo', body: 'Consulta mayoreo para preparar tu compra o elige una versión con precios sugeridos o sin precios para tus clientes.' },
    { number: '02', title: 'Compártelo', body: 'Envíalo por WhatsApp, mensaje o redes sociales para que tus clientes elijan sus modelos favoritos.' },
    { number: '03', title: 'Cotiza tu pedido', body: 'Mándanos los modelos elegidos para cotizar, apartar o completar la compra.' },
  ],
  terms: [
    { value: '3', label: 'modelos para mayoreo' },
    { value: '$800', label: 'anticipo de apartado, mayoreo' },
    { value: '20 días', label: 'para liquidar un apartado' },
    { value: '100%', label: 'productos originales' },
  ],
  catalogs: [
    { group: 'Bolsas y carteras', mode: 'Mayoreo', description: 'Precios para preparar y cotizar tu pedido.', host: 'Canva' },
    { group: 'Bolsas y carteras', mode: 'Con precios', description: 'Listo para compartir con precios sugeridos de venta.', host: 'Canva' },
    { group: 'Bolsas y carteras', mode: 'Sin precios', description: 'Comparte los modelos y decide tu precio final.', host: 'Canva' },
    { group: 'Skincare y makeup', mode: 'Mayoreo', description: 'Precios para preparar y cotizar tu pedido.', host: 'Google Drive' },
    { group: 'Perfumes', mode: 'Mayoreo', description: 'Precios para preparar y cotizar tu pedido.', host: 'Google Drive' },
  ],
  community: [
    { title: 'Grupos de WhatsApp', body: 'Más de 2,000 miembros con acceso a modelos y ofertas exclusivas.', host: 'WhatsApp' },
    { title: 'Grupo de Facebook', body: 'Más de 21,000 miembros y publicaciones exclusivas de Monetta.', host: 'Facebook' },
  ],
};

/** partner_hub_screen.dart (_wholesaleDetails); matches monetta.mx/pages/mayoreo on 2026-10-17. */
export const FAQ = [
  {
    question: 'Sistema de apartado',
    answer:
      'El apartado es un proceso manual por WhatsApp: Monetta confirma disponibilidad, registra el anticipo y crea el pedido en Shopify. Abrir el chat no reserva existencias ni cobra. Anticipo de referencia: $800 MXN mayoreo / $400 MXN menudeo, liquidación hasta en 20 días.',
  },
  {
    question: 'Productos originales',
    answer:
      'Somos una boutique online especializada en productos originales, con más de tres años de experiencia y verificación como empresa en Estados Unidos: Monetta Wholesale LLC.',
  },
  {
    question: 'Métodos de pago',
    answer: 'Transferencia y depósito bancario, tarjetas de crédito o débito, PayPal, Apple Pay y Mercado Pago. Shopify muestra en el checkout los métodos activos.',
  },
  {
    question: 'Información sobre envíos',
    answer:
      'Enviamos a todo México por FedEx, Estafeta y DHL. Al salir tu pedido recibirás los detalles por correo; la entrega toma entre 2 y 7 días hábiles según tu ubicación.',
  },
  {
    question: 'Políticas de devolución',
    answer:
      'Tienes 48 horas desde la entrega para aclaraciones, cambios o devoluciones, y 72 horas para modificar apartados o cotizaciones. El costo de envío se determina según el motivo de la solicitud.',
  },
  {
    question: 'Productos sobre pedido',
    answer:
      'Los modelos con la insignia “Sobre pedido” se preparan para envío entre 5 y 7 días después del cierre del pedido. El calendario de cierres se publica en la página de preguntas frecuentes.',
  },
];

/** Product page service rows, condensed from the FAQ above. */
export const SERVICE_FACTS = {
  shipping: 'Envíos a todo México por FedEx, Estafeta y DHL · 2 a 7 días hábiles.',
  returns: '48 horas desde la entrega para aclaraciones, cambios o devoluciones.',
  original: 'Producto original importado de Estados Unidos.',
  sobrePedido: 'Sobre pedido: se envía 5 a 7 días después del cierre de pedido.',
  inmediato: 'Envío inmediato: la pieza está lista en el inventario de Monetta.',
};

/** lib/data/shopify/cart_attribution.dart (ApartadoRequest) and the live FAQ. */
export const APARTADO = {
  whatsappDisplay: '826 106 6868',
  retailDeposit: 400,
  wholesaleDeposit: 800,
  days: 20,
};

/** lib/domain/home_content.dart (socialLinks) */
export const SOCIAL_LINKS = [
  { id: 'instagram', label: 'Instagram', handle: '@_monetta.mx', image: '/media/editorial/home_social_instagram.webp' },
  { id: 'tiktok', label: 'TikTok', handle: '@monetta.oficial', image: '/media/editorial/home_social_tiktok.webp' },
  { id: 'facebook', label: 'Facebook', handle: 'Monetta', image: '/media/editorial/home_social_facebook.webp' },
];

/**
 * lib/domain/home_content.dart (testimonials fallback, which mirrors the live
 * Loox carousel). Shown as labelled design samples; Loox supplies real reviews.
 */
export const TESTIMONIALS = [
  {
    reviewer: 'Monse C.',
    body: 'Excelente opción para emprender con productos originales, los precios de mayoreo son los mejores que he encontrado. Ya es mi quinto pedido.',
    rating: 5,
    image: '/media/editorial/home_review_monse.jpg',
  },
  {
    reviewer: 'Gaby E.',
    body: 'Me encanta que todo sea 100% original. Muy bonitos los bolsos y carteras, súper recomendados para negocio. Ya es mi tercer pedido.',
    rating: 5,
    image: '/media/editorial/home_review_gaby.jpg',
  },
  {
    reviewer: 'Guadalupe G.',
    body: 'Mis clientas amaron las bolsas, la calidad viene súper bien. Volveré a pedir.',
    rating: 5,
    image: '/media/editorial/home_review_guadalupe.jpg',
  },
];

/** monetta.mx/pages/contact, 2026-10-17 */
export const CONTACT = {
  eyebrow: '¿Buscas un modelo en especial?',
  headline: 'Estamos listos para ayudarte',
  body:
    'Si necesitas asistencia, información sobre envíos o asesoría sobre mayoreo, escríbenos por WhatsApp o en cualquiera de nuestras redes sociales.',
  whatsappDisplay: '826 106 6868',
};
