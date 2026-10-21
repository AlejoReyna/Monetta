# Monetta: auditoría de contenido

Contrato: 1.0.0. Modo: offline-frozen-sources.
Cierre de captura: 2026-10-20T23:20:50.425Z.
Huella de entradas: `c85b57c140872556d72f691b28c276ae39e0ee4e0c11874a4d4c28b056c5fe90`.

Resultado: pendiente. 47 errores de preparación, 196 pendientes/avisos.

Los errores describen contenido/contrato faltante, no fallos del proceso. No se consultó Shopify ni se ejecutaron builds.

| PDF | Pantalla | Estado | Hallazgos |
| --- | --- | --- | --- |
| 1 | Bienvenida | pending | 7 |
| 2 | Personalización | pending | 55 |
| 3 | Inicio | pending | 79 |
| 4 | Inicio: continuación | pending | 39 |
| 5 | Búsqueda | pending | 52 |
| 6 | Colección / categoría | pending | 58 |
| 7 | Preview del producto | pending | 2 |
| 8 | Producto | pending | 2 |
| 9 | Colección / categoría: variante | pending | 57 |
| 10 | Mayoreo | pending | 18 |
| 11 | Mayoreo: continuación | pending | 18 |
| 12 | Mis pedidos | pending | 3 |
| 13 | Mi cuenta | pending | 8 |
| 14 | Rewards: conservar saldo MXN | pending | 3 |
| 15 | Compartir catálogo | pending | 15 |
| 16 | Contacto | pending | 11 |
| 17 | Confirmación de compra | pending | 4 |
| 18 | Categorías y marcas | pending | 63 |
| 19 | Menú | pending | 10 |

| Código | Cantidad |
| --- | --- |
| CAPABILITY_NOT_READY | 14 |
| CATALOG_CONTENT_UNCONFIRMED | 9 |
| COMMERCIAL_DECISION_REQUIRED | 9 |
| CONTENT_CONTRACT_GAP | 15 |
| CONTENT_DESTINATION_PENDING | 21 |
| DESIGN_CONTENT_MISSING | 6 |
| DESIGN_DESTINATION_TYPE_GAP | 1 |
| DESTINATION_MISSING | 22 |
| DESTINATION_NOT_READY | 23 |
| ENTITY_UNCONFIRMED | 21 |
| HOME_MODULE_MISSING | 10 |
| KNOWN_ROUTE_INCONSISTENCY | 23 |
| LISTING_COVER_MISSING | 1 |
| PRODUCT_SELECTION_ORDER_MISMATCH | 1 |
| REQUIRED_FIELD_MISSING | 23 |
| RESPONSIVE_VISUAL_MISSING | 15 |
| SCREEN_CONTENT_MISSING | 1 |
| TEMPLATE_LAYOUT_PENDING | 5 |
| VISUAL_APPROVAL_PENDING | 23 |

## Hallazgos

