# Primera entrega del tema Shopify — Monetta Staging

Fecha: 19/10/2026. Alcance: trasladar el diseño aprobado de `design-prototype/` a un tema **nuevo y sin publicar** de `monetta-staging.myshopify.com` con el recorrido *Inicio → colección → ficha → agregar → bolsa → entrada al checkout de Shopify*.

Este documento no cierra retroactivamente D11 ni altera las auditorías históricas. Los 52 tests y 227 controles del prototipo son referencia: **no certifican este tema**. Lo que aquí se afirma está respaldado por las ejecuciones de [`RUNS.md`](RUNS.md) (cada una identifica tienda, tema, estado del código, comando, hora y resultado); lo que no se ejecutó está dicho como tal en §10.

## 1. Tema creado

| | |
|---|---|
| Tienda | `monetta-staging.myshopify.com` |
| **ID** | **`192125304866`** |
| Nombre | `Monetta Web F1 borrador sin publicar 2026-10-19` |
| Rol | `unpublished` (verificado en cada subida por `scripts/theme-push.sh` y al final con `shopify theme list`) |
| Creación | 2026-10-19T06:32Z con `shopify theme push --unpublished` (el primer intento falló por nombre >50 caracteres y no creó nada) |
| Preview | `https://monetta-staging.myshopify.com?preview_theme_id=192125304866` |
| Editor | `https://monetta-staging.myshopify.com/admin/themes/192125304866/editor` |

**La tienda de staging tiene contraseña de storefront**: el preview (y el enlace `shopifypreview.com` que genera `shopify theme preview`) redirigen a `/password` para quien no la tiene. Quien tenga la contraseña, o una sesión de administración, lo abre. Las pruebas se hicieron a través de `shopify theme dev` (proxy local autenticado por la persona en su propia terminal; la contraseña no pasó por el chat ni por ningún archivo).

Temas de la tienda antes y después ([`baseline/themes-before.json`](baseline/themes-before.json)): antes `189719183394` live («monetta-production-copy-2026-08-21», Atelier 3.5.0), `189523230754` Horizon, `189523263522` test-data, `189523296290` debut-vintage-theme. Después: los mismos cuatro, sin cambios de rol ni de nombre, más `192125304866`. No se publicó ni sobrescribió ningún otro tema.

## 2. Base utilizada y respaldo

- Base: copia **completa** de Atelier 3.5.0, el tema activo de staging (`189719183394`, `config/settings_schema.json` → `theme_info`). Se descargó en modo lectura con `shopify theme pull` el 2026-10-19T06:31Z.
- Los IDs de Atelier de los documentos (`149125824663`, `151218847895`) son observaciones antiguas de **producción**: no existen en staging y no se usaron como destino.
- Respaldo fuera del directorio subido: [`baseline/atelier-3.5.0-staging-live-copy.tgz`](baseline/atelier-3.5.0-staging-live-copy.tgz) (SHA-256 `a044980ecd927ce6c42ed4ec729554b670e6d0e67175595c7a42c038aa966223`) y su manifiesto por archivo [`baseline/atelier-3.5.0-staging-live-copy.manifest.sha256`](baseline/atelier-3.5.0-staging-live-copy.manifest.sha256) (558 archivos; SHA-256 del manifiesto `516bbde380b8980b527e62e117a6572d43411200cea7f65eb68538f517c6002b`). La copia de trabajo `storefront-theme/` se verificó idéntica a ese manifiesto antes de editar.
- Theme Check de la base: 187 errores / 64 avisos heredados (181 de traducciones) en [`baseline/theme-check-baseline.json`](baseline/theme-check-baseline.json).
- Horizon 4.1.4 también está en staging; no se usó (el handoff pide Atelier y es la base del tema activo).

## 3. Arquitectura y archivos implementados

**Decisión de arquitectura.** Atelier es una base de 100 KB de CSS global y decenas de componentes web. Portar el CSS verificado del prototipo sobre su marcado habría sido frágil, así que las plantillas portadas usan un **layout propio** (`layout/monetta.liquid`, seleccionado con `"layout": "monetta"` en cada plantilla JSON) que **no carga el `base.css` ni los scripts de Atelier**, y secciones/snippets propios con el CSS del prototipo copiado por script. Las plantillas aún no portadas (páginas, blog, 404, listado de colecciones, etc.) siguen con `layout/theme.liquid` y su cabecera Atelier: **cambiar de una a otra se nota** (§9). Todo el comercio es nativo: Liquid, `/cart/*.js`, Section Rendering API, `{% form 'product' %}`, `{% paginate %}`, filtrado de storefront.

