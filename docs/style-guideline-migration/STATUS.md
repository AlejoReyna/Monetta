# Migración a la guía de estilo: estado

**Última actualización:** 20 de octubre de 2026. **Hito 1:** fases 0 y 1 cerradas para revisión, fase 2 iniciada. Nada está confirmado (commit), publicado ni subido a Shopify.

Plan: [MONETTA_STYLE_GUIDELINE_MIGRATION_PLAN.md](../MONETTA_STYLE_GUIDELINE_MIGRATION_PLAN.md). Referencia: `guideline.pdf` (SHA-256 `7e7414de…97db`). Vista revisable: [m1/index.html](2026-10-20/m1/index.html).

## Dónde está el trabajo

| Superficie | Ubicación | Estado de git |
| --- | --- | --- |
| Tokens, generador | `design-system/` (checkout principal) | sin seguimiento |
| Prototipo web | `design-prototype/` (checkout principal) | sin seguimiento |
| Tema Shopify (solo local) | `storefront-theme/` y `docs/web-redesign/shopify-staging/scripts/port-css.mjs` | sin seguimiento / existente |
| App Flutter | worktree `.claude/worktrees/style-guideline`, rama `feat/style-guideline-migration` desde `c828d68` | **sin commit** (nadie lo pidió) |
| Evidencia y estado | `docs/style-guideline-migration/` | sin seguimiento |

El código Flutter va en un worktree porque `refactor/rf-17-tipografia` está bloqueada esperando a la persona y los cambios a `theme.dart` y a los roles tipográficos chocarían con RF-17. Los cambios sin relación del checkout principal (dart-defines, checkout) no se tocaron ni están en el worktree. Un segundo agente preparó en paralelo el contrato de contenido: [content-readiness/REPORT.md](content-readiness/REPORT.md).

## Fase 0: estado actual frente al diagnóstico

| Punto del diagnóstico | Resultado hoy | Diferencia |
| --- | --- | --- |
| Línea base Flutter dirigida: 67 | **67 aprobadas** | Coincide. |
| Pruebas unitarias del prototipo: 52 | **52 aprobadas** | Coincide. |
| Navegador del prototipo, identidad y layout: 51 | **51 aprobadas** | Coincide. |
| «La suite completa no está certificada» | En `c828d68`, **sin ningún cambio mío, fallan 15 de 1308 pruebas** en 4 archivos: `app/media/packshot_fit_test` (6), `text_scale_catalog_screens_test` (4, caso Colección ×1.3), `goldens/ui04…` (4, caso Ficha) y `home_account_invitation_test` (1, animación) | **Nueva.** El diagnóstico solo corrió 67. Siguen fallando igual tras mis cambios. |
| `dart format` y análisis | En la base: `flutter analyze` 8 avisos `info`; el gate de formato falla en 4 archivos de checkout (no relacionados) | **Nueva.** Tras mis cambios el análisis queda en 7 avisos. |
| Dos capas de tokens, `accent` dorado | `MonettaColors.accent` se lee como **color de texto** en 10 archivos (about, admin, cuenta, partner, home, experiencias, selector de apariencia, creador de catálogo, navegador) | **Nueva.** Cambiarlo al dorado decorativo habría bajado esos textos a 2.3:1; se conservó (ver abajo). |
| Tienda pública Atelier 3.5.0 | **No se volvió a consultar** (sin llamada remota en este hito) | Sigue siendo la observación del 20 oct del plan. |
| Staging del 19 oct, integraciones, dispositivos | No verificado | Sin cambio. |
| Estado del disco | El primer intento de crear el worktree llenó el disco (`ENOSPC`); la persona liberó espacio y se completó el checkout. Ningún archivo del repositorio quedó dañado | Incidente de entorno, registrado. |

## Fase 1: fundamentos compartidos

**Manifiesto único:** `design-system/monetta.tokens.json` (v1.0.0-m1, *propuesto*). `node design-system/build.mjs` genera el bloque de tokens de `design-prototype/src/styles/tokens.css` y `lib/app/monetta_tokens.g.dart`; el tema Shopify lo recibe por `port-css.mjs`. `--check` falla si una salida está vieja. El generador **se niega a escribir** si alguno de 22 pares de contraste queda bajo su mínimo.