- **warning · CAPABILITY_NOT_READY** — `/capabilities/categoryBrandHub`: PDF 18: categoryBrandHub is pending.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/contactGroupCards`: PDF 16: contactGroupCards is pending.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/hostedAccountBranding`: PDF 12: hostedAccountBranding is unknown.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/hostedAccountBranding`: PDF 13: hostedAccountBranding is unknown.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/hostedThankYouBranding`: PDF 17: hostedThankYouBranding is unknown.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/purchaseTypePreference`: PDF 2: purchaseTypePreference is pending.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/rewardsWebIntegration`: PDF 14: rewardsWebIntegration is unknown.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/shopifyFavorites`: PDF 6: shopifyFavorites is pending.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/shopifyFavorites`: PDF 8: shopifyFavorites is pending.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/shopifyPredictiveSearch`: PDF 5: shopifyPredictiveSearch is pending.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/shopifyQuickView`: PDF 7: shopifyQuickView is pending.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/signupSubmission`: PDF 11: signupSubmission is unknown.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/signupSubmission`: PDF 4: signupSubmission is unknown.
- **warning · CAPABILITY_NOT_READY** — `/capabilities/webCatalogSharing`: PDF 15: webCatalogSharing is pending.
- **warning · CATALOG_CONTENT_UNCONFIRMED** — `/routes/69`: Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.
- **warning · CATALOG_CONTENT_UNCONFIRMED** — `/routes/70`: Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.
- **warning · CATALOG_CONTENT_UNCONFIRMED** — `/routes/71`: Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.
- **warning · CATALOG_CONTENT_UNCONFIRMED** — `/routes/72`: Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.
- **warning · CATALOG_CONTENT_UNCONFIRMED** — `/routes/73`: Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.
- **warning · CATALOG_CONTENT_UNCONFIRMED** — `/routes/74`: Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.
- **warning · CATALOG_CONTENT_UNCONFIRMED** — `/routes/75`: Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.
- **warning · CATALOG_CONTENT_UNCONFIRMED** — `/routes/76`: Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.
- **warning · CATALOG_CONTENT_UNCONFIRMED** — `/routes/77`: Saved URL is backed locally; remote document identity/access/validity remain unknown. This is not evidence of a broken link.
- **warning · COMMERCIAL_DECISION_REQUIRED** — `/decisions/brands-and-categories`: Confirmar surtido, identidad CH, cuatro marcas del PDF y Handbags/Accesorios antes de crear tiles, logos o handles.
  Fuente: `docs/MONETTA_STYLE_GUIDELINE_MIGRATION_PLAN.md`; extracto: "Confirm which brands/categories are stocked".
- **warning · COMMERCIAL_DECISION_REQUIRED** — `/decisions/delivery-estimate`: Confirmación muestra 3 a 5 días hábiles, Mayoreo 2 a 7 y PDF 5 a 7. Falta una política compartida confirmada.
  Fuente: `lib/features/checkout/order_confirmation_screen.dart`; extracto: "return '3 a 5 días hábiles';".
  Fuente: `lib/features/wholesale/wholesale_content.dart`; extracto: "La entrega toma entre 2 y 7 días hábiles".
- **warning · COMMERCIAL_DECISION_REQUIRED** — `/decisions/legacy-product-count`: No perpetuar más de 3,000 productos del fallback como cantidad comercial actual.
  Fuente: `lib/domain/editorial_content.dart`; extracto: "Comparte más de 3,000 productos originales con tus clientes y".
- **warning · COMMERCIAL_DECISION_REQUIRED** — `/decisions/share-catalog-mode`: Elegir precios sugeridos o sin precios para compartir. Mayoreo prepara cotización; compartir no prueba vistas/compra ni genera comisión.
  Fuente: `lib/domain/editorial_content.dart`; extracto: "bool get isClientFacing => this != wholesale;".
  Fuente: `lib/features/partner/partner_hub_screen.dart`; extracto: "Opening WhatsApp or a catalog link does not approve reseller status".
- **warning · COMMERCIAL_DECISION_REQUIRED** — `/decisions/shared-store`: La entrega no demuestra catálogo/cuentas/sesiones compartidos. Alinear la tienda por canal antes de validar paridad.
  Fuente: `docs/web-redesign/shopify-staging/ENTREGA.md`; extracto: "No está demostrado que app y web operen sobre la misma tienda".
- **warning · COMMERCIAL_DECISION_REQUIRED** — `/decisions/shipping-offers`: La app publica gratis desde $1,499; PDF muestra otro umbral y oferta signup. Confirmar política sin autorizar incentivos nuevos.
  Fuente: `lib/app/shopper_copy.dart`; extracto: "Envío a todo México · gratis desde".
  Fuente: `docs/MONETTA_STYLE_GUIDELINE_MIGRATION_PLAN.md`; extracto: "The PDF includes $1,999 and 5-7 days".