Inventario exacto frente a la base: **52 archivos añadidos, 5 modificados (las plantillas JSON `index`, `collection`, `product`, `cart`, `search`), 0 eliminados** (610 archivos en total; el tema remoto descargado al final coincide con el local, con los 7 JSON equivalentes salvo el formato que Shopify reescribe).

| Área | Archivos | Para qué |
|---|---|---|
| Layout | `layout/monetta.liquid` | Cabeceras, fuentes, CSS/JS, grupos de secciones, dock, hoja de bolsa, regiones en vivo |
| Estilos | `assets/monetta-tokens.css`, `monetta-base.css`, `monetta-components.css`, `monetta-pages.css` | Portados del prototipo con `docs/web-redesign/shopify-staging/scripts/port-css.mjs` (reproducible; se eliminan las superficies exclusivas del prototipo y se acotan los selectores de elemento con `:where(.mw)`) |
| Adaptador | `assets/monetta-theme.css` | Sólo lo propio de un tema servidor: `<dialog>`, formularios, hoja de bolsa, filtros, campo de cantidad y tres correcciones de anillo de foco |
| Fuentes y marca | `Inter-{Regular,Medium,SemiBold,Bold}.woff2`, `PlayfairDisplay-Regular.woff2`, sus `OFL.txt`, `monetta-logo{,-2x,-3x}.png`, favicon, `monetta-home-banner.jpg` | Los originales del prototipo/app, con su licencia OFL junto a las fuentes |
| JS | `monetta-core.js` (barras medidas, foco en carruseles, diálogos, flecha «volver»), `monetta-cart.js`, `monetta-product.js`, `monetta-listing.js` | Sin framework ni build |
| Secciones | `monetta-header`, `monetta-footer`, `monetta-hero`, `monetta-product-rail`, `monetta-quick-links`, `monetta-collection-cards`, `monetta-featured-grid`, `monetta-collection`, `monetta-search`, `monetta-product`, `monetta-product-recommendations`, `monetta-cart`, `monetta-cart-sheet` + los grupos `monetta-header-group.json` y `monetta-footer-group.json` | Editables y reordenables en el editor (la portada se compone con 4 secciones, la cabecera y el pie son grupos) |
| Snippets | `monetta-icon` (generado del prototipo con `port-icons.mjs`), `-card`, `-image`, `-logo`, `-fonts`, `-dock`, `-page-bar`, `-section-header`, `-results`, `-listing-layout`, `-filter-groups`, `-hidden-filters`, `-cart-line`, `-menu-icon` | |

Lo que **no se tocó**: `settings_schema.json`, `settings_data.json`, los 100+ `ai_gen_block_*`, las secciones y bloques de Atelier, los locales. Nada de Flutter, backend, `.claude/`, secretos ni configuración de otros sistemas.

Sin datos comerciales en el código: se revisó que no haya IDs, precios, inventarios, descuentos ni listas de productos literales. Lo único «fijo» son textos editables en el editor (p. ej. «Envíos a todo México», el WhatsApp del pie y de la ficha, copias tomadas del prototipo/app) y enlaces de las plantillas a `/collections/all`, que es la colección automática de Shopify.

## 4. Diferencias justificadas frente al prototipo

