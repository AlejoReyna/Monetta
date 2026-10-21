# Preparación de contenido y rutas para la migración visual — auditor 1.0.1

Entrega inicial del **20 de octubre de 2026**, seguida de la **corrección 1.0.1** de la revisión independiente. El auditor funciona offline, cubre las **19 páginas del PDF** y deja un contrato V1 para integrar en Flutter y Shopify. Se escribieron únicamente `tools/style-guideline-content/` y `docs/style-guideline-migration/content-readiness/`. No se modificaron el STATUS compartido, componentes, estilos, navegación, pruebas existentes, entidades ni configuración de Shopify. No se cambió de rama ni se creó un worktree.

Resultado de preparación: **47 errores de contenido/contrato y 196 pendientes o avisos**, agrupados en [informe legible](reports/offline/audit.md) y [JSON](reports/offline/audit.json). Son diferencias contra el objetivo completo; no son fallos del ejecutable, 243 tickets independientes ni defectos demostrados de producción. Ninguna pantalla está certificada completa entre ambos canales.

## Corrección 1.0.1: tres huecos cerrados

La versión 1.0.0 y sus informes se [archivaron](reports/archive/initial-1.0.0/archive-manifest.json) antes de regenerar resultados. Se conservaron 24 archivos, incluidos código, esquema, documentación, informes y TAP inicial. El [informe inicial](reports/archive/initial-1.0.0/docs/REPORT.md) conserva sus bytes originales. La baseline, el manifiesto y los snapshots originales permanecen congelados; también se conservaron rutas, requisitos y field-map.

Se reprodujeron los cuatro casos sobre copias **en memoria** de la baseline antes de editar. Ninguno produjo hallazgos nuevos con 1.0.0. [Reproducciones previas](reports/correction-1.0.1/reproductions-before.json). Las regresiones se añadieron primero: **34 fallaron y 12 controles pasaron** contra la implementación anterior. [TAP previo](reports/correction-1.0.1/regressions-before.tap). Tras corregir, pasan **81/81 pruebas**: las 35 originales sin modificar y 46 nuevas.

| Hallazgo | Corrección concreta | Evidencia de la reproducción corregida |
| --- | --- | --- |
| Identidad de catálogo/destino | Se comparan `catalog.category`/`route.catalogCategory` y `catalog.mode`/`route.catalogMode`. La autorización de compartir usa la modalidad del destino, aunque la etiqueta diga precios sugeridos. Metadata incompleta se conserva como incertidumbre mediante avisos específicos. | `bags-suggested → catalog.bags-wholesale`: `CATALOG_MODE_MISMATCH` y `WHOLESALE_DESTINATION_PUBLIC_SHARE`. `bags-wholesale → catalog.perfume-wholesale`: `CATALOG_CATEGORY_MISMATCH`. Los nueve pares originales pasan estas validaciones. |
| Selección sin fuente resoluble | `collection` exige ruta existente de tipo colección. `curated` exige exactamente una ruta de colección o handles no vacíos, únicos y de texto. Se mantienen recomendaciones y newest por provider sin ruta artificial obligatoria. El esquema declara y el motor ejecuta `anyOf`/`oneOf`. | `todays-picks.kind=collection` sin `routeId`: `SCHEMA_ANY_OF_MISMATCH` en la fuente y `SELECTION_ROUTE_REQUIRED` en `source/routeId`. También se rechazan rutas desconocidas, sin destino o de página/producto. |
| `kind/contentRef` incompatible | Cada módulo se valida contra su familia canónica y contra la estructura V1 referenciada, incluidas listas. No basta la existencia de un objeto. Una definición de esquema ausente se informa explícitamente. | `product_selection → rewards`: `HOME_MODULE_FAMILY_MISMATCH` y `SCHEMA_ANY_OF_MISMATCH`. Hay controles positivos y negativos para los ocho tipos de módulo, referencias ausentes y estructuras incompletas. |

Los [resultados antes/después](reports/correction-1.0.1/reproductions.md) incluyen paths y mensajes concretos; el [JSON](reports/correction-1.0.1/reproductions-after.json) registra los deltas completos:

| Mutación | 1.0.0: errores/avisos | Hallazgos nuevos en 1.0.0 | 1.0.1: errores/avisos |
| --- | --- | --- | --- |
| suggested → wholesale | 47/196 | 0 | 49/196 |
| bags → perfume | 47/196 | 0 | 48/196 |
| collection sin ruta | 47/195 | 0 | 49/195 |
| módulo de selección → rewards | 45/195 | 0 | 47/195 |

