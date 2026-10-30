# MON-WEB-01 — Especificación del tema Shopify (staging)

Estado: borrador v0.1 · 2026-10-16 · Autor: Product designer · Para: Engineer (MON-WEB-02), Daniel (PM)

**Alcance:** tema duplicado **sin publicar** dentro de `monetta-staging`. Nunca en producción. El checkout lo pone Shopify y no se personaliza aquí (solo el logo y los colores que permiten los ajustes de marca del checkout). Esto es diseño, no código.

**Fuente de verdad:** app de Flutter, repo `AlejoReyna/Monetta`, rama `main`:
`lib/app/theme.dart` (sistema compartido), `lib/features/boutique/boutique_tokens.dart` (capa boutique: Home, bienvenida, catálogo), `lib/features/home/home_screen.dart`, `lib/features/catalog/product_tile.dart`. **No se usa la versión de Vercel como referencia.**
Reglas de logos de pago: `/workspace/monetta-ux/brand/payment-logos.md`.

Idioma: español (MX). Moneda: MXN, formato `$1,299.00 MXN` (usar el `money_with_currency_format` de la tienda).

---

## 1. Breakpoints

| Nombre | Ancho | Columnas del grid de producto | Margen lateral | Navegación |
|---|---|---|---|---|
| Móvil | < 750 px | 2 (1 si < 340 px, igual que `productGridColumns`) | 20 px (`gutter`) | Barra superior: menú (hamburguesa) · logo · búsqueda · carrito. Sin barra inferior (ver §7) |
| Tablet | 750–1199 px | 3 (4 a partir de 1060 px, igual que la app) | 32 px | Igual que móvil hasta 989 px; desde 990 px, menú horizontal |
| Escritorio | ≥ 1200 px | 4 | 48 px, contenido máximo 1320 px centrado | Menú horizontal con categorías + búsqueda abierta + cuenta + carrito |

Nota: la app cambia a 3 columnas en 720 px y a 4 en 1060 px. En la web se usan los cortes de Shopify (750/990/1200) y se respeta 1060 px → 4 columnas dentro de tablet para no tener tarjetas más anchas que en la app.

## 2. Tokens → ajustes del tema (`settings_schema.json`)

Se usa la **capa boutique** (la que ya ven los clientes en Home y catálogo), no la paleta cuadrada vieja de `theme.dart`, salvo donde se indica. Solo modo claro en la v1 (el modo oscuro de la app es un pendiente, ver preguntas).

### 2.1 Color

| Token app | Hex | Ajuste del tema (id sugerido) | Uso |
|---|---|---|---|
| `BoutiquePalette.canvas` | `#FFFFFF` | `color_background` | Fondo de página |
| `surface` (panelGrey) | `#FAFAFA` | `color_surface` | Tarjetas, paneles |
| `surfaceDeep` (deepGrey) | `#F0F0F0` | `color_surface_deep` | Fondo de foto, chips, campo de búsqueda, selección |
| `bar` = `navigationSurface` | `#F5F5F5` | `color_header_bg` / `color_footer_bg` | Header y footer (banda gris arriba y abajo, como en la app) |
| `ink` | `#111111` | `color_text` | Texto principal, botón primario |
| `inkMuted` | `#6B6660` | `color_text_secondary` | Texto secundario (5.7:1 en blanco, 5.2:1 en barra). **No usar `#737373`**: baja a 4.35:1 en la barra |
| `gold` | `#C5A052` | `color_accent_line` | Solo líneas, filetes y marcas. **Nunca texto** (2.5:1) |
| `goldText` | `#8F6838` | `color_accent_text` | Kickers/eyebrows dorados, texto de acento (5.0:1) |
| `hairline` | `#111111` al 12 % (`#1F111111`) | `color_border` | Divisores, bordes de tarjeta |
| `sale` | `#A3342B` | `color_sale` | Precio en oferta, badge de oferta |
| `success` (theme.dart) | `#3B7B4A` sobre `#EAF4EC` | `color_success` / `color_success_bg` | Confirmaciones |
| `warningSurface` (theme.dart) | `#F7F0E6` | `color_notice_bg` | Avisos (p. ej. ayuda de transferencia) |
| `onDark` (ivory) | `#F8F5EE` | `color_on_image` | Texto sobre fotografía |
| `scrim` | `#000000` al 32 % | `color_overlay` | Fondo de drawer/modal |
| `selectedBorder` | `#111111` | — | Selección = relleno + borde + check, nunca solo color |

