# Auditoría independiente de la entrega de fidelidad del 18 de octubre

**Objeto:** estado de `design-prototype/` y su documentación, con compuerta del autor terminada el 18/10/2026 a las 16:06:38 de Monterrey. Auditoría de lectura y ejecución; no se aplicaron correcciones. Entorno observado: Node 24.21.0, Vite 6.4.3 y Brave/Chromium 155 instalado.

## 1. Veredicto

| Elemento | Veredicto | Motivo |
| --- | --- | --- |
| H01 | **No corregido por completo** | La composición principal y las medidas declaradas a 375/440 son correctas; quedan problemas de encabezado/foco con título largo, semántica de búsqueda y protección lateral en horizontal. |
| H02 | **Corregido** | Orden de las cinco acciones, posiciones, iconos, objetivos de 48 px y centrado del logo confirmados en el navegador y contra `product_header.dart`. |
| H03 | **Corregido** | Inter 17/600/1,25, tarjetas 52vw, fotografía 4:5 sin inset, nombres de dos líneas y alturas iguales; Inicio conserva sus roles. Las adaptaciones grandes están documentadas. |
| D11 | **No justificado** | El cierre afirma ausencia de defectos materiales pendientes, pero hay foco oculto en un recorrido normal con teclado y fallos adicionales que los checks no cubren. Los 153 resultados aprobados son reales y su cobertura resulta insuficiente para ese cierre. |

No se identificó un Blocker general de compra o compilación. Hay una Alta y cinco Medias. No se atribuye automáticamente a esta ronda el origen de todos los defectos vigentes: no existe una línea base de los fuentes del 17 de octubre.

## 2. Hallazgos con reproducción

### GPT-01 · Alta · Defecto: el dock oculta enlaces que reciben foco por teclado

**Fuente:** `design-prototype/src/styles/components.css:727`, `:747`, `:825`; `src/styles/base.css:8`. El dock permanece fijo; el padding final del footer reserva espacio al final del documento, pero el scrollport no reserva el dock al desplazar cada enlace enfocado.

**Reproducción:** viewport 390×844, `/collections/guess`, Tab al enlace de saltar, Enter y continuar con Tab hasta los enlaces del pie. Con foco en “Novedades”, el enlace ocupa y=804,11–844,11; su centro (60,17;824,11) devuelve `.dock__item` en `document.elementFromPoint`, no el enlace. También se reprodujo con Envíos, Cambios y devoluciones y Mi cuenta. Se pulsaron teclas reales mediante Playwright; no se simuló la posición del foco con estilos.

**Evidencia:** [captura del foco oculto](/tmp/monetta-gpt-audit-20261018.UTOhgc/probes/footer-focus-covered.png), caso `keyboard-footer-hit-test` en [focused-results.json](/tmp/monetta-gpt-audit-20261018.UTOhgc/focused-results.json).

**Impacto:** un usuario de teclado pierde el texto y parte del indicador del control activo en la navegación habitual. Contradice D08/D09/D11; tener un outline calculado no demuestra que se vea.

**Corrección sugerida:** reservar el espacio inferior del control fijo en el scrollport o desplazar el elemento activo considerando los obstáculos reales; comprobar todo el recorrido, incluido el footer.

### GPT-02 · Media · Defecto: el fallback de la flecha interfiere con un Adelante válido

**Fuente:** `design-prototype/src/main.js:178`. El temporizador de 500 ms sobrevive a un `popstate` correcto y decide únicamente por igualdad de URL.

**Reproducción:** Inicio → Catálogo → primera ficha → flecha Volver → Adelante antes de 500 ms. En la ejecución, Volver terminó a los 37 ms; Adelante restauró la ficha a los 41 ms. A los 795 ms la URL ya era `/collections/carteras-1`, no la ficha solicitada: se ejecutó el fallback pendiente. La ficha era `/products/cartera-calvin-klein-negra-texturizada`.

**Evidencia:** caso `history:arrow-forward-race` en [independent-results.json](/tmp/monetta-gpt-audit-20261018.UTOhgc/independent-results.json), reproducción automatizada en [independent-probes.mjs](/tmp/monetta-gpt-audit-20261018.UTOhgc/independent-probes.mjs).

**Impacto:** una segunda navegación legítima se deshace y se inserta una entrada adicional. El flujo pausado de la suite pasa; no ejercita este intervalo.

**Corrección sugerida:** cancelar o invalidar el fallback al recibir el `popstate` esperado o iniciar otra navegación, vinculándolo a la operación/entrada de historial y no solo a la URL.