| Prototipo | Tema | Motivo |
|---|---|---|
| Franja «Prototipo de diseño», interruptores de fallos, panel de demostración | No existen | Instrucción expresa |
| Cabecera fija = franja 28 + cabecera + fila (146 px) | 118 px (cabecera + fila); `--strip-h: 0` | Sin franja; la reserva sigue siendo **medida**, no una constante |
| SPA/router, `history.pushState` por cada filtro | Filtros, orden y paginación son documentos con su URL (formularios GET de Shopify); «Ver más piezas» añade la página y mantiene el enlace `?page=n`. La flecha «volver» de la barra compacta guarda `idx`/`entry` en `history.state` y en `sessionStorage` para saltarse filtros/orden entre documentos | Arquitectura de tema multipágina (handoff §4) |
| Corazón de favoritos, quick view y «+» de variantes | Sin corazón ni página de favoritos. «+» sólo en productos de una única variante; los de varias variantes llevan a la ficha | No simular lo ausente; es el siguiente bloque |
| Buscador predictivo | Campo de búsqueda real (GET `/search`); sugerencias en el siguiente bloque | Alcance |
| Muestras de color | Sólo fichas de texto | «Muestras sólo cuando cada variante mapea a un color fiable» (handoff); no hay datos de color en staging |
| «Más de {marca}» | «También te puede gustar», con las recomendaciones de Shopify | La API de recomendaciones no filtra por marca; el metafield `custom.marca` no existe en staging |
| Cajón de bolsa con cantidades editables | Hoja «En tu bolsa» de lectura (cajón ≥768, hoja <768); se edita en `/cart` | Alcance; las líneas llevan el mismo marcado verificado |
| Portada completa (marcas, historia, redes, Loox) | Hero, Novedades, Accesos, Selección. Disponibles pero sin contenido por defecto: Tarjetas de colección | Staging **no tiene** las colecciones Bolsas/Carteras/Relojes/estilos; no se inventan |
| Datos de la portada («Mayoreo desde 3 piezas», devoluciones) | Omitidos | Afirmaciones comerciales marcadas **[verificar]** en el handoff |
| Precio «$1,369» | «$ 1,369» | Formato de dinero de la tienda (`money_without_trailing_zeros`); no se reformatea |
| Anillos de foco, controles altos, botón de pago sin marca | Ajustes en `monetta-theme.css` y `monetta-core.js` (§12) | Los detectaron la comprobación de píxeles y axe; los anillos recortados existen también en el prototipo |

## 5. Fuente de datos por componente y tienda

Verificado contra la tienda de staging (202 productos; ver §8 para lo que contiene y lo que no).

| Componente del tema | Fuente | Tienda |
|---|---|---|
| Tarjetas: título, marca (`custom.marca` si existe, si no `vendor`), precio, precio anterior, % de descuento, agotado | Objeto `product` de Liquid en cada petición | `monetta-staging.myshopify.com` |
| «Envío inmediato» | Metafield `custom.entrega` si existe; si no, la etiqueta `Envío inmediato` | ídem (el metafield no existe en staging) |
| Colección: lista, conteo, paginación | `collection.products`, `products_count`, `{% paginate %}` | ídem |
| Filtros y orden | `collection.filters` / `sort_options` (Search & Discovery) | ídem: **sólo Disponibilidad y Precio** están configurados |
| Búsqueda | `search.results`, `results_count`, filtros | ídem |
| Ficha: galería, opciones, variante, precio, disponibilidad | `product.media`, `options_with_values`, `selected_or_first_available_variant`; al cambiar de opción se pide a Shopify esta misma sección con `?variant=ID` y se sustituyen precio/disponibilidad/botones | ídem |
| Recomendaciones | `recommendations` (Section Rendering, perezoso) | ídem |
| Agregar al carrito | `POST /cart/add.js` con el **id exacto de variante**; mensajes de error de Shopify | ídem |
| Bolsa: líneas, cantidades, descuentos, subtotal, total | `cart` de Liquid y `POST /cart/change.js` por **clave de línea**; la sección se vuelve a renderizar en servidor | ídem |
| Checkout | Formulario `POST /cart` con `checkout` → redirige a `https://monetta-staging.myshopify.com/checkouts/cn/…` | ídem |
| Menús (categorías, menú móvil, pie) | `linklists` (`main-menu`, `footer`) | ídem: son los predeterminados de Shopify (Home / Catalog / Contact, Search) |
| Logotipo, fuentes, tokens, banner por defecto | Archivos del tema (originales de la app) | — |
| Hero, Accesos, textos de servicio, WhatsApp | Ajustes de sección (editor) | — |

## 6. Sincronización app ↔ web: qué tienda usa cada componente (no se declara sincronización)