- **warning · COMMERCIAL_DECISION_REQUIRED** — `/decisions/signup`: Faltan copy aprobado, consentimiento, adapter y privacidad publicada. enabled:false es fallback propuesto; no describe configuración remota.
  Fuente: `docs/MONETTA_STYLE_GUIDELINE_MIGRATION_PLAN.md`; extracto: "Confirm newsletter free-shipping offer".
- **warning · COMMERCIAL_DECISION_REQUIRED** — `/decisions/wholesale-mode`: Cotización manual por producto frente a descuento automático prometido en PartnerHub y tema. Resolver antes de publicar pricingMode.
  Fuente: `lib/features/wholesale/wholesale_content.dart`; extracto: "El precio de mayoreo se define por producto al cotizar".
  Fuente: `lib/features/partner/partner_hub_screen.dart`; extracto: "de mayoreo se aplica automáticamente a cada producto antes".
  Fuente: `storefront-theme/templates/page.mayoreo.json`; extracto: "el descuento de mayoreo se aplicará automáticamente".
- **warning · COMMERCIAL_DECISION_REQUIRED** — `/decisions/wholesale-unit`: 3 modelos, 3 piezas y más de tres piezas no son unidades/umbrales equivalentes. No convertir a tramos nuevos.
  Fuente: `lib/features/wholesale/wholesale_content.dart`; extracto: "static const int minModels = 3;".
  Fuente: `lib/domain/editorial_content.dart`; extracto: "accede a precios de mayoreo desde tres piezas.".
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/brands.list`: extension: Las marcas hoy no se editan como lista desde metafield; cuatro marcas del PDF carecen de seed/arte verificado.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/campaign.copy`: extension: Copy y CTA son independientes por canal; usar IDs estables y destino tipado.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/campaign.media`: extension: Faltan arte por tamaño y focal normalizado 0..1. El tema usa main_image para object-position aunque picture pueda seleccionar wide.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/catalogs.shared-rendering`: extension: Las URLs coinciden, pero tema y app no consumen hoy la misma entidad editorial. first:50 y listas parciales requieren paginación y semántica de desactivación.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/collections.pagination`: extension: Una colección fuera de las primeras 50 puede parecer ausente; no usar ausencia en esa página como prueba negativa.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/contact.shared`: extension: La cuenta llama openContact sin redes runtime; propagar contenido editado y agregar grupos de forma explícita.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/destinations.typed`: extension: Separar colección, página, cuenta y catálogo. Perfumes nativo es filtro por términos; web tiene catálogo externo.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/footer`: extension: Mantener año dinámico y políticas publicadas. Los rótulos del PDF no prueban páginas existentes.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/home.order`: extension: Añadir tipos campaña, mayoreo, servicios, signup y footer; hoy no existe un manifiesto de composición compartido.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/listing.covers`: extension: Separar logo de marca y portada de colección; el PDF usa portada Coach. Sin portada, fallback de encabezado de texto sin logo ampliado.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/preferences.purchase-type`: extension: Añadir persistencia y labels consistentes con unidad comercial; no concede elegibilidad o Rewards de mayoreo.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/products.selections`: extension: Separar novedades por fecha, selección editorial y populares; el enlace sorted no ordena el carrusel.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/services.shared`: extension: Sin fuente compartida; envío gratis, plazos, métodos y devoluciones requieren política coherente.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/signup`: unknown: No hay signup Monetta compartido. Fallback oculta módulo; no usar envío gratis ni simular confirmación.
- **warning · CONTENT_CONTRACT_GAP** — `/fieldMap/wholesale.policy`: decision: Contradicción cotización manual/descuento automático. No usar la preferencia mayoreo como autorización de precios.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/0/destination/routeId`: Content references brand.coach, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/1/destination/routeId`: Content references brand.michael-kors, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/10/destination/routeId`: Content references brand.laneige, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/11/destination/routeId`: Content references brand.rhode, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/2/destination/routeId`: Content references brand.anne-klein, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/3/destination/routeId`: Content references brand.guess, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/4/destination/routeId`: Content references brand.steve-madden, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/5/destination/routeId`: Content references brand.tommy-hilfiger, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/6/destination/routeId`: Content references brand.olaplex, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/7/destination/routeId`: Content references brand.dior, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/8/destination/routeId`: Content references brand.the-ordinary, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/brands/9/destination/routeId`: Content references brand.summer-fridays, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/categories/0/destination/routeId`: Content references category.bags, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/categories/1/destination/routeId`: Content references category.wallets, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/categories/2/destination/routeId`: Content references category.watches, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/categories/3/destination/routeId`: Content references category.tote, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/categories/4/destination/routeId`: Content references category.crossbody, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/categories/5/destination/routeId`: Content references category.shoulder, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/categories/6/destination/routeId`: Content references category.satchel, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/categories/7/destination/routeId`: Content references category.hobo, whose destination is not ready.
- **warning · CONTENT_DESTINATION_PENDING** — `/content/productSelections/todays-picks/source/routeId`: Content references selection.todays-picks, whose destination is not ready.
- **error · DESIGN_CONTENT_MISSING** — `/content/brands/ch`: Required design item ch is absent; no business/catalog data is inferred.
- **error · DESIGN_CONTENT_MISSING** — `/content/brands/kate-spade`: Required design item kate-spade is absent; no business/catalog data is inferred.
- **error · DESIGN_CONTENT_MISSING** — `/content/brands/marc-jacobs`: Required design item marc-jacobs is absent; no business/catalog data is inferred.
- **error · DESIGN_CONTENT_MISSING** — `/content/brands/tory-burch`: Required design item tory-burch is absent; no business/catalog data is inferred.
- **error · DESIGN_CONTENT_MISSING** — `/content/categories/accessories`: Required design item accessories is absent; no business/catalog data is inferred.
- **error · DESIGN_CONTENT_MISSING** — `/content/categories/handbags`: Required design item handbags is absent; no business/catalog data is inferred.
- **warning · DESIGN_DESTINATION_TYPE_GAP** — `/routes/4`: Design requires pagina_interna; current destination is coleccion.
- **warning · DESTINATION_MISSING** — `/routes/17`: No evidenced destination for Handbags.
- **warning · DESTINATION_MISSING** — `/routes/18`: No evidenced destination for Accesorios.
- **warning · DESTINATION_MISSING** — `/routes/33`: No evidenced destination for Tory Burch.
- **warning · DESTINATION_MISSING** — `/routes/34`: No evidenced destination for Kate Spade.
- **warning · DESTINATION_MISSING** — `/routes/35`: No evidenced destination for Marc Jacobs.
- **warning · DESTINATION_MISSING** — `/routes/36`: No evidenced destination for CH (identidad comercial por confirmar).
- **warning · DESTINATION_MISSING** — `/routes/5`: No evidenced destination for Todas las marcas.
- **warning · DESTINATION_MISSING** — `/routes/50`: No evidenced destination for Pedidos web.
- **warning · DESTINATION_MISSING** — `/routes/51`: No evidenced destination for Direcciones.
- **warning · DESTINATION_MISSING** — `/routes/52`: No evidenced destination for Métodos de pago.
- **warning · DESTINATION_MISSING** — `/routes/54`: No evidenced destination for Rewards web.
- **warning · DESTINATION_MISSING** — `/routes/56`: No evidenced destination for Favoritos web.
- **warning · DESTINATION_MISSING** — `/routes/58`: No evidenced destination for Preferencias web.
- **warning · DESTINATION_MISSING** — `/routes/60`: No evidenced destination for Gracias / estado del pedido web.
- **warning · DESTINATION_MISSING** — `/routes/62`: No evidenced destination for Preguntas frecuentes.
- **warning · DESTINATION_MISSING** — `/routes/63`: No evidenced destination for Envíos.
- **warning · DESTINATION_MISSING** — `/routes/64`: No evidenced destination for Cambios y devoluciones.
- **warning · DESTINATION_MISSING** — `/routes/65`: No evidenced destination for Aviso de privacidad.
- **warning · DESTINATION_MISSING** — `/routes/66`: No evidenced destination for Términos y condiciones.
- **warning · DESTINATION_MISSING** — `/routes/67`: No evidenced destination for Política de compra.
- **warning · DESTINATION_MISSING** — `/routes/68`: No evidenced destination for Política de distribución.
- **warning · DESTINATION_MISSING** — `/routes/8`: No evidenced destination for Lo más buscado / populares.
- **warning · DESTINATION_NOT_READY** — `/routes/10`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/11`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/12`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/13`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/14`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/15`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/16`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/21`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/22`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/23`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/24`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/25`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/26`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/27`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/28`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/29`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/30`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/31`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/32`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/4`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/44`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/7`: Destination status: pendiente.
- **warning · DESTINATION_NOT_READY** — `/routes/9`: Destination status: pendiente.
- **warning · ENTITY_UNCONFIRMED** — `/routes/10`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Carteras',\n        handle: 'carteras-1',\n        category: 'cartera',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/11`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Relojes',\n        handle: 'relojes',\n        category: 'reloj',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/12`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Totes',\n        handle: 'totes',\n        category: 'bolsa',\n        silhouette: 'tote',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/13`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Crossbodys',\n        handle: 'crossbodys',\n        category: 'bolsa',\n        silhouette: 'crossbody',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/14`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Hombro',\n        handle: 'hombro',\n        category: 'bolsa',\n        silhouette: 'shoulder',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/15`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Satchel',\n        handle: 'satchel',\n        category: 'bolsa',\n        silhouette: 'satchel',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/16`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Hobo',\n        handle: 'hobo',\n        category: 'bolsa',\n        silhouette: 'hobo',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/21`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Coach',\n        brand: 'Coach',\n        handle: 'coach',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/22`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Michael Kors',\n        brand: 'Michael Kors',\n        handle: 'michael-kors',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/23`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Anne Klein',\n        brand: 'Anne Klein',\n        handle: 'anne-klein',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/24`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Guess',\n        brand: 'Guess',\n        handle: 'guess-1',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/25`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Steve Madden',\n        brand: 'Steve Madden',\n        handle: 'steve-madden',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/26`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Tommy Hilfiger',\n        brand: 'Tommy Hilfiger',\n        handle: 'tommy-hilfiger',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/27`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Olaplex',\n        brand: 'Olaplex',\n        handle: 'olalplex',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/28`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Dior',\n        brand: 'Christian Dior',\n        handle: 'christian-dior',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/29`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'The Ordinary',\n        brand: 'The Ordinary',\n        handle: 'the-ordinary',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/30`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Summer Fridays',\n        brand: 'Summer Fridays',\n        handle: 'summer-fridays',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/31`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Laneige',\n        brand: 'Laneige',\n        handle: 'laneige',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/32`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Rhode',\n        brand: 'Rhode',\n        handle: 'rhode',".
- **warning · ENTITY_UNCONFIRMED** — `/routes/7`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/data/shopify/featured_catalog_repository.dart`; extracto: "'handle': 'monetta-todays-picks'".
- **warning · ENTITY_UNCONFIRMED** — `/routes/9`: A local reference does not establish collection membership/publication in the target store.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Bolsas',\n        handle: 'guess',\n        category: 'bolsa',".
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module brands.
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module campaign.
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module footer.
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module hero.
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module newest.
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module popular.
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module services.
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module signup.
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module styles.
- **warning · HOME_MODULE_MISSING** — `/content/home/moduleOrder`: Missing shared home module wholesale.
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/15`: Fallback reutiliza arte de tote; falta arte específico aprobado.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Satchel',\n        handle: 'satchel',\n        category: 'bolsa',\n        silhouette: 'satchel',".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/16`: Fallback reutiliza arte de shoulder; falta arte específico aprobado.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Hobo',\n        handle: 'hobo',\n        category: 'bolsa',\n        silhouette: 'hobo',".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/19`: Búsqueda de productos propios por términos; no acredita /collections/perfumes ni equivalencia con el catálogo PDF externo.
  Fuente: `lib/features/home/home_screen.dart`; extracto: "onPerfumes: () => _openCatalogSection(\n        title: 'Perfumes',\n        queryTerms: const ['perfume', 'fragancia'],".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/2`: Tipo de compra del PDF ausente de preferencias actuales.
  Fuente: `lib/features/onboarding/onboarding_sheet.dart`; extracto: "class OnboardingSheet extends StatefulWidget".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/20`: Productos propios y catálogos externos de beauty son destinos distintos.
  Fuente: `lib/features/home/home_screen.dart`; extracto: "onBeauty: () => _openCatalogSection(\n        title: 'Maquillaje y skincare',\n        queryTerms: const ['maquillaje', 'skincare'],".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/24`: guess-1 es marca Guess. El clic nativo filtra brand: Guess.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Guess',\n        brand: 'Guess',\n        handle: 'guess-1',".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/27`: El valor configurado es olalplex; no corregir sin comprobar la entidad.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Olaplex',\n        brand: 'Olaplex',\n        handle: 'olalplex',".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/28`: Dior es etiqueta visible; Christian Dior es clave de marca. No sustituir taxonomía por etiqueta.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Dior',\n        brand: 'Christian Dior',\n        handle: 'christian-dior',".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/37`: GET /search existe; la entrega del tema excluye predictive search.
  Fuente: `storefront-theme/sections/monetta-header.liquid`; extracto: "href=\"{{ routes.search_url }}\"".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/39`: Existe nativo; quick view Shopify pendiente. Sin cantidad nativa fiable para urgencia numérica.
  Fuente: `lib/features/product/quick_view.dart`; extracto: "Future<void> showProductQuickView(".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/4`: El dock abre todos los productos. El PDF pide un directorio. list-collections.json existe con layout Atelier; contenido/publicación sin confirmar.
  Fuente: `storefront-theme/snippets/monetta-dock.liquid`; extracto: "href=\"{{ routes.all_products_collection_url }}\"".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/41`: Plantilla con layout Atelier; asignación y reglas comerciales pendientes por tienda.
  Fuente: `storefront-theme/templates/page.contact.json`; extracto: "\"button_link\": \"shopify://pages/mayoreo\"".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/42`: como-vender es página; vende-con-monetta es handle del metaobject. No implica atribución o comisiones.
  Fuente: `storefront-theme/templates/page.mayoreo.json`; extracto: "\"button_link\": \"shopify://pages/como-vender\"".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/43`: Home abre PartnerHubScreen, sin abrir WholesaleScreen.
  Fuente: `lib/features/home/home_screen.dart`; extracto: "builder: (_) => PartnerHubScreen(".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/44`: Clase existente; sin invocación activa encontrada desde home/cuenta. Revisar unificación con PartnerHubScreen.
  Fuente: `lib/features/wholesale/wholesale_screen.dart`; extracto: "class WholesaleScreen extends StatelessWidget".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/45`: Evitar salto a producción desde tema staging; contact usa Atelier.
  Fuente: `lib/features/contact/contact_screen.dart`; extracto: "Uri.parse('https://monetta.mx/pages/contact')".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/46`: Cuenta abre ContactScreen; menú home abre WhatsApp. Grupos residen en PartnerHubScreen.
  Fuente: `lib/features/contact/contact_screen.dart`; extracto: "Future<void> openContact(".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/47`: Resolver con routes.account_url. Configuración de cuentas, capacidades y Rewards web no certificados.
  Fuente: `storefront-theme/sections/monetta-header.liquid`; extracto: "href=\"{{ routes.account_url }}\"".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/53`: Autoridad accounts_orders. Sin conversión a puntos/niveles ni premios por compartir.
  Fuente: `lib/features/rewards/rewards_section.dart`; extracto: "class RewardsSection extends StatefulWidget".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/6`: El enlace ordena por fecha; el carrusel usa el orden de la colección. Colección de campaña curada sin confirmar.
  Fuente: `storefront-theme/templates/index.json`; extracto: "\"button_1_link\": \"/collections/all?sort_by=created-descending\"".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/61`: shop.policies dinámico; falta inventario de políticas publicadas por tienda.
  Fuente: `storefront-theme/sections/monetta-footer.liquid`; extracto: "href=\"{{ policy.url }}\"".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/7`: Flutter usa monetta-todays-picks; Selección en templates/index.json usa all. No son equivalentes.
  Fuente: `lib/data/shopify/featured_catalog_repository.dart`; extracto: "'handle': 'monetta-todays-picks'".
- **warning · KNOWN_ROUTE_INCONSISTENCY** — `/routes/9`: guess es Bolsas; guess-1 es la marca Guess. No fusionar.
  Fuente: `lib/domain/home_content.dart`; extracto: "title: 'Bolsas',\n        handle: 'guess',\n        category: 'bolsa',".
- **error · LISTING_COVER_MISSING** — `/content/cover/brand.coach`: The listing needs campaign art/copy distinct from its brand logo or category tile.
- **error · PRODUCT_SELECTION_ORDER_MISMATCH** — `/content/productSelections/newest/source/ordering`: Required created_desc; available collection_default.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/contact/ctaLabel`: Missing required field ctaLabel.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/home/media/sources/compact/focal`: Missing required field focal.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/seasonal/ctaLabel`: Missing required field ctaLabel.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/seasonal/destination`: Missing required field destination.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/seasonal/headline`: Missing required field headline.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/share/ctaLabel`: Missing required field ctaLabel.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/share/headline`: Missing required field headline.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/welcome/destination`: Missing required field destination.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/welcome/media/sources/compact/focal`: Missing required field focal.
- **error · REQUIRED_FIELD_MISSING** — `/content/campaigns/wholesale/media/sources/compact/focal`: Missing required field focal.
- **error · REQUIRED_FIELD_MISSING** — `/content/categories/8/alt`: Missing required field alt.
- **error · REQUIRED_FIELD_MISSING** — `/content/categories/8/imageAssetId`: Missing required field imageAssetId.
- **error · REQUIRED_FIELD_MISSING** — `/content/footer/policyRouteIds`: Missing required field policyRouteIds.
- **error · REQUIRED_FIELD_MISSING** — `/content/home`: Missing required field home.
- **error · REQUIRED_FIELD_MISSING** — `/content/preferences/purchaseTypeOptions`: Missing required field purchaseTypeOptions.
- **error · REQUIRED_FIELD_MISSING** — `/content/productSelections/popular/source`: Missing required field source.
- **error · REQUIRED_FIELD_MISSING** — `/content/signup/body`: Missing required field body.
- **error · REQUIRED_FIELD_MISSING** — `/content/signup/consentText`: Missing required field consentText.
- **error · REQUIRED_FIELD_MISSING** — `/content/signup/ctaLabel`: Missing required field ctaLabel.
- **error · REQUIRED_FIELD_MISSING** — `/content/signup/headline`: Missing required field headline.
- **error · REQUIRED_FIELD_MISSING** — `/content/signup/privacyRouteId`: Missing required field privacyRouteId.
- **error · REQUIRED_FIELD_MISSING** — `/content/signup/submissionAdapter`: Missing required field submissionAdapter.
- **error · REQUIRED_FIELD_MISSING** — `/content/wholesale/pricingMode`: Missing required field pricingMode.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/contact/media/sources/compact`: Missing required field compact.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/contact/media/sources/expanded`: Missing required field expanded.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/contact/media/sources/medium`: Missing required field medium.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/home/media/sources/expanded`: Missing required field expanded.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/home/media/sources/medium`: Missing required field medium.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/seasonal/media/sources/compact`: Missing required field compact.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/seasonal/media/sources/expanded`: Missing required field expanded.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/seasonal/media/sources/medium`: Missing required field medium.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/share/media/sources/compact`: Missing required field compact.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/share/media/sources/expanded`: Missing required field expanded.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/share/media/sources/medium`: Missing required field medium.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/welcome/media/sources/expanded`: Missing required field expanded.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/welcome/media/sources/medium`: Missing required field medium.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/wholesale/media/sources/expanded`: Missing required field expanded.
- **error · RESPONSIVE_VISUAL_MISSING** — `/content/campaigns/wholesale/media/sources/medium`: Missing required field medium.
- **error · SCREEN_CONTENT_MISSING** — `/content/home/moduleOrder`: PDF 3: required content home.moduleOrder is unavailable.
- **warning · TEMPLATE_LAYOUT_PENDING** — `storefront-theme/templates/list-collections.json`: Current layout theme (default); required monetta.
- **warning · TEMPLATE_LAYOUT_PENDING** — `storefront-theme/templates/page.como-vender.json`: Current layout theme (default); required monetta.
- **warning · TEMPLATE_LAYOUT_PENDING** — `storefront-theme/templates/page.contact.json`: Current layout theme (default); required monetta.
- **warning · TEMPLATE_LAYOUT_PENDING** — `storefront-theme/templates/page.json`: Current layout theme (default); required monetta.
- **warning · TEMPLATE_LAYOUT_PENDING** — `storefront-theme/templates/page.mayoreo.json`: Current layout theme (default); required monetta.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/0/imageAssetId`: assets/images/brands/coach.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/1/imageAssetId`: assets/images/brands/michael_kors.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/10/imageAssetId`: assets/images/brands/laneige.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/11/imageAssetId`: assets/images/brands/rhode.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/2/imageAssetId`: assets/images/brands/anne_klein.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/3/imageAssetId`: assets/images/brands/guess.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/4/imageAssetId`: assets/images/brands/steve_madden.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/5/imageAssetId`: assets/images/brands/tommy_hilfiger.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/6/imageAssetId`: assets/images/brands/olaplex.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/7/imageAssetId`: assets/images/brands/dior.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/8/imageAssetId`: assets/images/brands/the_ordinary.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/brands/9/imageAssetId`: assets/images/brands/summer_fridays.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/campaigns/home/media/sources/compact/assetId`: assets/images/home_banner.jpg is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/campaigns/welcome/media/sources/compact/assetId`: assets/images/campaign_terracotta.jpg is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/campaigns/wholesale/media/sources/compact/assetId`: assets/images/campaign_olive.jpg is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/categories/0/imageAssetId`: assets/images/home_collection_bags.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/categories/1/imageAssetId`: assets/images/home_collection_wallets.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/categories/2/imageAssetId`: assets/images/home_collection_watches.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/categories/3/imageAssetId`: assets/images/home_bag_tote.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/categories/4/imageAssetId`: assets/images/home_bag_crossbody.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/categories/5/imageAssetId`: assets/images/home_bag_shoulder.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/categories/6/imageAssetId`: assets/images/home_bag_tote.webp is a legacy fallback; the PDF composition/crop is not approved.
- **warning · VISUAL_APPROVAL_PENDING** — `/content/categories/7/imageAssetId`: assets/images/home_bag_shoulder.webp is a legacy fallback; the PDF composition/crop is not approved.