Los totales de la baseline **sin mutaciones** siguen siendo 47/196: sus nueve pares son coherentes, las fuentes presentes son válidas para estas reglas y no hay módulos home que reclasificar. Los campos ausentes ya estaban reportados. No se retocó contenido, inventario, severidades o validaciones para conservar esos números. Los huecos se prueban mediante sus hallazgos nuevos, no mediante el total global de una baseline que ya estaba incompleta.

Archivos de implementación de esta corrección:

- `tools/style-guideline-content/lib/auditor.mjs`: comprobaciones cruzadas y de resolución/estructura, versión `1.0.1` y versión visible en el informe legible.
- `tools/style-guideline-content/lib/schema.mjs` y `content-contract.v1.schema.json`: disyunciones ejecutables, alternativas de selección y familias de referencias. El payload mantiene `contractVersion:1.0.0`; el esquema identifica la revisión de validación en `$comment`.
- `tools/style-guideline-content/test/corrections.test.mjs` y `test/fixtures/content-families.json`: 46 pruebas nuevas con esquema V1 real y fixtures reducidos. El archivo de las 35 pruebas originales conserva su SHA-256.
- `tools/style-guideline-content/verify-corrections.mjs` y `package.json`: ejecución reproducible de pruebas, comparación con el código archivado, CLI normal/estricto/live, huellas y preservación. No se restauran archivos con Git.
- Este informe, `CONTENT_CONTRACT.md`, el README del auditor y las evidencias propias bajo `reports/correction-1.0.1/`.

El verificador coteja los **109 archivos de datos congelados y el archivo de las pruebas originales** antes y después, además de las **24 copias archivadas**. Las [huellas y exit codes](reports/correction-1.0.1/verification.json) distinguen el código/esquema actual de la entrega inicial. JSON y Markdown offline son idénticos byte por byte en dos ejecuciones. El resultado normal es `0`; el modo estricto devuelve `1` por preparación pendiente, con sus informes conservados en [strict/](reports/correction-1.0.1/strict/audit.json).

La comparación local posterior detectó deriva en `storefront-theme/layout/monetta.liquid`, fuera de nuestro alcance de escritura. Se registra con las huellas anterior/actual y su hora en [live/audit.json](reports/correction-1.0.1/live/audit.json); no actualiza snapshots, baseline, capabilities ni el estado remoto. La observación inicial de cero cambios se mantiene abajo como evidencia histórica, no como el estado actual.

Limitaciones pendientes: estas reglas comprueban identidad y referencias contra el inventario congelado. No certifican contenido/acceso remoto de catálogos, publicación de colecciones, ejecución de providers, resolución actual de handles o stock. Las decisiones comerciales y los faltantes de la migración siguen pendientes. Rewards conserva MXN y sus reglas implementadas.

## Entrega lista para consumir

| Artefacto | Uso |
| --- | --- |
| [route-map.json](route-map.json) | 78 destinos con tipo, enlace/binding, fuente exacta, estado, aliases y discrepancias. Además, siete enlaces de contacto/redes/grupos. |
| [CONTENT_CONTRACT.md](CONTENT_CONTRACT.md) | Contrato 1.0.0, autoridades, edición comercial, compatibilidad, almacenamiento propuesto y fallbacks. |
| [content-contract.v1.schema.json](content-contract.v1.schema.json) | Esquema del contenido normalizado y definición del inventario de recursos. |
| [field-map.json](field-map.json) | 22 mapeos de campos existentes, ampliaciones, responsables y páginas afectadas. |
| [content-baseline.json](content-baseline.json) | Datos locales respaldados, 38 imágenes legacy identificadas, nueve catálogos, nueve decisiones y 17 capacidades. Las omisiones son deliberadas; no es un payload listo para publicación. |
| [screen-requirements.json](screen-requirements.json) | Requisitos por página 1–19, tipos de módulos, taxonomía, selecciones y nueve plantillas revisadas. |
| [Auditor y pruebas](../../../tools/style-guideline-content/README.md) | Node nativo, sin instalación de dependencias, acceso a Shopify ni builds. |

Pueden reutilizarse de inmediato las identidades de ruta respaldadas, la separación de categorías/marcas, los nueve pares categoría-modalidad de catálogo y las URLs de soporte/redes. Esto no confirma stock, publicación por tienda, vigencia del documento externo, membresía de colección o acceso de una persona. La implementación consumidora nueva todavía debe construirse.

## Evidencia y simultaneidad