| Componente | Catálogo | Carrito / checkout | Evidencia |
|---|---|---|---|
| **Tema borrador** (esta entrega) | `monetta-staging.myshopify.com` | el de esa tienda | §5; recorrido ejecutado |
| App Flutter, configuración de ejemplo «staging» | **`monetta.mx`** (producción) | `cartCreate` + `checkoutUrl` de la tienda configurada | `config/dart_defines.staging.json.example:4` (`"SHOPIFY_STORE_DOMAIN": "monetta.mx"`); `config/README.md:36-38` («una tienda de desarrollo es una tienda separada: productos, variantes, clientes, carritos y pagos no son los de monetta.mx»; **texto sin commitear de otra sesión**, el archivo está modificado en el árbol de trabajo) |
| App Flutter, producción | `monetta.mx` / `www.monetta.mx` / `fakcei-n9.myshopify.com` | ídem | `lib/data/shopify/storefront_config.dart:48-52`; `lib/app/runtime_config.dart:64-70` rechaza otra tienda en producción |
| `services/accounts_orders` (Fly «staging») | No lee catálogo (cuentas, pedidos, rewards por webhooks) | Pedidos de la tienda en `SHOPIFY_STORE_DOMAIN` | `services/accounts_orders/README.md:259` (`monetta-staging.myshopify.com`); app CLI instalada sólo en staging: `shopify/shopify.app.staging.toml:8` |
| Espejo de catálogo (Vercel + Firebase «staging») | **Lee la tienda de producción `fakcei-n9`** (sólo lectura) y escribe en Firestore staging | — | `shopify/shopify.app.catalog-mirror.toml:2`; `docs/SYSTEM_IMPLEMENTATION.md:94-98` |
| `design-prototype/` y galería `web/` | Instantánea del catálogo público (producción, 17/10/2026) | Simulado | `design-prototype/PROVENANCE.md` |

**Conclusión.** El tema y el backend de cuentas apuntan a la tienda de staging; la app, en su configuración de ejemplo, y el espejo leen producción. **No está demostrado que app y web operen sobre la misma tienda y las mismas variantes**, y las tiendas de staging y producción no comparten inventario ni variantes. No se abrió `config/dart_defines.staging.json` (real, ignorado por Git), así que no se sabe a qué tienda apunta el build que use la persona. **No se ejecutó ninguna compra cruzada app↔web.** Compartir carritos o favoritos entre ambos es alcance adicional. Hay cambios sin commitear de otra sesión en `lib/app/runtime_config.dart`, `lib/data/shopify/storefront_config.dart` y `config/README.md` (apertura a un dominio de staging); no se tocaron ni se interpretaron como parte de esta entrega.

## 7. Verificación ejecutada

Todas las ejecuciones están en [`RUNS.md`](RUNS.md) (generado) y en `runs/<hora>-<nombre>/`. Los guiones están en `scripts/e2e/`; el navegador es el Brave ya instalado con `playwright-core` (no se instaló nada). Datos reales de staging: 202 productos, 142 de una sola variante, 39 en oferta, 3 sin ninguna variante disponible (dos *snowboards* de prueba y una tarjeta de regalo) y 2 con variantes parcialmente agotadas.

**Estado del código de todas las ejecuciones finales:** SHA-256 del árbol de `storefront-theme/` = `a962cd92f8a480e199bf880714c3c85addf9e8e5c4eb179aaf7550cf10e5f0bf` (610 archivos), el mismo que el tema remoto `192125304866` (descargado con `shopify theme pull` y comparado archivo por archivo; sólo difieren los JSON en el formato que Shopify reescribe). Las 30 ejecuciones de [`RUNS.md`](RUNS.md) comparten ese árbol. Los defectos corregidos antes de congelarlo y sus ejecuciones previas están en §12.