### GPT-03 · Media · Defecto: búsqueda sin encabezado principal accesible en dos estados

**Fuente:** `design-prototype/src/pages/search.js:37`, `:78`, `:107`; `src/components/ui.js:117`. Si hay query, la barra usa un `p`. El error genera un `h2`; al mostrar sugerencias se oculta el bloque que contiene el único `h1`.

**Reproducción A:** `/search?q=bolsa&type=product` → Detalles → activar error de resultados → Esc → recargar. `document.querySelectorAll('main h1').length === 0`.

**Reproducción B:** en esa búsqueda sin el fallo activo, escribir `tote` y esperar las sugerencias. Hay un `h1` en el DOM, pero su contenedor está `hidden`: ninguno se expone como encabezado principal. Esc no cambia este hecho mientras el texto editado y la query de la página difieren.

**Evidencia:** [error](/tmp/monetta-gpt-audit-20261018.UTOhgc/probes/search-error.png), [sugerencias](/tmp/monetta-gpt-audit-20261018.UTOhgc/probes/search-suggestions.png). Axe con los mismos tags del proyecto devuelve **`page-has-heading-one`, impacto `moderate`**, en ambos casos: [focused-results.json](/tmp/monetta-gpt-audit-20261018.UTOhgc/focused-results.json).

**Impacto:** incumple la especificación de un `h1` por página y la orientación semántica de la búsqueda. No se presenta esta regla best-practice como una infracción WCAG automática.

**Corrección sugerida:** conservar un encabezado principal accesible para el estado realmente activo y comprobar error y sugerencias con axe, además de resultados normales.

### GPT-04 · Media · Defecto: la reserva del encabezado no crece con el título

**Fuente:** `design-prototype/src/styles/components.css:938`; `verify/check-fidelity.mjs:127`. El componente crece, pero `scroll-padding-top` permanece en 28+76+16 = 120 px.

**Reproducción:** a 320×812 abrir `/collections/tommy-hilfiger`, desplazar hacia abajo y ejecutar `scrollIntoView({block:'nearest',behavior:'instant'})` sobre la cuarta tarjeta, con su enlace enfocado. Es la misma forma de alineación que usa el check D11 del autor, con un título de dos líneas.

**Medición:** barra de 97,3125 px; borde inferior en y=125,3125; reserva de 120 px; enlace alineado en y=120,25. Sus **5,0625 px superiores quedan cubiertos**. La prueba de teclado inicial sobre la primera tarjeta no mostró este problema; la variante con alineación nearest sí lo demuestra.

**Evidencia:** [captura](/tmp/monetta-gpt-audit-20261018.UTOhgc/probes/long-title-anchor-overlap.png), caso `long-title-anchor-reserve` en [focused-results.json](/tmp/monetta-gpt-audit-20261018.UTOhgc/focused-results.json).

**Impacto:** refuta la afirmación de que el foco y las anclas nunca quedan bajo la barra. Los checks solo usan Bolsas, de una línea, a 375/390/440.

**Corrección sugerida:** calcular la reserva con la altura real del encabezado y añadir esta variante de título largo a su comprobación.

### GPT-05 · Media · Defecto: el reflow al 400 % deja casi todo el contenido bajo barras fijas

**Fuente:** `design-prototype/src/styles/components.css:727`, `:917`; `verify/check-layout.mjs:129`. Los controles dependen del ancho, sin adaptación a la escasa altura.

**Reproducción:** viewport CSS 320×200, equivalente geométrico de 1280×800 al 400 %, colección desplazada. La barra termina en y=104 y el dock comienza en y=118: quedan **14 px libres de contenido**. Con 360×225 —1440×900 al 400 %— quedan 39 px. A 640×400 —200 % de 1280×800— quedan 214 px.

**Evidencia:** [320×200](/tmp/monetta-gpt-audit-20261018.UTOhgc/probes/reflow-400-320x200.png), [zoom-results.json](/tmp/monetta-gpt-audit-20261018.UTOhgc/zoom-results.json). No se confunde esta emulación de reflow con haber operado el control nativo de zoom del navegador.

**Impacto:** no hay overflow horizontal, pero casi no se puede inspeccionar el producto entre los controles. La prueba del autor a 320×640 no cubre una ventana de escritorio habitual reducida también en altura.