- HEAD leído: `c828d684ed7ced1502a2c14ac5fc174cd882661f`, con cambios existentes de otras tareas conservados; [registro del checkout e instrucciones](evidence/session.json).
- No se encontraron `AGENTS.md` aplicables en los ancestros consultados ni bajo los directorios de trabajo de esta tarea. Se leyó la skill PDF para renderizar/revisar la referencia; su convención de salidas se ajustó al alcance de escritura solicitado.
- **144 fuentes locales** con fecha individual, tamaño y SHA-256 en [source-manifest.json](evidence/source-manifest.json). Captura del `2026-10-20T23:15:25.483Z` al `2026-10-20T23:20:50.425Z`. Es una captura por archivo, no una transacción atómica del checkout.
- Se conservan textos congelados para que los anchors y resultados no dependan del trabajo posterior de Claude. Los binarios se registran por identidad y metadatos. El auditor offline no necesita el PDF original en Desktop ni las imágenes originales en sus rutas locales.
- PDF: SHA-256 `7e7414def29c38c65c1ab5ce25dd5f250cc50d65db66a291d67536b45dbb97db`, 19 páginas. Se renderizaron y revisaron completas: hojas [1–5](evidence/pdf-review-01.jpg), [6–10](evidence/pdf-review-06.jpg), [11–15](evidence/pdf-review-11.jpg), [16–19](evidence/pdf-review-16.jpg); [identidades de las evidencias](evidence/pdf-review.json). Son referencia, no assets de producción.
- Comparación de la entrega inicial al `2026-10-20T23:44:29.236Z`: **144 fuentes sin cambio respecto a su captura**, cero desaparecidas. [Informe live inicial archivado](reports/archive/initial-1.0.0/reports/live/audit.json). Esto no cubre archivos ajenos al inventario ni asegura que sigan iguales después de esa hora. La comparación posterior de 1.0.1 se registra separadamente y sí detecta deriva local.
- La entrega Shopify y su auditoría del 19 de octubre se leyeron como evidencia histórica local. No se repitieron sus llamadas, pruebas, capturas o verificaciones remotas. No se leyó ninguna contraseña ni configuración real ignorada por Git.

## Rutas: hallazgos concretos

33 registros están `verificado` como referencia local, 24 `pendiente`, 19 `desconocido` y dos `propuesto`. **Verificado significa que el binding/URL coincide con una fuente congelada; no significa entidad publicada o contenido comercial validado.** Se distinguen valores actuales de propuestas, y un alias no se considera equivalente por similitud del nombre.

| Destino | Evidencia local | Implicación |
| --- | --- | --- |
| Bolsas / Guess | `HomeContent`: Bolsas → `guess`; marca Guess → `guess-1`. El clic de marca nativo filtra `brand: Guess`. | Mantener destinos e identidades separados. El auditor detecta su colisión incluso si se quita el guard particular de una ruta. |
| Carteras / relojes | App: `carteras-1`, `relojes`. Páginas heredadas: `carteras`, `relojes-1`. | No corregir, redirigir o fusionar sin revisar entidades/membresía por tienda. |
| Olaplex / Dior | Handle configurado `olalplex`; etiqueta Dior con clave `Christian Dior` y handle `christian-dior`. | Registrar el aparente typo y la diferencia de etiqueta/taxonomía; no adivinar una corrección. |
| Perfumes | Menú nativo busca términos `perfume`/`fragancia`; existen tres URLs externas por modalidad. | No hay respaldo para inventar `/collections/perfumes`. Catálogo externo y listado de productos propios son alternativas diferentes. |
| Estilos / categorías | Seeds: totes, crossbodys, hombro, satchel, hobo; sus filtros nativos conservan categoría y silueta. Handbags/Accesorios del PDF sin destino dedicado respaldado. | Los dos últimos quedan desconocidos. Arte de satchel/hobo reutiliza tote/shoulder como fallback. |
| Marcas del PDF | Tory Burch, Kate Spade, Marc Jacobs y CH sin seed/logotipo/handle respaldados en las fuentes utilizadas. | Confirmar surtido y la identidad de CH antes de incorporarlas. Los nombres del PDF no prueban existencia de colecciones. |
| Categorías / todas las marcas | Dock y menú actuales abren el catálogo completo. `list-collections.json` usa layout por defecto. | Falta el directorio solicitado. `/collections` es candidato de integración, no una página de directorio nueva certificada. |
| Mayoreo / compartir | `/pages/mayoreo` enlaza `shopify://pages/como-vender`; metaobject usa handle `vende-con-monetta`. Home abre `PartnerHubScreen`; `WholesaleScreen` existe sin invocación activa encontrada desde home/cuenta. | Conservar handles distintos y decidir una composición/destino común. No dar por conectada la pantalla de mayoreo sólo porque existe la clase. |
| Contacto | `https://monetta.mx/pages/contact` aparece en app; tema también conserva referencias `shopify://pages/contact`. Cuenta abre `ContactScreen`; menú home abre WhatsApp. | En Shopify, resolver la página de la tienda activa y evitar salto de staging a producción. Propagar redes runtime y agregar los grupos al contacto si se adopta el PDF. |
| Compartir catálogo | Las nueve URLs coinciden exactamente en fallback Flutter y ajustes de `page.como-vender.json`. | Se pueden integrar enlaces/copia/share; falta verificar contenido, acceso y vigencia. El modo wholesale no es el share predeterminado a clientas. |
| Cuenta / pedidos | Web utiliza `routes.account_url`; nativo tiene pedidos, favoritos y notificaciones. | Direcciones, métodos de pago, subdestino de pedidos y Rewards web permanecen desconocidos. No inventar subrutas ni asumir sesión compartida. |
| Confirmación | PDF 17 es confirmación, no formulario de pago. Nativo exige evidencia `CheckoutCompleted`. | Preservar números/totales reales. Gracias/estado del pedido pertenece a la superficie alojada de checkout, distinta de Customer Accounts y de Liquid. |
| Footer | Tema consume menús y `shop.policies`; rótulos FAQ/envíos/devoluciones/privacidad del PDF no prueban URLs. | Resolver sólo páginas y políticas publicadas; año dinámico. Los destinos individuales sin respaldo quedan desconocidos. |