### 2.2 Tipografía

| Rol | App | Web | Tamaños |
|---|---|---|---|
| Display / títulos editoriales | `Playfair Display` (fallback New York, Georgia, serif), peso 400, tracking −1.2 % | `type_header_font`: Playfair Display (está en la biblioteca de fuentes de Shopify; confirmar) | H1 32 móvil / 40 tablet / 48 escritorio; H2 24/28/32; título de tarjeta de colección 21 |
| Interfaz, precios, cuerpo | `Inter` (fallback SF Pro Text, Helvetica Neue, Arial) | `type_body_font`: Inter | Cuerpo 15, secundario 13, mínimo 11 |
| Eyebrow / kicker | Inter 500, tracking 1.4 px, MAYÚSCULAS, altura 1.3 | clase `.eyebrow` | 11 (badges 10, nunca menos de 10) |
| Botón | Inter 600, tracking 1.2–1.4, MAYÚSCULAS | `.button` | 12–13 |
| Título de producto | Inter 600, tracking −0.1, altura 1.25 | — | 14 tarjeta / 22 PDP (Playfair) |

Regla de la app que se mantiene: los titulares van de 24 a 32 según el espacio, nunca los 8–11 px que sugiere la densidad del mockup.

### 2.3 Espaciado, radios, alturas

- Escala (`BoutiqueSpace`): 4 · 8 · 12 · 16 · 24 · 32. Gutter 20. Separación entre secciones 32 (ajustada 24). En escritorio la separación entre secciones sube a 64 (decisión web, no está en la app).
- Radios (`BoutiqueRadius`): tarjeta 12 · control/botón/input 10 · miniatura 8 · cápsula 999 (chips). Ajustes: `card_radius=12`, `buttons_radius=10`, `inputs_radius=10`.
- Altura de control 52 px; área táctil mínima 48 px en la app → en la web **≥ 44 px garantizado, se usa 48**.
- Sombras: ninguna. La profundidad viene de los escalones de gris y del filete.
- Imagen de producto: 4:5 (densidad normal), 1:1 (densidad compacta, carruseles). Fondo `#F0F0F0`.

## 3. Componentes

| Componente | Especificación |
|---|---|
| **Header** | Fondo `#F5F5F5`, altura 56 móvil / 64 escritorio, iconos 22 px en botones de 48×48. Sticky. Logo centrado en móvil/tablet, a la izquierda en escritorio. Badge del carrito: cápsula `#111111` con número blanco 11 px |
| **Botón primario** | Fondo `#111111`, texto blanco, 52 px alto, radio 10, Inter 600 12–13 MAYÚSCULAS. Hover: `#2A2A2A`. Focus: anillo 2 px `#111111` con separación 2 px. Deshabilitado: `#F0F0F0` + texto `#6B6660` |
| **Botón secundario** | Borde 1 px `#111111`, fondo transparente, mismos tamaños |
| **Enlace de acción** | Texto Inter 13 subrayado o con flecha, color `#111111` |
| **Tarjeta de producto** (`MonettaProductTile`) | Imagen 4:5 radio 12 sobre `#F0F0F0`; botón favoritos (icono 19 px en área 44+) arriba a la derecha; badge arriba a la izquierda (eyebrow 10, ver estados); debajo: marca (eyebrow 11 `#6B6660`), nombre (Inter 14/600, 2 líneas máx.), precio (Inter 15). En oferta: precio actual `#A3342B` + precio anterior tachado `#6B6660`. Sin precio: «Consultar precio» (`kUnknownPriceLabel`) |
| **Vista rápida** | En la app existe (`quick_view.dart`). Web: botón «Vista rápida» solo en escritorio (hover/focus); en móvil y tablet se omite y la tarjeta lleva a la PDP |
| **Encabezado de sección** (`BoutiqueSectionHeader`) | Kicker eyebrow dorado `#8F6838` + título Playfair 24–32 + enlace opcional a la derecha |
| **Tarjeta de oferta** (`_OfferCard`) | Eyebrow 11, título, descripción 13, CTA 13 + flecha 16 |
| **Chips de filtro** | Cápsula, 44 px alto, fondo `#F0F0F0`; seleccionado: borde `#111111` + check |
| **Campo de búsqueda** | Fondo `#F0F0F0` (la app usa `#F1F1F1` en `theme.dart`; se unifica a `#F0F0F0`), radio 10, 48 px |
| **Línea de pagos** | Ver §4.1 |
| **Botón WhatsApp** | Secundario con icono, texto «Escríbenos por WhatsApp», enlace `https://wa.me/528261066868`, `target=_blank rel=noopener` |