**Corrección sugerida:** en alturas reducidas, hacer que uno de los controles pase al flujo normal o deje de ocupar permanentemente el viewport; comprobar ancho y altura del reflow conjuntamente.

### GPT-06 · Media · Riesgo demostrado en emulación: no se respetan los insets laterales

**Fuente:** `design-prototype/src/styles/components.css:1476`, `src/styles/tokens.css:108`; referencia Flutter `lib/features/catalog/product_card.dart:173` (`SliverSafeArea`). El prototipo solo consume el inset inferior.

**Reproducción:** a 667×375, CDP `Emulation.setSafeAreaInsetsOverride` con left=44 y right=44. Un elemento de medición confirma `env(safe-area-inset-left/right) = 44px`. La cuadrícula conserva padding=0, primera tarjeta x=0 y ancho=327,5 px. La región segura sería x=44…623; su equivalente de dos columnas con separación 12 tendría 283,5 px por tarjeta.

**Evidencia:** caso `safe-area-horizontal` en [focused-results.json](/tmp/monetta-gpt-audit-20261018.UTOhgc/focused-results.json), [captura](/tmp/monetta-gpt-audit-20261018.UTOhgc/probes/safe-area-landscape.png). La captura no dibuja una muesca física; demuestra por medición que los insets emulados se ignoran.

**Impacto:** la equivalencia con la cuadrícula Flutter no incluye su protección lateral en horizontal; controles y contenido pueden ocupar la zona insegura. No se afirma haberlo probado en un dispositivo real.

**Corrección sugerida:** consumir los insets izquierdo/derecho y calcular el ancho disponible con ellos; conservar esta emulación como comprobación.

## 3. Afirmaciones del autor

| Afirmación | Resultado | Evidencia independiente |
| --- | --- | --- |
| Colección: primera tarjeta a 140,8 px bajo el aviso, a 375 y 440 | Confirmada | y=168,796875; aviso=28. Barra=76. Diferencia de 52,8 frente a Flutter justificada por atajos. |
| Anchos de tarjeta 181,5 / 214 | Confirmada | Navegador: 181,5 / 214, x=0; separación=12. Reservas sobre safe area: GPT-06. |
| Búsqueda: primera tarjeta a 206 px | Confirmada | 375, 390 y 440: y=234. A 320 son 230,14 bajo aviso, por wrap; no se extendió indebidamente la cifra de 206 a ese caso. |
| Bolsa: una barra de 76, Playfair 28 y contador 12 | Confirmada | DOM y capturas. La línea existe desde el inicio; el borde web es 1 px, frente al borde de 0,5 del `_BagLineTile` nativo. Diferencia menor de acabado. |
| Ficha: cinco controles, inset=4, objetivos=48, iconos=20/22/23 | Confirmada | A 375: x=4 / 52 / 145,8125 / 275 / 323; cuatro acciones de 48×48; logo con centro 187,4922 frente a 187,5. A 440: centro 219,9922 frente a 220. |
| Recomendaciones Inter 17/600/1,25; 195/228,8 px; ratio 0,8; dos líneas; alturas iguales | Confirmada | Medidas independientes y comprobaciones D11 reproducidas; 20/22 en pantallas grandes y cinco tarjetas a 1440. |
| Inicio permanece igual | Confirmada | Medidas y capturas coinciden; Novedades Playfair 24/400, tarjeta compacta de 135 a 375. |
| Tablet/escritorio conservados | Confirmada fuera de la adaptación H03 | Ocho JPEG a 768/1440 son idénticos entre auditoría previa y entrega; los dos de ficha cambian y sus métricas lo sitúan en recomendaciones/Reseñas, cambios declarados. |
| `npm test` 31/31; verificación 153/153 | Confirmada | Reejecución: 31/31 y 153/153; esta última tardó 173 s, frente a 170 del autor. |
| D11: 25+6+10=41 casos; seis pruebas unitarias nuevas | Confirmada | Clasificación de resultados por H01/H02/H03; 112 nombres/gates previos conservados. |
| 26 capturas de fidelidad y 58 estándar, sin errores ni overflow | Confirmada para esos sets | Reejecuciones con `--out` externo; 26 métricas idénticas a las del autor; índice de 58 con cero problemas/overflow. |
| Foco siempre visible y libre de barras | Refutada | GPT-01, GPT-04 y GPT-05. |
| Un encabezado principal por estado | Refutada | GPT-03 y axe en estados adicionales. |
| La flecha respeta el historial sin interferir | Refutada en el intervalo demostrado | GPT-02; el recorrido pausado y la recarga tras filtro sí pasan. |
| Originales intactos y alcance preservado durante esta auditoría | Confirmada | Rehash de 258 archivos protegidos, 762 revisados, cero cambios de contenido; status y HEAD iguales al inicio. Solo se añade este informe. |
| Atribución completa de todos los cambios a la ronda del autor / ausencia histórica de push | No verificable completamente | Fuentes sin seguimiento y sin manifiesto anterior a sus cambios. HEAD actual `c828d68` es del 14/10. No se observó un commit nuevo; eso no certifica operaciones remotas históricas. |