Fuentes principales: [modelo home](../../../lib/domain/home_content.dart), [home y bindings](../../../lib/features/home/home_screen.dart), [editorial y catálogos](../../../lib/domain/editorial_content.dart), [contacto](../../../lib/features/contact/contact_screen.dart), [mayoreo heredado](../../../storefront-theme/templates/page.mayoreo.json), [catálogos del tema](../../../storefront-theme/templates/page.como-vender.json), [cabecera](../../../storefront-theme/sections/monetta-header.liquid), [dock](../../../storefront-theme/snippets/monetta-dock.liquid). El JSON del inventario conserva los extractos precisos; sus hashes están en el manifiesto.

## Implementación o contenido que falta

- **Campañas:** sólo hay tres fuentes compactas de fallback registradas para seis roles; faltan 15 fuentes por tamaño y focales explícitos. Los 23 usos de imágenes legacy requieren revisión de arte/crop. La portada Coach del listado debe ser una campaña, no su logo ampliado.
- **Home:** falta un manifiesto de composición compartido para hero, estilos, marcas, nueva colección, campaña secundaria, populares, mayoreo, servicios, signup y pie. `HomeSectionId` y las cuatro secciones del index actual no representan esa secuencia completa.
- **Selecciones:** Flutter usa `monetta-todays-picks` mientras el tema selecciona `all`. El enlace Novedades ordena por fecha; el carrusel usa el orden de la colección. No hay una autoridad compartida de popularidad demostrada. No usar `all` para simular estos significados.
- **Datos por tienda:** 21 destinos de colección requieren comprobar entidad/membresía/publicación. La entrega del 19 informa que staging no tenía las colecciones de navegación ni varios metafields/filtros comerciales. Es una observación fechada, sin confirmación actual. La consulta nativa de sólo 50 colecciones tampoco prueba inexistencia fuera de esa página.
- **Editorial:** lista de marcas editable, destinos tipados, covers, servicios, soporte y signup requieren ampliación. Los repositorios actuales no leen un contrato V1 compartido. Hay que propagar contenido runtime hacia contacto y unificar mayoreo.
- **Shopify:** `page.mayoreo.json`, `page.como-vender.json`, `page.contact.json`, `page.json` y `list-collections.json` siguen en layout por defecto. Esto no acredita asignación remota de las plantillas. Predictive search, favoritos y quick view figuran pendientes en la evidencia de entrega.
- **Signup/footer:** falta proveedor de envío real, consentimiento, política de privacidad publicada y copy aprobado. `enabled:false` en baseline es fallback propuesto, sin modificar el estado de la tienda. Mantener menús/políticas reales y año dinámico.
- **Cuenta/confirmación:** validar capacidades y branding de las superficies alojadas. La existencia de CSS del tema no demuestra personalización de cuenta/checkout ni acceso web a Rewards.