| Verificación | Resultado (todo sobre datos reales de staging) |
|---|---|
| **Theme Check** (`shopify theme check`) | 187 errores / 64 avisos, **idéntico a la base**; **0 hallazgos en los archivos nuevos** ([`runs/theme-check-final.json`](runs/theme-check-final.json)) |
| **Recorrido de compra** (`e2e/journey.mjs`) en 375×812, 440×956, 768×1024, 1024×768, 1440×900 y 812×375 | **55/55, 55/55, 52/52, 52/52, 51/51 y 52/52** (el de 812×375 se repitió: su primer intento dio 43/45 por un 502 del proxy) |
| **Matriz de maquetación** (`e2e/layout.mjs`): 15 tamaños (375×812, 440×956, 768×1024, 1024×768, 1440×900, 320×640, 812×375, 1024×200, 1280×200, 1024×480/481, 360×480/481, 768×480/481) | **219 comprobaciones, todas en verde** (213/214 en la serie y 10/10 en la repetición de 768×481, que sufrió un *timeout* del proxy). Con insets de 44 px en 375×812, 812×375, 1024×200, 768×1024, 1440×900 y 1024×481: **77/77** |
| **Teclado y píxeles** (`e2e/keyboard.mjs`): Tab y Shift+Tab sin activar el skip link, en 10 tamaños × 5 páginas | **50 de 50 combinaciones en verde**: cada centro visible y alcanzable por *hit test* (sin exención para controles altos), anillo leído en los cuatro lados de la captura, y las mismas paradas de ida y vuelta. Con insets de 44 px en 375×812, 812×375 y 1024×768: **45/45** |
| **Fila de categorías de tablet** (`e2e/nav.mjs`) en 768, 812×375, 1023, 1024 y 1440, con y sin insets de 44 px | **31/31 y 31/31**: el último enlace sale del degradado, los doce enlaces tienen anillo completo y texto de tinta, y por debajo de 1024 px sus píxeles son idénticos con la máscara retirada (tolerancia 0) |
| **Accesibilidad** (`e2e/axe.mjs`, axe-core del prototipo): 6 páginas + cajón de filtros, menú, hoja de bolsa y bolsa con una línea, en 375 y 1440 | **18/18, cero hallazgos serios o críticos** |
| **Movimiento reducido** (`e2e/motion.mjs`) | **4/4**: con la preferencia, transiciones ~0 y cajón en su sitio sin deslizar; sin ella, 180/280 ms |
| **Capturas** (`e2e/screens.mjs`): 8 tamaños, hasta 13 vistas cada uno (inicio, colección, colección filtrada, cajón de filtros, menú, ficha, variante agotada, búsqueda, bolsa vacía y con líneas…), esperando fuentes y decodificación de cada imagen | 95 comprobaciones de captura (93 en la serie; las dos que sufrieron *timeouts* se repitieron en verde) más las de 812×375 y 375×812 con insets de 44 px; **abiertas y revisadas** (hojas de contacto `sheet-*.png` en cada carpeta) |
| **Controles negativos** | **5 de 5 detectados**: al reintroducir el anillo del dock, el de las miniaturas, el de los carruseles, el de la barra lateral y la liberación de barras a ≤480 px, el verificador falla |

Lo que el recorrido de compra comprueba contra el JSON de Shopify (`/products/x.js`, `/cart.js`): el conteo de piezas del filtro coincide con el de la faceta (199); el orden por precio es el de Shopify; *Atrás/Adelante* y la flecha de la barra compacta (salta filtro y orden); «Ver más piezas» añade la página 2 y deja `?page=2`; el cambio de opción fija exactamente esa variante (id oculto y `?variant=`) con su precio; una variante agotada muestra «Agotado» y botón inactivo; **un doble clic rápido envía una sola petición**; la bolsa gana exactamente esa variante; la hoja «En tu bolsa» se abre y `Esc` devuelve el foco; el rechazo de Shopify (variante inexistente → 422) muestra su mensaje en un aviso con `role="alert"` y en línea, deja la bolsa intacta y **resincroniza** la ficha; en la bolsa las líneas, el total y los importes tras `+`, `−`, eliminar y *Deshacer* coinciden con Shopify; la bolsa vacía recupera el dock; y *Continuar al checkout* entrega a `monetta-staging.myshopify.com/checkouts/cn/…` (no a producción).

Valores medidos que coinciden con el diseño: barra compacta de 76 px que crece a 160 px con un título de dos líneas y la reserva la sigue; dock de 90 px y barra de compra de 65 px reservados; a 1280×200 el visor mide 571×714 (como en la auditoría del prototipo), la barra lateral y el panel quedan estáticos y la liberación a ≤480 px se invierte en 481; cabecera fija de 118 px a 1024×481; recomendaciones móviles con título Inter 17/600, tarjetas de `min(52vw, 260px)`, foto 4:5 a ras, separación de 12 y nombre de dos líneas; cabecera de ficha móvil con volver + buscar · logo centrado · cuenta + bolsa, objetivos de 48 px.