### Calidad de pruebas y documentación

- Las mutaciones prueban sensibilidad real: mostrar el encabezado global anterior causa **12 fallos D11**; restaurar Playfair 24/400 en las recomendaciones causa **4 fallos D11**. Ambas ejecuciones terminan con exit 1, como corresponde. Las copias están fuera del repositorio.
- No son checks vacíos en conjunto. Hay, sin embargo, límites concretos: el presupuesto de cromo se deriva de las propias cajas web; la altura del encabezado no se fija directamente en ese caso. Los objetivos se aceptan desde 44 px aunque Flutter y el contrato dicen 48. El check de foco usa `scrollIntoView` y no un recorrido completo con Tab; el recorrido de historial omite el temporizador activo y la navegación posterior. Hay esperas fijas de 250/350 ms sensibles al tiempo de ejecución.
- Las seis unitarias prueban estados puros razonables, pero no el listener, `popstate`, el temporizador, una recarga ni una pestaña duplicada. Los casos de regresión anteriores no quedan demostrados por esas unitarias.
- Los 112 casos previos tienen los mismos nombres/gates que el informe del 17 y pasan. Identity/layout/journeys/a11y/report/browser y el lockfile conservan fechas del 17; no se vio un `skip` nuevo ni una anulación de fallos. Sin baseline de fuentes no se afirma identidad histórica criptográfica de esos archivos.
- El scanner axe existente solo rechaza impactos `critical`/`serious` y sus 33 estados no incluyen error de resultados ni sugerencias inline móviles. Sus cero hallazgos en esos 33 estados son reproducibles; no significan cero hallazgos en todos los estados.
- Las cifras vigentes y los enlaces Markdown locales de RESULTADO, STATUS, DESIGN_SPEC, VERIFICATION, IMPLEMENTATION_HANDOFF, FINAL_REPORT y README son consistentes. Los números 112/25/56 están marcados como históricos. Las afirmaciones absolutas de foco y el cierre D11 deben reconsiderarse por los hallazgos anteriores.
- Las decisiones de atajos, búsqueda en colección, contadores, corazones/descuentos, títulos Inter, cinco tarjetas grandes y vistas restantes con header global están declaradas. No se califican como defectos por diferir de Flutter. La columna única bajo 360 también está documentada; Flutter usa 340 como umbral. Esta diferencia no se contó como defecto independiente.

## 4. Comandos y resultados reales

Directorio de ejecución de los comandos principales: `/Users/alexis_reyna/MyCode/Monetta/design-prototype`. Evidencia de esta auditoría: `/tmp/monetta-gpt-audit-20261018.UTOhgc/`.