Una diferencia de contenido puede permitir un fallback legítimo durante implementación. El informe mide fidelidad/preparación del alcance completo y no exige bloquear toda compra hasta completar cada módulo opcional.

## Decisiones comerciales pendientes

1. **Mayoreo manual o automático.** `WholesaleTerms` dice cotizar por producto; `_WholesaleDiscount` y la página heredada prometen descuento automático. Determinar el comportamiento real y la unidad/umbral: tres modelos, tres piezas o más de tres piezas. No generar una tabla de tramos.
2. **Envío y entrega.** La app contiene gratis desde $1,499; el PDF ilustra otro umbral e incentivo signup. Confirmación muestra 3–5 días hábiles y Mayoreo 2–7. Confirmar política, exclusiones y fuente de estimación antes de unificar textos. No se añade ninguna oferta.
3. **Signup.** Aprobar copy/consentimiento, política y proveedor; la oferta ilustrativa de envío gratis no es autorización comercial.
4. **Taxonomía y arte.** Confirmar surtido/identidad de marcas nuevas, Handbags/Accesorios, colecciones por tienda, logos y originales de campaña con focal por tamaño.
5. **Compartir.** Elegir precios sugeridos o sin precios por categoría; confirmar vigencia de los catálogos y membresía de grupos. Copiar/compartir no prueba una vista o compra ni genera una comisión.
6. **Tienda común.** Resolver la configuración por canal antes de afirmar paridad de productos, cuentas o sesiones. La entrega Shopify reconoce que no está demostrada. No se cambió configuración en esta tarea.
7. **Cantidad histórica de surtido.** El fallback editorial dice más de 3,000 productos. No se utiliza como cantidad actual; confirmar o retirar esa promesa al integrar contenido.

Las nueve entradas del JSON separan algunas de estas decisiones por autoridad/campo. **Rewards no queda abierto a reinterpretación en esta entrega:** conserva MXN y las reglas implementadas (3%, límite de canje 20%, 12 meses, mayoreo no genera, uso en mayoreo pendiente/bloqueado y flags del backend). No se migra a puntos, niveles, bonos de compartir/vistas ni beneficios ilustrativos. Las banderas desplegadas siguen desconocidas.

## Cambios para integrar después en la sesión de Claude

Los siguientes archivos son destinos de integración; **no se editaron en esta entrega**. Los nombres marcados “nuevo” son propuestas, no archivos ya existentes.

