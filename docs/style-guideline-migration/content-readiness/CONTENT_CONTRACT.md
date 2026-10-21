# Contrato compartido de contenido Monetta

Versión del payload **1.0.0**, 20 de octubre de 2026; revisión de validación y auditor **1.0.1**. Estado: contrato propuesto para integración; no desplegado. Especificación ejecutable: [content-contract.v1.schema.json](content-contract.v1.schema.json). Mapeo de campos y responsables: [field-map.json](field-map.json). Evidencia fechada: [source-manifest.json](evidence/source-manifest.json). La [entrega inicial](reports/archive/initial-1.0.0/docs/CONTENT_CONTRACT.md) permanece archivada sin cambios.

Este contrato describe un modelo de lectura normalizado para Flutter y Shopify. No modifica Shopify, precios, disponibilidad, checkout o Rewards. [content-baseline.json](content-baseline.json) es una instantánea deliberadamente incompleta para medir preparación. No debe publicarse como contenido final.

## Forma, versión y referencias

La parte `content` sigue el esquema. El inventario `assets` del documento acompañante sigue `$defs.asset`; `route-map.json` resuelve destinos y enlaces de soporte. Son tres entradas relacionadas: **contenido + recursos + rutas**. Los clientes no deben interpretar `assetId` como URL o construir handles a partir del título visible.

| Grupo | Campos del contrato |
| --- | --- |
| Identidad | `contractVersion: 1.0.0`, `locale: es-MX`. Identifica la versión del modelo, no la tienda o un idioma remoto comprobado. |
| Composición | `home.moduleOrder[]`: `id`, `kind`, `contentRef`. Tipos: `campaign`, `categories`, `brands`, `product_selection`, `wholesale`, `services`, `signup`, `footer`. `contentRef` es una ruta dentro del documento, p. ej. `campaigns.home`. |
| Campañas | Mapa `campaigns.<id>`: `id`, `headline`, `ctaLabel`, `destination`, `media`; opcionales `eyebrow`, `body`, `active`. La campaña de portada, la secundaria, mayoreo, compartir y contacto son objetos independientes. |
| Recursos | `assets[]`: `id`, `path`, SHA-256, dimensiones, `approval`, `availableAtCapture`; opcionales `url`, `themeAssetName`, `shopifyImageGid`. `path` es procedencia/fallback nativo; el adapter web debe resolver una imagen Shopify, URL HTTPS o asset del tema. Un archivo local no demuestra que esté subido a Shopify. |
| Media adaptable | `media.alt`, `media.decorative`, `media.sources.compact|medium|expanded`, cada fuente con `assetId` y `focal: {x,y}`. Coordenadas normalizadas inclusivas entre 0 y 1, desde la esquina superior izquierda de **esa imagen**. |
| Categorías y marcas | `id`, `title`, `imageAssetId`, `alt`, `destination.routeId`. Opcionales `description`, `coverCampaignId`, `brandKey`, `nativeDestination`. `brandKey` identifica la taxonomía; `title` es presentación. El logo es distinto de la portada de colección. |
| Selecciones | `productSelections.<id>`: `id`, `title`, `source.kind`, `source.provider`, `source.ordering`. `collection` exige `routeId` de colección existente en el inventario; `curated` exige exactamente una alternativa: esa ruta o `handles` explícitos no vacíos, únicos y de texto. `newest` y `recommendations` conservan fuentes por provider sin ruta obligatoria. La resolución efectiva ocurre en la tienda/contexto activos. |
| Mayoreo | `headline`, `body`, `campaignId`, `steps[] {number,title,body}`, `terms[] {value,label}`, `pricingMode`, `supportLinkId`, `catalogIds`, `rewardsPolicyRef`. `pricingMode`: `manual_quote` o `verified_automatic`, sólo después de resolver la contradicción actual. |
| Servicios | `services[] {id,title,body,icon,supportLinkId?}`. Sin umbrales, tiempos o métodos nuevos derivados de ilustraciones. |
| Contacto | `headline`, `campaignId`, `channels[] {id,label,url,kind}`, `groupLinkIds[]`. `hours`, `email`, `voice` son opcionales y actualmente desconocidos. Los grupos se resuelven mediante `route-map.supportLinks`. |
| Redes | `socialLinks[] {id,label,url,kind}`. Conservar IDs de perfil y queries que identifican el recurso. Los parámetros de tracking no justifican cambiar la identidad. |
| Catálogos | `id`, `category`, `categoryLabel`, `mode`, `destination`, `description`, `sortOrder`, `active`, `shareable`; opcionales `updatedLabel`, `imageAssetId`. Modos canónicos: `wholesale`, `suggested_prices`, `no_prices`. `wholesale` no es el destino predeterminado para compartir a clientas. |
| Signup | `enabled`, `headline`, `body`, `ctaLabel`, `submissionAdapter`, `consentText`, `privacyRouteId`; opcionales `offerClaim`, `offerPolicyRef`, que requieren aprobación comercial y una política comprobada. No hay un adapter compartido implementado/verificado. |
| Pie | `brandDescription`, `columns[] {id,heading,menuHandle}`, `policyRouteIds`, `socialLinkIds`, `supportLinkId`, `copyrightYear: runtime_year`. Los menús y políticas se resuelven en la tienda activa. |
| Preferencias | `brandOptionIds`, `categoryOptionIds`, `purchaseTypeOptions`, `skipAllowed`. Son opciones candidatas, **no preferencias elegidas ni prueba de stock**. Los consumidores filtran según catálogo real. Los valores guardados del cliente permanecen en su mecanismo de persistencia. |
| Rewards | `model: mxn_balance_v1`, `currency: MXN`, `authority: accounts_orders`, `policyRef: docs/redesign/REWARDS_CONTRACT_V1.md`, `capabilitySource`. Sólo referencias al contrato existente; ningún saldo o regla se administra como contenido editorial. |