**Incidencia de infraestructura del 19/10 (no del tema).** El proxy autenticado de `shopify theme dev` caducó (`401 {"error":"unauthorized"}`) a las ~2 h; la CLI siguió autenticada y un segundo proxy local levantó sin pedir la contraseña, pero en la serie siguiente el proxy dio *timeouts*, algún 502 y respuestas de error. Esa primera serie completa (contra el proxy caducado) se descartó entera; después se añadió a los guiones una espera de recuperación y una negativa a registrar resultados con el proxy caído, y los subconjuntos que fallaron por esa causa se repitieron por separado. Las ejecuciones fallidas siguen en `runs/` y en `RUNS.md`. Los recorridos de 375 a 1440 corrieron en `:9293` y el resto en `:9292`; ambos servían el mismo tema remoto.


## 8. Hallazgos sobre la tienda de staging (no son defectos del tema)

- **Sólo 3 colecciones** (`automated-collection`, `frontpage`, `hydrogen`) más `/collections/all`: no existen `guess`, `totes`, `crossbodys`, `hombro`, `carteras`, `relojes` ni las de marca que cita el handoff.
- **Filtros:** únicamente Disponibilidad y Precio. No están configurados `custom.marca`, `custom.categoria`, `custom.estilo`, `custom.color` ni `custom.entrega` (los productos tampoco tienen esos metafields). El tema los mostrará cuando existan; no inventa datos.
- **Idioma:** la tienda responde en inglés (menús «Home / Catalog / Contact», opciones de orden «Alphabetically, A-Z», mensajes de error de Shopify como «Cannot find variant», botón «Buy it now» de pago acelerado). El tema escribe sus textos en español.
- **`/cart/add.js` acepta variantes marcadas `available:false`** (se probó con la variante «Negro» de `bolso-steve-madden-crossbody-3` y con 5000 unidades en 60 productos: ningún 422). El tema las bloquea en la interfaz según `available`; Shopify no. El único rechazo reproducible es una variante inexistente (422 «Cannot find variant»), que es exactamente lo que enviaría una página desactualizada; con él se ejercitó el error en línea y la resincronización.
- Las descripciones de producto de staging son copia de producción y **enlazan a `https://monetta.mx/pages/contact`**.
- El orden por defecto de `/collections/all` no es «más recientes»: el carrusel Novedades usa el orden de la colección elegida; para «novedades» reales hay que usar una colección ordenada por fecha de creación (el enlace «Ver todo» sí usa `?sort_by=created-descending`).
- Checkout: tras «Continuar al checkout» la tienda responde `302 /cart → …/checkouts/cn/<token>/en-mx`; un navegador sin la contraseña de storefront termina en `/password`. Se verificó la entrega a Shopify, no la página de checkout.

## 9. Limitaciones y lo que no se verificó

- **No verificado:** dispositivos reales, Safari y Firefox, lectores de pantalla, teclado virtual real, zoom nativo, el editor de temas (no hay sesión de administración: no se probaron arrastrar/reordenar secciones ni la vista previa del editor), Loox/Labeler/Booster/Clarity (no aparecen en el HTML de la ficha de staging, así que no hay nada que probar; el bloque `@app` está listo), la página de checkout y cualquier pago o pedido. Los insets son emulación CDP; los tamaños son viewports CSS.
- **No hay `RESULTADO` de D11 ni se actualizaron STATUS/VERIFICATION/FINAL_REPORT**: esta carpeta es seguimiento nuevo.
- **Los textos de interfaz están escritos en español dentro del tema**, no en archivos de traducción (la tienda opera en un idioma de interfaz y el locale por defecto de Atelier es inglés).
- Inconsistencia visible mientras conviven los dos layouts: las páginas no portadas (blog, páginas de contenido, 404…) conservan la cabecera y el pie de Atelier.
- Atribución de carritos (`_channel`, `_platform`, `_device_id`, `_app_version`, `_rec_source`): el carrito web **no** las envía; es una decisión de negocio pendiente (handoff §11.12).
- Atelier sigue contando 187 errores / 64 avisos de Theme Check heredados; ninguno está en los archivos nuevos.

## 10. Siguiente bloque (concreto)