| Decisión | Valor | Nota |
| --- | --- | --- |
| Lienzo / barras / superficie / panel / mosaico | `#FBF8F2` / `#F7F3EC` / `#FFFFFF` / `#F3EADF` / `#F4EEE5` | Re-muestreados del PDF ([muestras](2026-10-20/pdf-color-samples.md)). |
| Acción principal, píldora oscura | `#745237` (6.99:1 con blanco), `#2D1E14` | El PDF muestra `#735136`–`#7A502A`. |
| Texto de acento / dorado decorativo | `#805C32` (5.67:1) / `#C5A052` (solo marcas, 2.32:1) | |
| Navegación | activa `#8C6436`, inactiva `#211B16` | 4.76:1 y 15.4:1 sobre la barra; 3.24:1 entre estados, además de peso 600 y una regla de 2 px. |
| Borde de controles | `#8A7766` (4.03:1) | El contorno dorado del PDF no alcanza 3:1; se usa solo en controles con contorno. |
| Tipografía | Playfair Display + Inter, 11 roles con tamaños por clase de ancho 390/834/1440 | Serif: campaña, título, sección, nombre de producto, fila de cuenta. Sans: cuerpo, tarjeta, precio, control, navegación. Fuente definitiva pendiente de los dueños. |
| Geometría | tarjeta 12, control 12, mosaico 10, píldora 999, hoja 20; objetivos 48 / principal 52 | |
| Breakpoints | 768 y 1024 (web); Flutter usa el ancho disponible | Gutters 16/20/32/40/48. |
| **Controles inferiores (decisión del plan §4)** | Barra de navegación plana a ancho completo en navegación y cuenta; **la ficha de producto mantiene su única barra de compra** y la carrito su barra de pago. No se apilan dos barras fijas | Se confirma con contenido real y texto grande en el hito 2. |

**Ejemplos ejecutables (web):** `/design/cuenta` y `/design/board` en el prototipo, además de Inicio, Colección y Producto restilizados. **Nativo:** `tool/captures/style_keyframes_test.dart` (fuera de `test/`).

## Fase 2: cambios concretos hechos

**Prototipo y tema (web):** botones primario marrón / contorno / oscuro en píldora; precio, insignia de oferta, tarjetas sobre mosaico cálido (foto con `multiply`), chips, buscador, acordeones y opciones; títulos de producto y de sección en serif; **barra inferior plana a ancho completo** con estado activo por color, peso y regla; componentes nuevos `.identity`, `.balance-row`, `.row-list`, `.promo-banner`, `.service-strip`; `theme-color` en el prototipo y en `layout/monetta.liquid`. `port-css.mjs` ya excluye lo exclusivo del prototipo (`.board*`, `.dock--static`) y regeneró `monetta-{tokens,base,components,pages}.css`; el dock Liquid ya usa las mismas clases.

**Flutter:** `MonettaColors` con 8 roles nuevos y paleta clara desde los tokens; botones, chips, hojas y campos del tema; `BoutiquePalette` y `BoutiqueButton` (píldora marrón); roles serif adaptables al ancho (`boutiqueScreenTitle/ProductName/SectionHeading/RowLabel(context:)`); `MonettaNavigationBar` (nueva) con `MonettaFloatingBottomNavigation` como envoltorio de compatibilidad; botón de compra del dock y CTA de Inicio en marrón; Cuenta: avatar, fila compacta de Rewards **en MXN** (sin puntos ni niveles), filas en serif, mosaicos cálidos.

**Pruebas revisadas a la nueva especificación (comportamiento intacto):** paleta, chrome, tipografía (5 archivos), navegación (4), geometría de la barra (3), contraste en Dart (archivo nuevo). **Verificaciones del prototipo revisadas:** identidad, fidelidad y dock; nueva `tests/unit/tokens.test.mjs` (toda variable CSS usada está definida) y `npm run tokens:check`.

## Resultados ejecutados ahora (20 oct 2026)