El texto requerido se normaliza con `trim` y los tipos no se coaccionan. Los IDs son estables y no se derivan de la posición en un arreglo. `destination.routeId` resuelve un registro tipado del inventario; un destino nativo por filtro no se convierte en un handle Shopify. En los aliases, `equivalent:null` significa equivalencia desconocida y `rewriteAllowed:false` impide una reescritura automática. Los hosts, sesiones, GIDs y URLs de pedidos no se comparten por coincidencia de marca o correo.

Una ampliación opcional compatible aumenta MINOR. Corregir documentación aumenta PATCH. Eliminar/renombrar campos o cambiar su significado aumenta MAJOR. El auditor de esta entrega admite exactamente `1.0.0`: debe actualizarse deliberadamente junto con el esquema al adoptar otra versión. Los clientes deberán tolerar campos opcionales desconocidos de su versión compatible; el auditor rechaza campos no declarados para descubrir errores antes de publicar. No hay consumidor nuevo implementado todavía.

La revisión de validación `1.0.1` corrige tres huecos del contrato propuesto sin cambiar el `contractVersion` del payload ni la baseline original. El esquema inicial está archivado; el esquema actual incorpora `anyOf` y `oneOf`, ambos ejecutados y probados por el motor nativo. No se declararon condiciones que ese motor ignore.

## Identidad de catálogos y autorización de compartir

`catalog.category` debe coincidir exactamente con `route.catalogCategory`, y `catalog.mode` con `route.catalogMode`, para el destino `catalogo_externo` referenciado. No se presume que dos categorías o modalidades sean aliases. Si los valores completos difieren, se emiten `CATALOG_CATEGORY_MISMATCH` o `CATALOG_MODE_MISMATCH`.

La restricción de compartir se aplica a la **modalidad del destino registrado**, además de la etiqueta del catálogo. Una fila `suggested_prices` con `shareable:true` que enlaza a un destino `wholesale` produce `WHOLESALE_DESTINATION_PUBLIC_SHARE`. Cambiar sólo el rótulo no habilita compartir precios de mayoreo.