1. Decidir con la persona la tienda común app↔web y qué hacer con el espejo (§6) **antes** de hablar de sincronización; si es staging, configurar el Headless/Storefront de staging y repetir una compra cruzada.
2. Cargar en staging lo que el diseño necesita (colecciones Bolsas/Carteras/Relojes/estilos y marcas, metafields y filtros de Search & Discovery) como migración revisada, o decidir qué se oculta.
3. Páginas faltantes: favoritos (corazón + `/pages/favoritos`), quick view para productos de varias variantes, buscador predictivo, marcas/historia/redes/Loox en la portada, Mayoreo/Contacto/Historia, 404, y llevar `layout/monetta` a las demás plantillas para quitar la cabecera Atelier.
4. Cajón de bolsa con edición, «vistas recientemente», muestras de color cuando haya datos.
5. Revisión en el editor de temas con una sesión de administración y en dispositivos reales (iOS Safari, Android Chrome, VoiceOver/TalkBack).
6. Cerrar la documentación del prototipo (R2-01..03 y RESULTADO de D11) como trabajo propio, no mezclado con este.

## 11. Cómo se reanuda

```sh
# Proxy local autenticado (pide la contraseña de la tienda en su propia terminal), sólo contra el tema borrador
docs/web-redesign/shopify-staging/scripts/start-theme-dev.command
# Subida con guardián (verifica tienda, ID, nombre y rol «unpublished» antes de empujar)
docs/web-redesign/shopify-staging/scripts/theme-push.sh
# Verificación (ejemplos)
node docs/web-redesign/shopify-staging/scripts/e2e/journey.mjs --base-url=http://127.0.0.1:9292 --w=375 --h=812
node docs/web-redesign/shopify-staging/scripts/e2e/keyboard.mjs --base-url=http://127.0.0.1:9292
node docs/web-redesign/shopify-staging/scripts/runs-index.mjs   # regenera RUNS.md
```

`THEME.env` fija tienda e ID: no se debe editar sin una nueva autorización. El proxy deja `theme dev` sincronizando `storefront-theme/` con el borrador mientras esté abierto; ciérralo con Ctrl+C cuando termines.

## 12. Registro de errores y correcciones durante el trabajo

**Errores de exploración y de herramientas (sin atribuirlos al tema):**

- `timeout: command not found` (macOS). El primer `theme push --unpublished` falló con «Nombre es demasiado largo (el máximo es 50 caracteres)»; se comprobó con `theme list` que no creó nada.
- `shopify theme dev` sin contraseña: `Failed to prompt: Enter your store password`; `theme preview` devolvió una URL que también redirige a `/password`. Se resolvió con la persona escribiendo la contraseña en su propia terminal.
- Durante el desarrollo, el servidor rechazó subidas por: filtros o comparaciones dentro de los argumentos de `{% render %}` (3 veces), nombres de esquema de más de 25 caracteres y una plantilla que apunta a una sección aún no subida (se resolvió tocando la sección y luego la plantilla).
- Guiones propios: `settle()` se colgó 10 minutos esperando imágenes `lazy` fuera de la vista (se mató y se reescribió con carga forzada y límite de tiempo); el muestreador de anillos asumía «lados rectos» en botones circulares y leía los píxeles *después* de mover el foco; el recorrido de Shift+Tab empezaba fuera del documento; una sustitución mía duplicó la cola del guion del recorrido (se reconstruyó); `path` es una variable especial de zsh; el proxy devolvió algún 502 transitorio (los guiones de teclado, capturas y axe lo reintentan y lo registran).
- Expectativas mías equivocadas, corregidas en la prueba y no en el tema: *Forward* tras la flecha «volver» regresa a la primera entrada de la pantalla (no a la última); la comparación píxel a píxel con la máscara retirada sólo tiene sentido por debajo de 1024 px (a 1440 mostró ruido de captura de mi método).

**Defectos reales del tema que las comprobaciones encontraron y que están corregidos** (el prototipo comparte los tres primeros; el cuarto y los siguientes son de la adaptación):