## 4. Páginas

### 4.1 Home (`templates/index.json`)
Orden tomado de `home_screen.dart`:

1. **Banner (hero)** — imagen a sangre, texto `#F8F5EE` sobre degradado/scrim; eyebrow + titular Playfair + CTA primario. Móvil: 4:5, texto abajo. Tablet: 16:9, texto abajo-izquierda. Escritorio: 21:9 (alto máx. 640), texto a la izquierda en una columna de 480.
2. **Ofertas** — «OFERTA MONETTA» / «Una selección especial para encontrar tu próxima pieza.» / «Ver la selección»; «NUEVO EN MONETTA» / «Piezas que acaban de llegar» / «Descubrir novedades»; «VENDE CON MONETTA» / «Haz crecer tu negocio con mayoreo» / «Conocer mayoreo». Encabezado: kicker «Para comprar, estrenar o crecer», título «Lo mejor de Monetta, hoy». Móvil: carrusel horizontal con scroll-snap (tarjeta al 85 % del ancho). Tablet: 2 + 1. Escritorio: 3 columnas.
3. **Colecciones** — «Colecciones»: tarjetas editoriales (título Playfair 21 sobre imagen). Accesos: Carteras, Relojes, Perfumes, Maquillaje y skincare. Móvil carrusel; tablet 3; escritorio 4.
4. **Catálogo de hoy** — kicker «Selección Monetta», título «Catálogo de hoy». Grid de tarjetas de producto según §1 (8 productos móvil, 12 escritorio) + «Ver todo».
5. **Marcas** — grid de 2 columnas en móvil, 4 en tablet, 6 en escritorio. Cada una «Ver {marca}».
6. **Más sobre Monetta** — eyebrow «BIENVENID@», texto 13, enlaces «Conoce nuestra historia» y «Vende con Monetta».
7. **Nuestras redes** — tiles 0.82:1 con icono 28.
8. **Cierre (sección final)** — fondo `#F5F5F5` (misma banda que el header):
   - Promesa de confianza: **«100% originales»** (pendiente de Alexis frente a «Originales garantizados»; dejarlo como texto editable del bloque).
   - **Línea de pagos (texto, logos apagados):** «Pagos seguros con tarjeta de crédito o débito, PayPal, Mercado Pago y transferencia.» Inter 13, `#6B6660`, altura 1.45, **hace salto de línea, nunca se corta ni lleva elipsis**, centrada en móvil y alineada a la izquierda en escritorio.
   - Ayuda de transferencia: «¿Pagas por transferencia? Escríbenos por WhatsApp» → wa.me/528261066868. No hay CLABE: **no mostrar datos bancarios en la web**.
   - Apple Pay y Google Pay: **ocultos** (ni texto ni logo).
   - Logos: bloque preparado pero **apagado** (`show_payment_icons=false`). Si se encienden: altura única para todos, solo métodos realmente ofrecidos, artwork oficial sin recolorear (Visa azul), PayPal ≥ 23 px de alto → la fila sería ≥ 24 px, no 22. No usar el `payment_type_svg_tag` automático de Shopify sin filtrar, porque muestra todos los métodos activos (incluido Apple/Google Pay).
   - Enlaces legales/políticas (ver preguntas).

### 4.2 Listado / colección (PLP, `templates/collection.json`)
- Encabezado: título Playfair + número de productos (Inter 13 secundario).
- Filtros (Shopify Search & Discovery): móvil y tablet → botón «Filtrar y ordenar» que abre drawer a pantalla completa (móvil) o lateral 400 px (tablet), con botón fijo «Ver N resultados». Escritorio → columna lateral de 260 px sticky + selector de orden arriba a la derecha.
- Filtros activos: chips con «×» y «Quitar todo».
- Grid según §1, separación 12 móvil / 16 tablet / 24 escritorio.
- Paginación: botón «Cargar más» (secundario) con contador «Mostrando 24 de 120». No scroll infinito (accesibilidad y footer alcanzable).