Si falta categoría/modalidad, o la modalidad no es canónica, el auditor emite `CATALOG_IDENTITY_UNCONFIRMED`; si además se pretende compartir un destino de modalidad desconocida, emite `CATALOG_SHAREABILITY_UNCONFIRMED`. Es incertidumbre que impide certificar preparación, no prueba de equivalencia o de un enlace roto. Los nueve pares originales continúan válidos para estas comprobaciones; su contenido remoto sigue sin revisar.

## Resolución de selecciones

| `source.kind` | Fuente exigida | Validación |
| --- | --- | --- |
| `collection` | `routeId` no vacío. | Debe existir en `route-map`, tener destino existente y tipo `coleccion`. Una propuesta sin destino, una ruta desconocida, una página o un producto no resuelven esta fuente. |
| `curated` | Exactamente un `routeId` de colección **o** una lista `handles` no vacía. | La ruta sigue las mismas reglas. Los handles deben ser textos no vacíos y únicos. Se rechazan ambas alternativas simultáneas por ambigüedad. |
| `newest` | `provider` y `ordering`, sin ruta obligatoria. | Mantiene la fuente de catálogo por provider; si hay ruta, debe resolver una colección. Sigue vigente la política de orden que corresponda a la selección. |
| `recommendations` | `provider` y `ordering`, sin ruta obligatoria. | Conserva el contexto y las recomendaciones reales del proveedor. No se inventa una colección para satisfacer el esquema. |

El esquema V1 comprueba las alternativas con `anyOf`/`oneOf`; el auditor resuelve las referencias tipadas. `SELECTION_ROUTE_REQUIRED`, `SELECTION_DESTINATION_UNRESOLVED` y `SELECTION_DESTINATION_TYPE_MISMATCH` distinguen los fallos de colección; `SELECTION_SOURCE_UNRESOLVED`, `SELECTION_SOURCE_AMBIGUOUS` y `SELECTION_HANDLES_INVALID` describen una fuente curada inválida.

Una referencia a una colección registrada con publicación pendiente mantiene los avisos de entidad/destino de la captura. La validación offline no prueba el provider instalado, la publicación en Shopify, la existencia actual de cada handle ni su stock. Una lista de handles válida describe cómo resolver la selección y no certifica productos comerciales actuales.

## Familia y estructura de módulos home

Una referencia existente no basta: `kind` debe señalar la familia correcta y el contenido referenciado debe cumplir su estructura V1, incluidos los elementos de listas.

| `kind` | `contentRef` permitido | Estructura comprobada |
| --- | --- | --- |
| `campaign` | `campaigns.<id>`, una entrada completa. | `$defs.campaign`, con destino y media por tamaño. |
| `product_selection` | `productSelections.<id>`, una entrada completa. | `$defs.selection`, incluida su fuente resoluble. |
| `categories` | Exactamente `categories`. | Lista de tiles de categorías, no una fila o la lista de marcas. |
| `brands` | Exactamente `brands`. | Lista de tiles de marcas. |
| `wholesale` | Exactamente `wholesale`. | `$defs.wholesale`. |
| `services` | Exactamente `services`. | Lista de `$defs.service`. |
| `signup` | Exactamente `signup`. | `$defs.signup`. |
| `footer` | Exactamente `footer`. | `$defs.footer`. |

`HOME_MODULE_FAMILY_MISMATCH` rechaza referencias como `product_selection → rewards`, aunque existan y sean objetos completos. `HOME_MODULE_CONTENT_INVALID` enlaza los errores de estructura del contenido correcto; `HOME_MODULE_CONTENT_MISSING` conserva los casos ausentes/vacíos. Un esquema reducido sin la definición necesaria produce `HOME_MODULE_SCHEMA_MISSING` en lugar de certificar la estructura silenciosamente.