| Comando / operación | Resultado |
| --- | --- |
| `git status --short` | Los diez archivos modificados y los directorios sin seguimiento declarados. Sin cambios durante la auditoría. |
| `find src verify tests package.json -type f -newer ../docs/web-redesign/fidelity-2026-10-18/evidence/verify-report.json` | Exit 0, salida vacía. Ningún fuente/test/script posterior al gate. |
| `npm test` | Exit 0, 31 aprobadas; [log](/tmp/monetta-gpt-audit-20261018.UTOhgc/npm-test.log). |
| `npm run build` | Exit 0; CSS 66,07 kB, JS 271,36 kB; [log](/tmp/monetta-gpt-audit-20261018.UTOhgc/npm-build.log). |
| `npm run verify -- --skip-build --port=4311 --out=/tmp/monetta-gpt-audit-20261018.UTOhgc/verify` | Exit 0, 153/153 en 173 s; [JSON](/tmp/monetta-gpt-audit-20261018.UTOhgc/verify/verify-report.json). |
| `npm run capture:fidelity -- --skip-build --port=4312 --out=/tmp/monetta-gpt-audit-20261018.UTOhgc/fidelity` | Exit 0, 26 capturas; [log](/tmp/monetta-gpt-audit-20261018.UTOhgc/capture-fidelity.log). |
| `npm run capture -- --skip-build --port=4313 --out=/tmp/monetta-gpt-audit-20261018.UTOhgc/screenshots` | Exit 0, 58 capturas; [índice](/tmp/monetta-gpt-audit-20261018.UTOhgc/screenshots/index.json). |
| `node node_modules/vite/bin/vite.js preview --host 127.0.0.1 --port 4314 --strictPort` | Servidor local utilizado por los probes propios; no se intervino el 5173. |
| `node /tmp/monetta-gpt-audit-20261018.UTOhgc/independent-probes.mjs` | Exit 0, 67 casos registrados; 50 celdas principales, navegación y estados adicionales; cero errores de ejecución y cero peticiones externas. |
| `node /tmp/monetta-gpt-audit-20261018.UTOhgc/focused-probes.mjs` | Exit 0; foco/footer, anclas, safe area, umbral de cuadrícula y axe. Los defectos se registran como datos, no como falsos tests aprobados. |
| `node /tmp/monetta-gpt-audit-20261018.UTOhgc/zoom-and-controls.mjs` | Exit 0; tres reflows y teclado de filtros en tablet; Tab/Shift+Tab atrapados, Esc restaura el botón visible. |
| Mutación `old-header`: `npm run verify -- --only=fidelity --port=4321 --out=.../report` en su copia temporal | **Exit 1 esperado**: D11 29/41, total 30/42; error ejemplo `global header still visible`, primera tarjeta 201,796875 frente a presupuesto 140,796875. |
| Mutación `old-recommendation-heading`: mismo comando con puerto 4322 en su copia | **Exit 1 esperado**: D11 37/41, total 38/42; error ejemplo `#product-more` Playfair 24/400. |
| Comparación de hashes/índices/enlaces | Cero cambios protegidos, cero enlaces Markdown locales rotos, métricas reproducidas sin diferencias. [Integridad](/tmp/monetta-gpt-audit-20261018.UTOhgc/integrity-result.json). |

Las mutaciones consisten en añadir CSS solo a las copias: `body.has-page-bar .site-header{display:block!important}` dentro de la media query de teléfono, y `.product-section-title{font-family:var(--font-serif)!important;font-size:24px!important;font-weight:400!important}` respectivamente. Se construyó cada copia antes de verificarla; no se verificó un dist anterior.

Los probes propios requieren arrancar primero el servidor 4314 del comando anterior. Miden 320, 360, 375, 390, 440, 667×375, 812×375, 768, 1024 y 1440; se abrieron imágenes de los pares Flutter/web y de los fallos. No se instaló un navegador ni se ejecutó `fixtures`.

## 5. Integridad y límites de lo verificable

- SHA-256 del prompt original confirmado: `0a7ac81dd3910114805770dab2ce130e7dab06cfc20d40fb32f692d79d3124ed`. El valor de la petición venía truncado; se usó el valor completo de la evidencia previa y se calculó de nuevo.
- La carpeta de auditoría previa conserva mtime de directorio 18/10 14:53:08; el set de capturas original, 17/10 22:30:48. Sus contenidos se hashearon al inicio y al final, sin diferencias. Esos metadatos apoyan su preservación por el autor, pero no sustituyen un manifiesto anterior a su ronda.
- Prototipo, pruebas, documentación previa, Flutter, backend, `.claude/` y prompts no se editaron. El build regeneró únicamente `dist/`, salida generada que los comandos solicitados requieren. Las mutaciones y capturas nuevas están en `/tmp`; este es el único archivo nuevo escrito al repositorio.
- No se observó tráfico externo del prototipo en los recorridos instrumentados; no se hicieron escrituras en Shopify ni operaciones de git de modificación.
- No se operó la función nativa de duplicar pestaña o el control nativo de zoom del navegador. La recarga después de filtrar se probó; el zoom se evaluó mediante los viewports CSS equivalentes indicados. No se presenta ninguna de esas simulaciones como observación de una función nativa que no se operó.
- Sin línea base de los fuentes sin seguimiento, no se puede certificar la lista histórica completa de cambios ni atribuir cada defecto al 18 de octubre. Tampoco se puede probar una ausencia histórica de push o escrituras externas solo con el estado local. No se extendió la auditoría a las áreas excluidas por el usuario.

La evidencia de `/tmp` es temporal. Este informe conserva comandos, medidas, errores y ubicaciones de reproducción, además de los resultados resumidos.