### 4.3 Ficha de producto (PDP, `templates/product.json`)
- Móvil: galería en carrusel 4:5 a todo el ancho con puntos e indicador «1/5», luego marca (eyebrow), nombre (Playfair 22–24), precio, selector de variante (chips/swatches 44 px), cantidad, botón primario «Agregar al carrito» 52 px y barra fija inferior con precio + botón cuando el botón original sale de pantalla.
- Tablet: igual que móvil hasta 989; desde 990 dos columnas 55/45.
- Escritorio: galería en grid de 2 columnas (o miniaturas verticales a la izquierda) 58 %, info sticky 42 %.
- Debajo del botón: promesa «100% originales» + línea de pagos (misma regla de §4.1) + enlace WhatsApp para dudas.
- Acordeones: Descripción, Detalles/medidas, Envíos y devoluciones (**texto lo define el PM**), Cuidado.
- «También te puede gustar»: recomendaciones de Shopify (`product_recommendations`), carrusel 1:1 compacto. No es la recomendación on-device de la app.

### 4.4 Carrito (`templates/cart.json` + drawer)
- Agregar → **drawer** lateral (escritorio/tablet 420 px; móvil a pantalla completa) con «Agregado al carrito», línea, subtotal, botón primario «Pagar» y secundario «Ver carrito».
- Página de carrito: móvil una columna con resumen fijo abajo; escritorio líneas 2/3 + resumen sticky 1/3.
- Línea: miniatura 1:1 radio 8 (80 px), marca, nombre, variante, stepper de cantidad (botones 44×44), «Eliminar» como texto.
- Resumen: subtotal; «Impuestos y envío se calculan al pagar» (confirmar texto con PM); botón «Pagar» → checkout de Shopify; línea de pagos debajo.
- Sin campo de código de descuento en el carrito (se usa el del checkout), salvo que el PM pida lo contrario.