Estas reglas no modifican Rewards ni convierten su estructura en una selección de productos. Las [reproducciones antes/después](reports/correction-1.0.1/reproductions.md) y las [pruebas](reports/correction-1.0.1/tests.tap) documentan la corrección.

## Tamaños y medios

`compact` corresponde inicialmente a 320–767, `medium` a 768–1023 y `expanded` a 1024+; son bandas del contrato de contenido propuestas por el plan, no una modificación de breakpoints Flutter. Los clientes adaptan el tamaño a su área disponible. Web usa `<picture>`/fuentes adecuadas; Flutter resuelve el recurso y solicita dimensiones acotadas. No hay que descargar imágenes desktop para un teléfono.

Cada fuente tiene un focal propio. En Shopify, la integración deberá convertir el punto de presentación de **la imagen seleccionada** o guardar coordenadas explícitas. Actualmente `monetta-hero` tiene imágenes mobile/desktop y aplica el focal de `main_image`, que puede no corresponder a la fuente `wide` seleccionada por `<picture>`. Falta una fuente tablet independiente y un equivalente de focal en el modelo nativo.

El centro `(0.5,0.5)` es un fallback de renderizado posible, no un focal aprobado que deba rellenar la auditoría. La instantánea omite los focales desconocidos. Una imagen empaquetada sirve como fallback, pero no acredita el arte de campaña del PDF ni su recorte horizontal. No usar capturas del PDF como imágenes de producción. Imágenes decorativas usan `alt: ""`; las demás requieren descripción útil.

## Campos actuales y ampliaciones

| Fuente actual | Qué conservar | Ampliación requerida y editor |
| --- | --- | --- |
| `HomeContent` + shop metafields `app.home_sections`, `home_collections`, `home_bag_types`, `social_links`, `about_image_url` | Nombres/aliases existentes, colecciones, estilos, redes y fallbacks. | Ingeniería añade adapters y módulos; comercial administra contenido/orden. `HomeSectionId` sólo reconoce ocho familias actuales y no puede representar la composición completa del PDF. |
| `HomeCollectionCard` | `title`, `handle`, `fallbackAsset`, `imageUrl`, `category`, `silhouette`. | Añadir ID, destino tipado, alt y portada; diseño prepara arte, comercial elige entidades, ingeniería empaqueta fallbacks. |
| `HomeBrandCard` / `_brands` | Etiqueta, clave de marca, handle y logo; actualmente sólo se sobreescribe imagen de seeds existentes. | Lista editable de marcas y portada por separado. Confirmar Tory Burch, Kate Spade, Marc Jacobs y CH antes de incorporar logos o handles. |
| `CampaignMedia` y `monetta-hero` | Video/poster nativo y ajustes existentes del tema. | Campañas compartidas con copy, CTA, recursos y focal por tamaño. `Remote Config` es comentario futuro en el código, no implementación actual. |
| `FeaturedCatalogRepository` y secciones de productos | `monetta-todays-picks`, catálogo/variantes reales y recomendaciones. | Elegir la misma selección por tienda/canal. El tema configura `all` como Selección. Novedades debe ordenar la lista por fecha; un enlace con `sort_by` no cambia el orden del carrusel. No hay fuente de popularidad compartida confirmada. |
| `app_about/monetta` | `eyebrow`, `headline`, `body`, `timeline_json`, `trust_facts_json`. | Referencia a campaña/imagen opcional; el hero actual se empaqueta con la app. Comercial edita Metaobjects si las definiciones/acceso existen. |
| `app_partner_program/vende-con-monetta` | `eyebrow`, `headline`, `body`, `steps_json`, `terms_json`, `faqs_json`. Cada campo JSON guarda su arreglo. | Añadir campaña, soporte y política consensuada. `WholesaleScreen` usa constantes y no recibe este objeto; reconciliarlo con `PartnerHubScreen`. |
| `reseller_catalog` | Categoría, etiqueta, modalidad, URL, descripción, orden, actualización y activo. Hosts exactos permitidos de `isTrustedPartnerUri`. | Compartir la misma entidad desde Liquid y Flutter; ampliar imagen y metadatos de revisión sólo cuando se necesiten. El tema heredado guarda las URLs en ajustes de bloques. Las nueve coinciden hoy en la captura. |
| Contacto y redes | Número `528261066868`, página `contact`, tres redes, dos grupos WhatsApp y grupo Facebook. | Centralizar configuración. Comercial podrá editarla; actualmente algunos canales requieren cambio de código. `openContact(context)` desde cuenta no recibe las redes runtime. |
| Servicios / signup / footer | Servicios existentes, menús `main-menu`/`footer`, `shop.policies`, año dinámico. | Servicios compartidos, consentimiento y adapter real de signup. Comercial/legal define políticas y ofertas; ingeniería implementa envío y estados. No hay oferta signup aprobada en la evidencia. |
| `$app:storefront_config/monetta` | `announcement`, `show_hero`, `show_newest`, `show_todays_picks`, `show_external_picks`, versión administrada por backend. | Mantener su autoridad/propietario app. No migrar ese tipo reservado a un metaobject editorial merchant-owned ni reactivar el agregador externo retirado. |

