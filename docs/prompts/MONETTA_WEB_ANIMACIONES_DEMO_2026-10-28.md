# Encargo: animaciones de Monetta en el tema de Shopify (staging) y UX/UI lista para el video demo

## 0. Qué se espera

Implementar en el tema de Shopify de **Monetta Staging** (`monetta-staging.myshopify.com`) las animaciones aprobadas en la investigación de movimiento, y dejar la experiencia lista para grabar un video demo.

El objetivo es que se vea **precioso, en el sentido de Monetta**: un lujo silencioso donde todo está en su sitio. Fotografía real, precios correctos, nada salta ni parpadea, cada toque tiene respuesta y la marca se presenta una sola vez, con el logo escribiéndose en la bienvenida. «Precioso» **no** significa más movimiento: la investigación concluyó que la app no debe moverse en reposo y que cada animación debe comunicar algo.

El trabajo termina en un **duplicado sin publicar** con los cambios, un enlace de vista previa, un guion del demo, un ensayo grabado y la validación completa. **Publicar es decisión de la persona responsable.**

## 1. Lee primero

**Investigación de movimiento.** Rama `claude/determined-wozniak-waw24s`, carpeta `docs/research/monetta-motion-evidence-2026-10-27/`:

- `INVESTIGACION_V2.md`: los 20 candidatos con su decisión R, C o X, sus parámetros y su **Referencia comercial**.
- `REFERENCIAS_COMERCIALES.md`: lo verificado en grabaciones de FARFETCH, Moda Operandi, Zara, HBX, Lyst, ASOS, Zalando y Shop.
- `LOGO_Y_ENTREGA.md`: la especificación del logo escrito letra por letra.
- `index.html` y `evidence/*.jpg`: las hojas de fotogramas. Ábrelas cuando un candidato te genere dudas.

**Proceso web y estado de staging.** Todo en `origin/main`:

- `docs/prompts/MONETTA_WEB_GUIA_1A1_PLAN_2026-10-27.md`: proceso, límites y cómo arrancar el proxy.
- `docs/web-redesign/shopify-staging/guia-1a1/RESULTADO.md`: estado, el incidente del borrador publicado y las validaciones pendientes.
- `docs/web-redesign/shopify-staging/THEME.env`: tienda, ID y nombre del tema de trabajo. No contiene secretos.
- `docs/web-redesign/shopify-staging/scripts/`: `theme-push.sh` (subida protegida; aborta si el tema es `live`), `start-theme-dev.command` y `compare-remote.mjs`.
- `docs/web-redesign/shopify-staging/guia-1a1/scripts/validate.sh`: la batería de comprobaciones (Playwright, axe y Theme Check).
- `design-system/build.mjs --check`, `tools/style-guideline-theme/port-css.mjs --check` y `bin/check_no_secrets.sh`.
- `docs/design/web/MON-WEB-01-theme-spec.md`.

**Código del tema** (`storefront-theme/` en `origin/main`):

- `layout/monetta.liquid`: el layout de inicio, colección, búsqueda, producto y carrito. **No carga** `base.css` ni los scripts de Atelier.
- `layout/password.liquid` y `sections/monetta-guia-welcome.liquid`: la bienvenida web. Foto de la dueña, logotipo, lema y «COMENZAR», que abre el diálogo de contraseña. Este layout **no carga** las hojas de Monetta.
- `assets/monetta-tokens.css`: `--dur-snap` 180 ms, `--dur-swap` 280 ms, `--dur-settle` 480 ms y `--ease: cubic-bezier(0.16, 1, 0.3, 1)`. Son los mismos tokens y la misma curva de la app.
- `assets/monetta-base.css`: la regla global de movimiento reducido (scope `.mw`) y el reveal `[data-reveal]` (480 ms, 10 px).
- `assets/monetta-home-22oct.css`: el reveal de secciones del inicio (0,6 s, 16 px).
- `assets/monetta-core.js`: diálogos de 280 ms, `Monetta.toast`, `Monetta.announce` y `reduceMotion()`.
- `assets/monetta-cart.js`: el camino único para agregar y la hoja «En tu bolsa» (`#cart-sheet`): cajón derecho desde 768 px y hoja inferior en teléfono.
- `assets/monetta-pages.css`: el resaltado de la línea agregada (`@keyframes highlight`, 1,6 s, fondo dorado).
- `assets/monetta-product.js`, `monetta-listing.js`, `monetta-predictive-search.*` y `monetta-guia.js` (el carrusel, sin autoplay).
- `snippets/monetta-logo.liquid`: el logotipo en PNG (1x, 2x y 3x; proporción 132:38). Nunca se recolorea ni se redibuja.
- `snippets/scripts.liquid`: carga `fly-to-cart.js` y `view-transitions.js` de Atelier, solo en el layout `theme.liquid`.