| Archivos | Cambio concreto |
| --- | --- |
| `lib/domain/home_content.dart`, `editorial_content.dart`, `campaign.dart`, `collection.dart` | DTOs para campañas/media por tamaño, focal, destino tipado, lista de marcas, cover separado del logo, módulos/servicios/signup y versión. Mantener constructores/aliases y seeds legacy durante transición. |
| `lib/data/shopify/queries.dart`, `home_content_repository.dart`, `editorial_content_repository.dart`, `featured_catalog_repository.dart` | Lectura dual V1/legacy, referencias de imagen, normalización y validación de destinos; paginar/consultar handles; alinear selección y orden. Distinguir documento vacío confirmado de error/incompleto para no restaurar catálogos desactivados. |
| `lib/app/home_content_controller.dart`, `editorial_content_controller.dart` | Conservar último contenido válido por módulo/campo y procedencia. No convertir una respuesta parcial en un cambio de política. |
| `lib/features/home/home_screen.dart`, `home_boutique_sections.dart`, `navigation/monetta_side_menu.dart` | Consumir composición/destinos; conectar directorio y separar Bolsas/Guess. El menú no debe generar handles desde títulos. |
| `lib/features/catalog/` y `category_hub_screen.dart` (nuevo) | Directorio categorías/marcas con todo el catálogo accesible, portada/chips y soporte de destino externo explícito. Mantener filtros y estado reales. |
| `lib/features/wholesale/wholesale_screen.dart`, `wholesale_content.dart`, `partner/partner_hub_screen.dart` | Unificar entrada/contenido, resolver contradicción comercial, campañas/catálogos/soporte y share sin promesas de ganancias. |
| `lib/features/contact/contact_screen.dart`, `account/account_screen.dart` | Propagar redes del contenido runtime, grupos verificados y ruta contact de la tienda correcta. Mantener omisión de canales desconocidos. |
| `lib/features/onboarding/onboarding_sheet.dart`, `lib/app/onboarding_controller.dart` | Si se adopta tipo de compra: opciones/persistencia y skip. Filtrar candidatos con catálogo real; no conceder precio o Rewards por preferencia. |
| `storefront-theme/templates/index.json`, `sections/monetta-hero.liquid`, `monetta-product-rail.liquid`, `monetta-featured-grid.liquid`, `monetta-quick-links.liquid`, `monetta-collection-cards.liquid` | Bindings de contenido compartido; focal de la fuente seleccionada; mismo significado/orden de selecciones; módulos nuevos con campos editables y fallbacks explícitos. |
| `storefront-theme/templates/page.mayoreo.json`, `page.como-vender.json`, `page.contact.json`, `page.json`, `list-collections.json` | Portar contenido y seleccionar layout Monetta cuando corresponda. Antes de retirar bloques legacy, revisar asignación y dependencias en la tienda autorizada. |
| Secciones Shopify `monetta-campaign`, `monetta-brands`, `monetta-services`, `monetta-signup`, `monetta-contact`, `monetta-wholesale`, directorio (nuevas propuestas) | Presentación/copy desde la fuente acordada. Signup sólo con envío y consentimiento reales. No duplicar términos comerciales en ajustes sin autoridad definida. |
| `storefront-theme/sections/monetta-header.liquid`, `monetta-footer.liquid`, grupos y `snippets/monetta-dock.liquid` | Menús y políticas de tienda/locale activos, enlaces a directorio y soporte, redes, año dinámico, fallback de destinos desconocidos. Revisar la superficie real de políticas sin inventar un tipo de template. |
| Cuenta/checkout Shopify y eventual integración en `shopify/extensions/` | Validar capacidades, branding y destinos antes de prometer direcciones/pagos/Rewards web. No crear subrutas falsas ni reutilizar credenciales nativas por suposición. La confirmación alojada es checkout/order-status, no Customer Accounts. |
| `docs/EDITORIAL_CONTENT_METAOBJECTS.md` | Documentar la fuente V1 elegida, campos nuevos, editores, revisión comercial y semántica de desactivación/compatibilidad. Mantener esta captura como evidencia histórica. |

La elección de almacenamiento propuesta en el contrato debe cerrarse antes de conectar ambos consumidores. No se requiere crear todas las definiciones sugeridas: elegir una sola fuente editorial con referencias/adapters. Migrar datos o configurar Shopify corresponde a una etapa posterior autorizada.

## Ejecución y resultados

Desde `/Users/alexis_reyna/MyCode/Monetta`:

```sh
node tools/style-guideline-content/audit.mjs
node --test tools/style-guideline-content/test/*.test.mjs
node tools/style-guideline-content/audit.mjs --live
node tools/style-guideline-content/audit.mjs --strict
node tools/style-guideline-content/verify-corrections.mjs
```

| Verificación propia | Resultado guardado |
| --- | --- |
| Auditor offline | Exit `0`; 78 rutas, 19 páginas; 47 errores de preparación, 196 pendientes/avisos. [JSON](reports/offline/audit.json), [Markdown](reports/offline/audit.md). |
| Pruebas Node | **81/81 aprobadas**, cero omitidas: 35 originales intactas y 46 nuevas. [TAP](reports/correction-1.0.1/tests.tap). Cobertura original más identidad de catálogos, fuentes resolubles, disyunciones reales del esquema, familias/estructuras de módulos y preservación de la captura. |
| Reproducibilidad | JSON y Markdown idénticos byte por byte en dos ejecuciones offline. [Huellas y comprobación](reports/reproducibility.json). |
| Modo estricto | Exit `1` esperado por preparación pendiente; diferente de exit `2` por error de ejecución/entrada. |
| Comparación local posterior | Exit `0`; 144 fuentes comparadas; deriva detectada en `storefront-theme/layout/monetta.liquid`. No consulta red ni reinterpreta la captura. [JSON live](reports/correction-1.0.1/live/audit.json). |

No hubo hallazgos de hash de snapshot alterado, extractos de evidencia ausentes, referencias de destino inventadas en los valores existentes o assets registrados sin respaldo local. Los desconocidos permanecen como tales. El auditor utiliza módulos nativos y valida el vocabulario del esquema entregado; sus límites están en el README.

No se lanzaron builds, suites visuales, capturas de la aplicación, Theme Check, proxy, Shopify CLI, checkout o escrituras remotas. Las únicas imágenes generadas son renders locales de la referencia PDF en este directorio autorizado. El alcance queda preparado para integración; la implementación visual y la publicación comercial continúan en sus etapas correspondientes.