Los campos actuales son evidencia de soporte en código, **no certificación de que existan y estén publicados en la tienda de staging o producción**. `HomeContent` consulta las primeras 50 colecciones y editorial los primeros 50 catálogos. El adapter futuro debe paginar o consultar referencias/handles exactos antes de concluir que un recurso no existe.

## Almacenamiento propuesto y quién edita

Propuesta para integrar después, sin crear nada en esta entrega:

- Mantener intactos los metafields/metaobjects existentes y sus handles. Añadir un manifiesto editorial versionado, por ejemplo shop metafield JSON `app.content_v1`, con una revisión de contenido y estado de publicación separados de `contractVersion`. Ese nombre es **propuesto**, no una definición existente.
- Dar al manifiesto referencias a recursos de imagen y destinos tipados; los adapters lo normalizan al esquema y registran procedencia. Los GIDs y assets del tema se resuelven según tienda/canal y nunca se copian entre tiendas por suposición.
- Si el equipo prefiere entradas editoriales reutilizables, crear definiciones merchant-owned para campañas, tiles, servicios, contacto y signup, y referenciarlas desde ese manifiesto. Son una alternativa de implementación, no requisitos de crear simultáneamente dos fuentes de verdad.
- Un editor de contenido comercial podrá editar copy, orden, campañas, selección y destinos existentes. Diseño entrega imágenes/logos originales y focales. Comercial/legal aprueba términos, envío, devolución, oferta signup y canales. Ingeniería administra schemas, adapters, listas de confianza y fallbacks empaquetados. Las capacidades, saldos, flags de Rewards y elegibilidad proceden de los servicios, no del editor.
- Secciones Shopify deberán consumir esa fuente o bindings derivados explícitos. Los ajustes locales del editor pueden actuar como override de presentación documentado, sin generar una segunda política comercial ni ocultar su procedencia. No se ha probado el editor de Shopify en esta tarea.

## Compatibilidad y fallbacks

La integración deberá mantener lectura dual: contenido V1 válido y disponible → fuente legacy compatible → último contenido válido/bundled. Si una respuesta es inválida, no promover parcialmente datos comerciales o destinos sin respaldo. El error de una campaña no debe vaciar toda la home.