1. El anillo de foco del ítem «Inicio» del dock quedaba tapado por el relleno dorado del vecino seleccionado → `.dock__item:focus-visible { z-index: 1 }`.
2. Anillos recortados por su propio contenedor con desplazamiento: miniaturas de la galería (tira y columna), tarjetas de los carruseles desde 1024 px (la regla portada quitaba el relleno lateral) y la barra lateral de filtros → anillo interior en miniaturas y relleno de 6 px en carruseles y barra lateral (`monetta-theme.css`, bloque «Focus rings clipped…»). El registro de la ejecución que los encontró se conserva en [`runs/antes-de-corregir/`](runs/antes-de-corregir/).
3. El primer grupo del cajón de filtros se abría cerrado (la barra lateral sí lo abría) → `open_first` también en el cajón.
4. Las líneas de la hoja «En tu bolsa» repetían `data-line` de las de la bolsa (colisión de selectores) → sólo las líneas editables lo llevan.
5. Al aplicar un filtro se añadía `sort_by` por defecto a la URL → sólo si no es el orden por defecto.
6. Hallazgo de revisión de código (no de una prueba): los campos de precio vacíos se deshabilitaban al enviar y seguían deshabilitados tras *Atrás* (caché de ida y vuelta) → la URL se construye con los campos no vacíos; `--scrollbar-comp` se calcula al abrir un cajón.
7. Disponibilidad y precios de una página restaurada o largo rato oculta se vuelven a pedir a Shopify (`pageshow` persistido, `visibilitychange` > 30 s), en ficha y bolsa.
8. **Control alto sin centro visible:** a 1024×200 las tarjetas (469 px) y el visor de la galería (540 px) no caben en la ventana y, con foco de teclado, el navegador alineaba un borde dejando el centro fuera de pantalla → al recibir foco por teclado, un control cuyo centro queda fuera de la banda visible desplaza la página hasta centrarlo (o a meterlo en la banda si cabe) (`keepFocusedCentreInView` en `monetta-core.js`; sin exención para controles altos). Evidencia previa: [`runs/antes-de-corregir/keyboard-1024x200-centro-fuera-de-pantalla.json`](runs/antes-de-corregir/keyboard-1024x200-centro-fuera-de-pantalla.json).
9. **Contraste del botón de pago acelerado:** axe marcó como *serious* el «Buy it now» azul de Shopify (texto blanco sobre `#1990c6`) en la ficha, a 375 y a 1440 → sólo la variante **sin marca** (`.shopify-payment-button__button--unbranded`) se restiliza como botón de contorno, como «Comprar ahora» del prototipo; los botones de billetera (Shop Pay, Apple Pay, PayPal) conservan su marca. Evidencia previa: [`runs/antes-de-corregir/axe-contraste-boton-pago-acelerado.json`](runs/antes-de-corregir/axe-contraste-boton-pago-acelerado.json).

**Controles negativos.** Para no fiarse de verificadores que sólo saben pasar, la serie final incluye ejecuciones que **reintroducen a propósito** cuatro de los defectos (anillo del dock, anillo de miniaturas, anillo de carruseles, anillo de la barra lateral) y la liberación de las barras fijas a ≤480 px de alto, inyectando una hoja de estilos; deben fallar y aparecen aparte en [`RUNS.md`](RUNS.md).

## 13. Estado de git y de la tienda antes y después

- `git status --short` antes y después (HEAD `c828d684ed7ced1502a2c14ac5fc174cd882661f`, rama `refactor/rf-17-tipografia`, sin cambios): la única diferencia es el directorio nuevo `storefront-theme/`. `docs/web-redesign/` ya figuraba como no versionado, así que `docs/web-redesign/shopify-staging/` no añade una línea propia. Los diez archivos modificados de otra sesión (`Makefile`, `config/README.md`, `lib/…`, `test/…`) y los demás no versionados se conservaron intactos. **Sin commits, push, despliegues ni cambios en Flutter, backend, `.claude/`, secretos o configuración de otros sistemas.**
- Temas de la tienda ([`baseline/themes-before.json`](baseline/themes-before.json) y [`baseline/themes-after.json`](baseline/themes-after.json)): el único cambio es el tema nuevo `192125304866` (`unpublished`). El tema activo y los otros tres no cambiaron de rol ni de nombre. No se escribió en producción (`monetta.mx` / `fakcei-n9.myshopify.com`) ni se cambiaron productos, inventario, descuentos, menús, pasarelas, cuentas o aplicaciones. Las pruebas añadieron variantes a carritos de navegador de usuario anónimo y abrieron el checkout sin completarlo: no hay pedidos ni pagos.
- Procesos locales: el proxy `shopify theme dev` sigue abierto en la terminal de la persona (puerto 9292) sincronizando `storefront-theme/` con el borrador; hay que cerrarlo con Ctrl+C. El segundo proxy (9293) que levanté para la verificación ya está cerrado.