### 4.5 Cuenta y pedidos
- Shopify tiene «cuentas de cliente» nuevas (hosted) o clásicas. Si son nuevas, **no se diseña en Liquid**: solo se aplica logo y colores en la configuración de marca. Si son clásicas: login (correo + contraseña, 52 px), registro, lista de pedidos (tabla en escritorio, tarjetas en móvil: número, fecha, estado de pago, estado de envío, total) y detalle.
- Estados de pedido: usar los mismos textos que la app (#14) para que coincidan; Engineer copia las cadenas de la rama de #14. Pedido por transferencia pendiente: aviso `#F7F0E6` con «Para completar tu pago por transferencia, escríbenos por WhatsApp» + botón.
- Rewards, favoritos sincronizados, eliminación de cuenta: ver §6.

### 4.6 Búsqueda, 404 y páginas de contenido
- Búsqueda predictiva en drawer superior: productos (miniatura 1:1), colecciones, «Ver todos los resultados».
- Sin resultados: «Sin resultados» (texto de la app) + sugerencias de colecciones.
- 404: titular Playfair «No encontramos esta página» + «Volver al inicio».

## 5. Estados

| Estado | Diseño |
|---|---|
| **Cargando** | Skeleton con bloques `#F0F0F0` del tamaño final (imagen 4:5, 2 líneas de texto, precio) sin animación si `prefers-reduced-motion`. Imágenes con `loading=lazy` salvo el hero. Botón «Agregar al carrito» en carga: spinner 16 px + texto «Agregando…», deshabilitado, sin cambio de ancho |
| **Agotado** | Tarjeta: badge «AGOTADO» (eyebrow 10, `#111111` sobre `#FFFFFF`), imagen al 60 % de opacidad. PDP: botón deshabilitado «Agotado». Variante agotada: chip tachado con `aria-disabled`, sigue seleccionable para ver la info. Aviso de reposición: **no** se incluye hasta que el PM lo decida |
| **Oferta** | Badge con texto, nunca solo color; precio `#A3342B` + tachado |
| **Sin precio** | «Consultar precio» y sin botón de compra; CTA WhatsApp |
| **Carrito vacío** | «Tu carrito está vacío» + «Seguir comprando» (primario) + 4 productos de «Catálogo de hoy» |
| **Colección vacía / sin resultados de filtros** | «No hay productos con estos filtros» + «Quitar filtros» |
| **Sin pedidos** | «Aún no tienes pedidos» + «Ir a la tienda» |
| **Error al agregar** (límite de inventario) | Mensaje en línea bajo el botón, `#A3342B`, con `role=alert` |

## 6. Liquid vs. solo app

| Función | Web (tema) | Nota |
|---|---|---|
| Home, PLP, PDP, carrito, búsqueda | Secciones Liquid / JSON templates | Editables en el editor de temas |
| Filtros | Search & Discovery de Shopify | |
| Recomendaciones | `product_recommendations` de Shopify | La recomendación **on-device** de la app no existe en la web |
| Checkout y métodos de pago | Shopify checkout | Fuera de alcance; solo marca |
| Notificaciones push | **Solo app** | En web no hay sustituto en la v1 |
| Espejo de pedidos (orders mirror, tokens de checkout #18, banners DUP/MON-UX-03 #17) | **Solo app** | La web usa los pedidos nativos de Shopify |
| Rewards (saldo, lotes) | **Solo app** en v1 | Mostrar en web requeriría app embed/proxy del backend; pregunta abierta |
| Favoritos | App: cuenta propia. Web: no hay favoritos nativos en Shopify | Pregunta abierta: ocultar el corazón en web o guardar en local |
| Eliminación de cuenta (#13) | App | En web, solo enlace a la ruta que defina el PM |
| Mayoreo / Partner hub | App | Web: página con CTA «Conocer mayoreo» → ¿WhatsApp o formulario? |
| Vista rápida | Escritorio sí; móvil no | |
| Modo oscuro | App sí | Web v1 solo claro |

## 7. Accesibilidad (WCAG 2.2 AA)
- Contraste: texto ≥ 4.5:1 (grande ≥ 3:1). Verificados: `#111111`/`#FFFFFF` 18.9:1; `#6B6660`/`#FFFFFF` 5.7:1, sobre `#F5F5F5` 5.2:1; `#8F6838`/`#FFFFFF` 5.0:1; `#A3342B`/`#FFFFFF` ≈ 6.9:1. `#C5A052` **prohibido para texto**. Texto sobre foto: scrim hasta ≥ 4.5:1 en la zona del texto.
- Áreas táctiles ≥ 44×44 (se usa 48): iconos del header, favoritos, stepper, chips, puntos del carrusel (área ampliada).
- Foco visible siempre (anillo 2 px), orden lógico, skip link «Saltar al contenido».
- Drawers y modales: `role=dialog`, foco atrapado, Esc cierra, regresa el foco.
- Carruseles: no autoplay (o con pausa), flechas con `aria-label`, operables con teclado.
- Selección y estados nunca solo por color (borde + check, texto en badges).
- `lang="es-MX"`, alt de imágenes = nombre del producto + variante.
- Línea de pagos legible con zoom al 200 % (salta de línea, no se corta).
- Respetar `prefers-reduced-motion`.

## 8. Entregables para MON-WEB-02
Base recomendada: duplicar Dawn (u otro tema OS 2.0) sin publicar; mapear ajustes de §2; secciones nuevas: `monetta-hero`, `monetta-offers`, `monetta-collections`, `monetta-brands`, `monetta-about`, `monetta-social`, `monetta-closing` (promesa + línea de pagos + WhatsApp). Revisión de diseño en 375, 768, 1024, 1280 y 1440 px antes de pasarlo a QA de pagos (LOGO-01).

## 9. Preguntas abiertas para el PM / Alexis
1. Confirmar que la web es tema de Shopify (Liquid) y no Flutter web.
2. Promesa de confianza: «100% originales» u «Originales garantizados».
3. Políticas: textos de envíos, devoluciones, garantía/autenticidad, tiempos de entrega, costo de envío y umbral de envío gratis. No los defino.
4. ¿Qué métodos están activos en el checkout de staging? La línea de pagos debe coincidir; ¿se ocultan Apple/Google Pay también en el checkout o solo en el tema?
5. ¿Cuentas de cliente nuevas o clásicas? Cambia si se diseña cuenta/pedidos en Liquid.
6. Rewards en web: ¿se muestra saldo (necesita backend) o queda solo en app?
7. Favoritos en web: ¿ocultar, guardar localmente o integrarlos con la cuenta?
8. Mayoreo en web: ¿página propia, WhatsApp o formulario? ¿Precios de mayoreo visibles?
9. ¿Aviso de reposición en productos agotados?
10. ¿Perfumes y Maquillaje y skincare entran en la web (la app ya los tiene como accesos)?
11. Fuentes: confirmar licencia/uso de Playfair Display e Inter desde la biblioteca de Shopify.
12. ¿Banner de app («Descarga la app») en la web móvil? ¿Enlaces a tiendas?
13. Imágenes: ¿mismos assets del banner y colecciones de la app? Necesito originales en alta resolución para 21:9.
14. Logos de pago: siguen apagados; si se encienden, falta el artwork oficial (lista en payment-logos.md).