| Comprobación | Resultado |
| --- | --- |
| `node design-system/build.mjs --check` | Salidas vigentes, 22 pares de contraste aprobados |
| Prototipo `npm test` | **54/54** |
| Prototipo `npm run verify` (completa, 633 s) | **247/247** (D02 10, D03 49, D09 50, con axe sobre las páginas principales y las dos de diseño a 390 y 1440 px y reflow a 320 px, D06 8, D05 6, D07 5, D08 3, D11 115, D10 1). Reporte: [verify-report.json](2026-10-20/m1/verify-report.json) |
| Flutter `flutter test --no-pub` (1335 pruebas) | **1314 aprobadas; 21 fallos = los 15 preexistentes + 6 goldens** que ya se regeneraron (ver abajo). Tras regenerar `test/goldens/ui04/`, las pruebas de goldens pasan (10/10) en este equipo |
| Flutter `flutter analyze --no-pub` | 7 avisos `info` (la base: 8). Sin errores ni advertencias |
| `dart format` | Los archivos que toqué quedan formateados; el gate global sigue fallando en los 4 de checkout de la base |
| Capturas | Web: 15 pares (390/834/1440 × 5 pantallas) con 0 desborde horizontal de página y 0 errores de consola. Nativo: 10 PNG (390/834) |

**No ejecutado:** compilación Android/iOS, suite del backend, `shopify theme check`, dispositivos, Safari/Firefox, VoiceOver/TalkBack, texto ampliado en dispositivo, llamadas remotas a Shopify. Resultados **históricos** (staging del 19 oct, auditorías del 17–19 oct) no se repitieron.

**Texto ampliado, áreas seguras, accesibilidad:** web: axe sin violaciones críticas/serias, reflow a 320 px (equivale a 400 % de zoom) y altura corta 200 px sin pérdida de controles; Flutter: las pruebas de escala 1.3–1.5 y de áreas seguras existentes pasan salvo el caso ×1.3 de Colección, que ya fallaba en la base.

## Pendiente de la persona o de otros

1. **Goldens de `test/goldens/ui04/`:** regenerados para el nuevo diseño; **la persona debe aprobar las imágenes** (D-15) antes de integrarlos. Seis de los diez cambiaron por el diseño; los de Ficha ya diferían en este equipo en la base.
2. **Fuente y arte originales** (decisión de assets del plan §5): fuentes, campañas por tamaño, logotipos, recortes de categoría. Mientras tanto se usan Playfair/Inter y los recursos existentes.
3. **Los 15 fallos preexistentes** y el gate de formato de 4 archivos de checkout: no son de este programa; conviene asignarlos.
4. **Decisiones comerciales** (mayoreo manual o automático, envío y umbral, signup, taxonomía, catálogos de compartir, tienda común) están en [REPORT.md](content-readiness/REPORT.md). Rewards sigue en MXN; **no** se implementó puntos ni niveles.
5. **Aprobación del rumbo visual** con las capturas, en particular: nombre «Catálogo» frente a «Categorías» en la barra, cubierta de colección y el estado inactivo de la navegación casi negro.

## Dependencias de imágenes y datos

- Las capturas usan fotos del snapshot del 17 oct y precios/pedidos/saldo de muestra (marcados). El banner de Inicio nativo no se siembra en el arnés y sale vacío.
- Faltan portada de colección, directorio de categorías/marcas y foco por tamaño: dependen de los originales y del contrato de contenido.

## Siguiente bloque concreto (hito 2, fases 2→3)

1. Integrar de `content-readiness`: DTOs de campaña y destino tipado en `lib/domain/{home_content,editorial_content}.dart` y sus repositorios; separar Bolsas (`guess`) de la marca Guess (`guess-1`).
2. **Directorio de categorías y marcas** (nativo `category_hub_screen.dart`, Shopify `list-collections.json`) y la pestaña «Categorías» de la barra.
3. **Portada de colección** con chips, conteo y orden visibles; cuadrícula de 2/3/4 columnas desde `layout.columns` del manifiesto en Flutter.
4. Migrar los 10 archivos que usan `MonettaColors.accent` como texto a `accentContent`; después, mover `kGold` a los tokens.
5. Ficha: galería sobre el mosaico cálido, filas de servicio, acordeones en serif; vista previa (quick view) centrada en tablet.
6. Revisar el tema Shopify en una vista previa **no publicada** (con autorización): ejecutar `shopify theme check`, comparar con la línea base heredada y cargar las páginas de contacto, mayoreo y colección.
7. Texto grande y VoiceOver/TalkBack en dispositivo con la persona; regenerar goldens aprobados.