| Caso | Comportamiento actual | Comportamiento a preservar o precisar al integrar |
| --- | --- | --- |
| Sin red/configuración | Controllers conservan contenido empaquetado o en memoria. Home pasa el contenido anterior como fallback. Editorial conserva estado ante error de fetch y usa fallback estático al interpretar campos parciales. | Mantener compra/navegación accesibles y procedencia del fallback. Estos controllers no acreditan caché editorial durable entre reinicios. |
| Sección/JSON ausente o inválido | `_sectionOrder` descarta IDs desconocidos; listas inválidas/vacías suelen volver al fallback. | Mantener aliases legacy. IDs de módulo nuevos requieren adapter antes de activarlos. |
| Colección configurada no encontrada | `_cards` omite desconocidas/vacías y vuelve al fallback si el resultado queda vacío. `_brands` conserva seeds incluso con colección vacía. | Diferenciar consulta incompleta, ausencia comprobada y colección vacía. No prometer disponibilidad por un tile o un logo. |
| Lista de catálogos | Parser filtra modo/URL/host/campos/activo; si no queda ninguno, restaura todos los fallbacks. Una lista parcial válida reemplaza el conjunto, no lo completa por categoría. | No dejar que `active:false` de todos los catálogos haga reaparecer los desactivados. Añadir estado de documento completo y desactivación explícita antes de cambiar esta semántica; lectores viejos continúan su comportamiento hasta migrar. |
| Ausente frente a vacío | Legacy suele tratar vacío como falta de datos. | En el futuro manifiesto, campo ausente = heredar; lista vacía confirmada en documento completo = ocultar deliberadamente; fallo de red/parseo = conservar último válido. Versionar/publicar sin cambiar de golpe el significado para lectores viejos. |
| Media/crop desconocido | Imágenes empaquetadas y centro de imagen. | Mantener fallback sin presentar un focal inferido como aprobado. Si falta la portada, encabezado de texto; no ampliar un logo para simular campaña. |
| Destino sin evidencia | Existen callbacks y algunos enlaces heredados inconsistentes. | Ocultar la acción o mostrar indisponibilidad real. No asignar `#`, crear un handle adivinado o sustituir un catálogo por `all` sin explicitarlo. |
| Signup sin proveedor/política | No hay integración compartida demostrada. | Ocultar signup (`enabled:false` propuesto en baseline); no simular éxito ni prometer envío gratis. |
| Canales desconocidos | Contacto omite correo/voz no verificados. | Mantener omisión y no generar `mailto`/`tel` con datos ilustrativos. |
| Catálogo sin acceso | No consultado en esta tarea. | Restricción de acceso no significa enlace roto. Incluso HTTP 200 necesita revisar identidad, categoría, modalidad y vigencia del documento. |

## Reglas comerciales que permanecen

Rewards conserva el contrato y defaults del repositorio: saldo en centavos MXN, menudeo 3%, máximo de canje 20%, vigencia 12 meses, mayoreo no genera, uso en mayoreo sin definir/bloqueado, e incentivos de primera compra/reseña/referido deshabilitados por defecto. El servicio determina las banderas desplegadas; esta tarea no las consultó ni las cambia. Los ejemplos de saldo del contrato de Rewards tampoco son saldos de una persona.

La preferencia de compra mayoreo no habilita precios ni cambia Rewards. Compartir/copiar un catálogo no atribuye vistas, compras o comisiones. No portar los puntos, niveles o incentivos del PDF.

Los importes de anticipo y plazos conservados en baseline provienen de código existente y quedan identificados como referencias con decisiones pendientes. No hay precios, disponibilidad, cantidades de stock, descuentos, números de pedido o personas del PDF en el modelo editorial. La disponibilidad de productos, variantes, reseñas y pedidos se resuelve desde sus proveedores reales y se conserva su estado/procedencia.

## Validación

El auditor valida el contrato, referencias, evidencia y diferencias contra los requisitos de las 19 páginas. También revisa layouts desde las plantillas congeladas. No compila Flutter/Liquid, no deduce toda capacidad mediante análisis estático, no verifica la verdad de una política comercial y no certifica Shopify desplegado.

Para actualizar la preparación después de implementar, revisar los mapeos/decisiones/capacidades con evidencia nueva en un conjunto de datos separado, conservando esta captura. `--live` sólo detecta deriva local y no transforma código cambiado en contenido aprobado. Instrucciones en [README del auditor](../../../tools/style-guideline-content/README.md) y [REPORT.md](REPORT.md).