## 2. Punto de partida (verificado el 28 de octubre)

- **`main` avanzó.** Ya incluye la guía 1:1 (#36) y el buscador predictivo (#37). **Parte del `origin/main` más reciente.**
- **El tema publicado de staging puede haber cambiado.** Según `RESULTADO.md`:
  - El 27 de octubre el borrador `192125304866` apareció como `live`.
  - Se trabajó en los duplicados sin publicar `192558366754` (guía) y `192576585762` (buscador predictivo).
  - La validación F9 del buscador seguía pendiente y no se había publicado.
  - **Antes de tocar nada:** ejecuta `shopify theme list --store monetta-staging.myshopify.com` (solo lectura) y pregunta a la persona qué tema es la base correcta.
- **La tienda está detrás de contraseña:** `/` redirige a `/password`. La bienvenida de la página de contraseña es lo primero que verá el demo.
- **El movimiento ya existe en parte:**
  - tokens;
  - movimiento reducido global;
  - diálogos de 280 ms;
  - la hoja de bolsa con foco y anuncio;
  - el resaltado de la línea agregada;
  - un spinner;
  - el `shimmer` de carga;
  - dos reveals al hacer scroll.
- **Lo que no existe:**
  - el logo animado;
  - el estado «Agregando…» dentro del botón;
  - el zoom de la galería;
  - la animación de altura en los plegables.
- **El repositorio es público.** Las evidencias con fotos de la dueña van fuera de git (`.git/info/exclude`), como en la guía 1:1.

## 3. Qué animar, traducido a la web

Cada efecto debe:

- salir de un candidato de la V2;
- usar los tokens;
- animar solo `transform`, `opacity` o `clip-path` (este último, solo para el logo);
- tener su equivalente con movimiento reducido;
- no provocar saltos de layout.

**Sin librerías nuevas** (nada de GSAP, Motion, Lottie ni Rive). Usa CSS y JavaScript en los `monetta-*.js`.

### Primera tanda: obligatoria para el demo

| # | Qué hacer en la web | Parámetros y reglas |
|---|---|---|
| 09 | **Logo escrito en la bienvenida** (`monetta-guia-welcome`) | **Variante A:** siete máscaras (`clip-path: inset(...)`) sobre el PNG original, ajustadas a mano midiendo `monetta-logo-3x.png`. La gota ornamental pertenece a la M. Tiempos: M 0–220 ms; O 220–350; N 350–480; E 480–610; T 610–740; T 740–870; A 870–1000. La caja tiene su tamaño final desde el inicio. Sin cursor, bucle, rebote ni salida. **Una vez por sesión:** `sessionStorage`, con try/catch; si falla, se muestra estático. **«COMENZAR» funciona desde el primer frame**, y tocarlo termina la animación. Con movimiento reducido o sin JavaScript, el logo aparece completo. Agrega un ajuste a la sección, `logo_animation: letras / estático`, para comparar A con C desde el editor. La variante B (trazo) solo si queda fiel; Shop es su único precedente. El layout de contraseña no carga las hojas de Monetta: los estilos van en la sección o en un asset propio, con su propia regla de movimiento reducido. |
| 01 · 13 | **Agregar a la bolsa** | Mientras la petición está en curso, el botón muestra «Agregando…» con el `spin` existente y `aria-busy`. Solo durante la espera real, sin espera mínima; un doble clic no duplica la petición. El ancho del botón no cambia. Al terminar, abre la hoja «En tu bolsa» (lo que ya existe) con el anuncio. Hay precedente en HBX y Moda Operandi para la espera en el botón, y en FARFETCH, Zara y Zalando para la hoja. Si hay error, el mensaje va junto al control, no en un aviso flotante, siempre que se pueda. |
| 02 | **Hoja «En tu bolsa»** | Entrada y salida de 280 ms, un solo fondo atenuado y la página de atrás quieta. El foco se queda dentro; Esc y Cerrar devuelven el foco al botón que la abrió. Revisa el resaltado de 1,6 s: déjalo o acórtalo a ≤1,2 s, sin que se repita. |
| 03 | **Panel de filtros** | El mismo contrato de 280 ms. No se animan las opciones ni los resultados. El texto con el conteo se actualiza. Se conservan las selecciones. |
| 04 | **Galería de producto** | El deslizamiento (scroll-snap) sigue al dedo y el indicador (puntos o segmentos) se actualiza. La imagen nueva aparece con un fundido de ≤280 ms solo cuando ya está decodificada (`img.decode()`), y la anterior se conserva mientras tanto. Sin autoplay, parallax ni 3D. |
| 06 | **Cambio de variante** | El borde de la muestra de color aparece de inmediato. Fundido opcional de 180 ms en la foto principal. El precio no se anima. Una respuesta tardía nunca sustituye a la selección vigente. |

### Condicionados: si salen limpios y baratos

- **#05 zoom de la foto.** Hoy no existe. Solo si da tiempo: visor de 180–280 ms, Cerrar siempre visible y regreso a la misma foto. Si no, se queda estático; no hay precedente comercial móvil observado.
- **#07 presión de botón.** Primero aprovecha el cambio de color que ya existe. Una escala de 0,985 a 1 en 180 ms, solo si una prueba muestra que no basta.
- **#08 check de filtro:** estático.
- **#10 plegables:**
  - El chevron gira en 180 ms.
  - La altura se anima (≤200 ms, con `::details-content` e `interpolate-size` como mejora progresiva) **solo en secciones cortas**, como envío o medidas.
  - Los textos largos aparecen de inmediato.
- **#11 navegación:** estática.
- **#12 quitar de la bolsa:** la fila se desvanece en 180 ms y la lista se reacomoda. «Deshacer» solo si es una operación real del carrito; si no, retiro inmediato con anuncio.
- **#14 errores** (por ejemplo, de stock): junto al control y persistentes.
- **#15 copiar:** si existe algo que copiar, «Copiado» en el mismo lugar.
- **#16 menú lateral:** 280 ms, sin escalonar los enlaces.
- **#17 favoritos:** ya existen en tarjetas y cabecera. El corazón se rellena de inmediato y, como mucho, con un fundido de 180 ms. **Sin rebote.**

### Descartados: verificar que no aparezcan

- **#18:** texto escalonado.
- **#19:** deslizar para eliminar.
- **#20:** producto que vuela al carrito. **El `fly-to-cart.js` de Atelier nunca debe ejecutarse en las plantillas de Monetta.** Comprueba también que ninguna página con `theme.liquid` lo dispare.

### Movimiento que ya existe y hay que auditar

- **Reveals al hacer scroll** (`[data-reveal]` a 480 ms y `.section.reveal` a 600 ms):
  - Nunca esconden precios, cuadrículas de producto ni botones; solo bloques editoriales debajo del primer viewport.
  - Se ajustan a los tokens: `--dur-settle` y ≤8 px de desplazamiento.
  - Se disparan antes de entrar en pantalla (`rootMargin`), para que en el video no aparezcan huecos al desplazarse rápido.
  - Si la persona prefiere quitarlos, se quitan. El inicio del 22 de octubre los incluyó con su visto bueno, así que pregunta antes.
- **Reposo:**
  - A los 10 s sin interacción, `document.getAnimations()` no debe tener nada decorativo en marcha en bienvenida, inicio, colección, producto ni carrito.
  - Sin autoplay, marquesinas ni Ken Burns.
- **Transiciones entre páginas:** `@view-transition` con un fundido de 280 ms imitaría la transición de rutas de la app. **Es opcional**, solo con el visto bueno de la persona y como mejora progresiva.

## 4. UX/UI lista para el demo

**Guion** (una tarea completa, de 60 a 90 s, en teléfono a 390 × 844 y en escritorio a 1440 × 900):

1. Bienvenida: el logo se escribe y se toca «COMENZAR». La contraseña la escribe la persona, fuera de cuadro.
2. Inicio.
3. Búsqueda predictiva de «crossbody».
4. Colección con un filtro de color.
5. Producto: deslizar fotos, elegir variante y abrir un plegable.
6. Guardar en favoritos.
7. Agregar: «Agregando…» y luego «En tu bolsa».
8. Carrito: cambiar la cantidad.
9. Ir al checkout de Shopify. **Detenerse ahí: sin pagar ni crear pedidos.**

**Contenido del recorrido:**

- Elige con la persona de 3 a 5 productos protagonistas, con fotos reales, variantes con stock y nombres y precios correctos (`$1,299.00 MXN`).
- No debe haber placeholders, textos en inglés que se escapen (`monetta-store-lang`), productos de prueba visibles ni colecciones vacías.
- **No edites el catálogo ni el admin sin autorización.** Si falta contenido, entrega la lista a la persona.

**Pulido visual:**

- Cero saltos de layout en el recorrido.
- Fuentes listas antes de pintarse, sin destello de fuente cambiada.
- Imágenes con dimensiones fijas.
- Foco visible solo con teclado (`:focus-visible`).
- Estados hover coherentes.
- Radios y espacios de los tokens.
- Contraste según `build.mjs --check`.
- Objetivos táctiles de ≥48 px.
- Áreas seguras en iPhone.
- Sin desplazamiento horizontal entre 320 y 1440 px.
- Consola sin errores y ningún asset en 404.

**Rendimiento:**

- Las animaciones solo animan `transform` y `opacity`.
- Un trace de rendimiento del recorrido en escritorio. En iPhone Safari también, si hay dispositivo, sin cuadros perdidos visibles.

**Condiciones de grabación** (documéntalas, no las fuerces en el tema):

- Cómo ocultar la barra de vista previa de Shopify (verifica si `pb=0` funciona) o usar el proxy de `theme dev`.
- Navegador al 100 %.
- Carrito vacío al empezar cada toma.
- Caché caliente.

**Ensayo:** graba el guion con Playwright (`recordVideo`) a 390 y 1440, con una captura por paso. Es un ensayo para revisar, no el video final. Guárdalo fuera de git.

## 5. Fases

Haz un commit local por fase. **Sin push ni PR, salvo que se pida.**

1. **F0 · Preparación.**
   - Worktree desde `origin/main` actualizado: `.claude/worktrees/web-animaciones-demo`, rama `feat/web-animaciones-demo`.
   - `shopify theme list` (solo lectura) y la pregunta de la base (sección 7).
   - Respaldo de solo lectura del remoto (tgz más manifiesto).
   - Con autorización, `shopify theme duplicate` de la base como «Monetta animaciones demo borrador sin publicar 2026-10-28». Debe ser la única escritura en la tienda.
   - `THEME.env` apuntando al duplicado.
   - Comprobación de `theme-push.sh`: OK con el duplicado, y control negativo con el tema `live`.
   - Capturas y `validate.sh` de línea base.
2. **F1 · Inventario.** `MOTION_AUDIT.md`: cada transición o animación del tema, con archivo:línea, disparador, duración, curva y decisión según la V2. Luego, cada candidato de la sección 3 mapeado al código.
3. **F2 · Logo de bienvenida.** Pruebas primero: una vez por sesión; «COMENZAR» operable en t=0; el último frame es idéntico al logo estático; estático con movimiento reducido.
4. **F3 · Agregar, bolsa, espera y error.** Pruebas: una sola petición por acción; `aria-busy` solo durante la espera; foco en la hoja; error junto al control.
5. **F4 · Galería y variante** (y zoom, si aplica).
6. **F5 · Filtros, menú, plegables, favoritos y quitar.**
7. **F6 · Auditoría de lo existente:** reveals, `fly-to-cart` y reposo de 10 s.
8. **F7 · Pulido para el demo:** contenido, aspecto visual y rendimiento.
9. **F8 · Validación completa:**
   - `validate.sh` con todas las fases.
   - axe sin nuevos hallazgos serios.
   - Theme Check con **0 hallazgos nuevos** contra la línea base.
   - `build.mjs --check`, `port-css --check` y `check_no_secrets.sh`.
   - `node --check` de cada JS tocado.
   - Pasada con movimiento reducido emulado.
   - Comprobación de reposo.
   - Chrome y Safari de escritorio, más iPhone Safari si hay dispositivo.
   - Subida protegida con `theme-push.sh`.
   - `compare-remote.mjs` con cero diferencias de contenido.
   - El ensayo grabado.
10. **F9 · Entrega:** el enlace de vista previa y la petición explícita de decisión para publicar.

Extiende el arnés de Playwright existente con comprobaciones de movimiento:

- duraciones vía `getComputedStyle`;
- `prefers-reduced-motion` emulado;
- `document.getAnimations()` vacío en reposo;
- el logo una sola vez por sesión;
- un doble clic en «Agregar» produce una sola petición;
- una respuesta tardía de variante no cambia la foto.

## 6. Reglas técnicas

- **CSS generado.** `monetta-pages.css` y las demás hojas portadas se generan con `port-css`: **no las edites a mano**. El CSS nuevo va en una hoja aparte, por ejemplo `assets/monetta-motion.css`, cargada después, igual que `monetta-home-22oct.css`. Comprueba que `port-css --check` siga en verde.
- **Tokens.** Usa `--dur-snap`, `--dur-swap`, `--dur-settle` y `--ease`. No metas números sueltos sin justificarlo en `MOTION_AUDIT.md`.
- **Movimiento reducido** en los dos layouts, `monetta.liquid` y `password.liquid`.
- **Sin animación como única fuente de información.** Los estados se anuncian (`Monetta.announce`) y tienen texto.
- **Textos de interfaz en español de México.**

## 7. Preguntas para la persona (antes de F2)

1. ¿Qué tema es la base: el que hoy está `live` en staging o el borrador del buscador predictivo, `192576585762`, ya validado?
2. Para agregar a la bolsa, ¿B (abre la hoja; recomendado, porque ya existe y tiene precedente) o A (confirmación en el botón, con la bolsa a voluntad)? El demo usa una sola.
3. ¿Se conservan los reveals del inicio, ajustados a los tokens, o se quitan?
4. ¿Transiciones entre páginas (`@view-transition`): sí o no?
5. ¿Qué 3 a 5 productos protagonizan el demo?
6. ¿El video final se graba en un iPhone real, en escritorio o en ambos?
7. Tras revisar el ensayo, ¿se publica el duplicado en staging?

## 8. Límites

- **Nunca** tocar la tienda de producción. **Nunca publicar** sin autorización explícita. Toda subida pasa por `theme-push.sh` a un duplicado `unpublished`.
- **Nunca pedir ni imprimir la contraseña de la tienda.** La persona la escribe en su Terminal al arrancar `start-theme-dev.command` del worktree.
- Sin escrituras en el admin ni en el catálogo, y sin pagos ni pedidos, salvo autorización.
- Sin secretos en git. Las evidencias con fotos de la dueña van fuera de git, porque el repositorio es público.
- Sin dependencias nuevas. Sin push ni PR, salvo que se pida.
- No implementar los descartados (#18–#20) ni sumar efectos fuera de la V2. Si algo nuevo parece necesario, propónlo con su evidencia (nivel N1–N6) y espera el visto bueno.

## 9. Entregables

- Los cambios del tema en `feat/web-animaciones-demo`, con un commit local por fase.
- El duplicado sin publicar con los cambios y su enlace `?preview_theme_id=…`.
- En `docs/web-redesign/shopify-staging/animaciones-demo/`:
  - `RESULTADO.md`: una entrada por fase, decisiones, comprobaciones antes y después, y pendientes.
  - `MOTION_AUDIT.md`.
  - `DEMO_GUION.md`: tomas con tiempos, URLs, tamaños, qué animación aparece en cada momento, cómo reiniciar el estado y condiciones de grabación.
  - La lista de contenido faltante, si la hay.
- Los videos de ensayo y las capturas, en una carpeta de evidencia excluida de git.

## 10. Criterios de aceptación

- **Trazabilidad.** Cada efecto implementado remite a un candidato de la V2, usa tokens y tiene equivalente con movimiento reducido. Ningún descartado aparece.
- **Logo:** una vez por sesión, ≈1000 ms, «COMENZAR» operable desde el inicio, último frame idéntico al estático, estático con movimiento reducido o sin JavaScript.
- **Agregar:** una petición por acción; espera visible solo mientras dura; la hoja se abre con foco; errores junto al control.
- **Reposo:** ninguna animación decorativa en marcha a los 10 s en ninguna pantalla del recorrido.
- **Calidad:** sin saltos de layout por animación, sin errores de consola en el recorrido y sin desplazamiento horizontal entre 320 y 1440 px.
- **Validación:** todas las comprobaciones de F8 en verde, o con cada excepción explicada y aceptada por la persona.
- **Ensayo:** muestra el recorrido completo a 390 y 1440 sin defectos visuales, y la persona lo revisó.
- **Publicación:** nada se publica sin su visto bueno.
