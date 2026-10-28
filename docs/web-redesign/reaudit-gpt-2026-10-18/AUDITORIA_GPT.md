# Reauditoría independiente — correcciones de Claude, 18 de octubre de 2026

Trabajo ejecutado en `/Users/alexis_reyna/MyCode/Monetta`, después de la entrega de
`correcciones-auditoria-gpt-2026-10-18/`. Auditoría sin correcciones al prototipo.
Entorno: Node 24.21.0, Vite 6.4.3, Playwright Core 1.63.0 y Brave/Chromium 155.0.8059.40 instalado.

La entrega resuelve las reproducciones originales y sus cifras principales se sostienen.
Queda un caso de poca altura fuera de la solución y un problema de foco/contraste en la
navegación de tablet. **No doy D11 por cerrado sin pendientes.** Son dos defectos de severidad
media; no encontré un Blocker ni una Alta en el alcance ejecutado. Ambos existían en la base:
no son regresiones introducidas por estas correcciones.

## 1. Veredicto

| Punto | Veredicto | Evidencia independiente |
| --- | --- | --- |
| GPT-01, foco bajo el dock | **Corregido** | Tab real: 19 enlaces/controles del pie en cada una de las cinco páginas, 95 paradas, sin centro tapado. Las pruebas completas añaden inspección del anillo y píxeles. Abrí las capturas del foco. |
| GPT-02, fallback de navegación | **Corregido** | Inicio → Catálogo → ficha → flecha → Adelante: la ficha se restauró a los 88 ms y seguía ahí a los 843 ms. La suite pasa los casos 0/150/450/700 ms, filtros y recarga. El contador invalida el fallback al navegar o recibir `popstate`. |
| GPT-03, búsqueda sin encabezado accesible | **Corregido** | Consulté `Accessibility.getFullAXTree`: exactamente un encabezado de nivel 1 en cinco estados × dos anchos (390/1440). Axe no encuentra violaciones en las reproducciones de error y sugerencias. El `<p role="heading" aria-level="1">` está expuesto correctamente. |
| GPT-04, reserva superior fija | **Corregido** | Tommy Hilfiger, 320×812: barra 97,3125 px, borde inferior 125,3125, reserva 141,31. La reproducción anterior con `nearest` deja el enlace en y=141,25, solape 0. La suite verifica también Shift+Tab, anclas, fuente tardía y resize. |
| GPT-05, poca altura | **Parcial** | Pasan los seis viewports declarados y los controles siguen funcionando. A 1024×200 reaparece el problema: quedan sólo 54 px para contenido. Véase RE-01. |
| GPT-06, insets laterales | **Corregido en emulación CDP** | 667×375, insets 44/44: primera tarjeta x=44, ancho 283,5. Pasan los barridos y paneles en 667 y 812. No equivale a una prueba en dispositivo físico. |
| A1, rieles/chips/miniaturas con teclado | **Confirmado para los escenarios móviles** | Los dos controles A1 pasan. La fila de categorías de tablet que también contempla el nuevo código conserva el defecto RE-02. |
| H01 / H02 / H03 originales | **Se conserva la corrección visual principal** | Colección: 140,80 px bajo el aviso; tarjetas 181,5/214 a 375/440. Ficha: cinco controles y logo centrado. Recomendaciones: Inter 17/600, 195/228,80 px y foto 4:5. Las 26 mediciones de fidelidad coinciden exactamente con la entrega. |
| D11 | **No justificado como cierre sin pendientes** | El gate original exige que no quede un defecto material de layout o accesibilidad. RE-01 conserva el contenido comprimido y RE-02 afecta el enlace enfocado en tablet; la batería no incluye esas condiciones. |

No reabro las diferencias deliberadas ya documentadas: atajos de estilo, contadores públicos,
corazones/descuentos, encabezados de resultados, adaptación de escritorio y otras vistas interiores.

## 2. Hallazgos, por severidad

### RE-01 — Media · defecto · la corrección de poca altura termina en 1024 px

**Fuente:** `design-prototype/src/styles/pages.css:1713`; cobertura:
`design-prototype/verify/check-audit-fixes.mjs:607`.

**Reproducción:** abrir `/collections/guess` con viewport CSS **1024×200**, desplazar 800 px.
`#site-top` sigue `sticky`, su borde inferior queda en **146 px** y la reserva superior es
**162 px**: sólo **54 de 200 px** quedan para los productos. En **1023×200**, un píxel menos
de ancho, la cabecera es `static`, se va de pantalla y quedan los **200 px**.
Abrí las dos imágenes: en 1024 la cabecera ocupa el 73 % de la ventana y sólo asoman trozos
de las fotografías. Esto es una medición de viewport, no una ejecución del zoom nativo.

**Causa:** la regla de poca altura incorpora `max-width: 1023.98px`. El comentario afirma que
desde 1024 la cabecera ocupa una fracción pequeña de cualquier ventana baja, pero la medición
lo contradice. Las seis geometrías ensayadas tienen menos de 1024 px de ancho, por lo que el
control GPT-05 pasa sin atravesar el límite que introduce la solución.

**Impacto:** persiste el problema de lectura y navegación del catálogo en ventanas anchas y
bajas. Es un caso límite de la misma clase que GPT-05, existente en la base y no cubierto por
la entrega.

**Corrección sugerida:** resolver la reserva por altura también desde 1024, contemplando las
columnas `sticky` de escritorio. Añadir una comprobación a ambos lados del límite de ancho.

Evidencia:
[captura 1024×200](/var/folders/vp/1zm3yfq11_7bbzm2_t195l2r0000gn/T/monetta-gpt-reaudit-20261018.q5ejmyw9/probes/short-desktop-1024.png),
[control 1023×200](/var/folders/vp/1zm3yfq11_7bbzm2_t195l2r0000gn/T/monetta-gpt-reaudit-20261018.q5ejmyw9/probes/short-desktop-1023.png),
`extra-results.json`, casos `short-desktop-1023` y `short-desktop-1024`.

### RE-02 — Media · defecto y cobertura incompleta · el último enlace de tablet sigue bajo el degradado

**Fuente:** `design-prototype/src/styles/components.css:230` y `:246`;
`design-prototype/src/lib/scrollers.js:16`; pruebas A1 en
`design-prototype/verify/check-audit-fixes.mjs:156`.

**Reproducción:** Inicio, **768×1024**, Tab sin activar el enlace de salto hasta
**“Nuestra historia”** en la fila de categorías. El desplazamiento llega a su máximo
**249 px**. El texto ocupa x=**630,27…736,42**; el degradado empieza en **675,84**.
Más de 60 px del texto quedan dentro del desvanecimiento y el borde derecho del foco se
desvanece. Las partes superior e inferior del anillo también quedan recortadas por el
scrollport de 44 px y el enlace de 44 px.

No es sólo una caja declarada en CSS: abrí la captura y comparé sus píxeles con una segunda
captura que únicamente desactiva la máscara en el DOM. En el píxel **(734,119)**, la tinta
pasa de **(17,17,17)** sin máscara a **(168,168,168)** con ella. En el extremo derecho de la
palabra encontré 37 píxeles de tinta oscura aclarados por encima de 125/255. A **812×1024**
ocurre lo mismo: máximo 205, degradado desde 714,56 y texto hasta 780,42.

**Causa:** `scroll-padding-inline: 12px 12%` no añade espacio desplazable al final. El cálculo
se limita a `maxScroll`, de modo que no puede sacar el último enlace de la máscara.
El nuevo módulo y el comentario CSS mencionan la fila de tablet, pero A1 sólo se ejecuta
a 320/390 y salta directamente al contenido. La sonda general tampoco detecta este caso:
el estilo `outline` existe y la lectura de píxeles sólo se hace en el pie; una máscara y el
recorte del propio scrollport no equivalen a una barra superpuesta en `elementFromPoint`.

**Impacto:** texto y señal de foco degradados en una navegación común con teclado en tablet.
Está presente en la base reconstruida y en la corregida: no lo atribuyo a una regresión nueva.

**Corrección sugerida:** retirar el degradado al llegar al final o proporcionar espacio real
para que el último enlace salga de él; conservar espacio para el anillo y probar Tab en la
navegación de tablet, sin usar el enlace de salto.

Evidencia:
[foco en tablet](/var/folders/vp/1zm3yfq11_7bbzm2_t195l2r0000gn/T/monetta-gpt-reaudit-20261018.q5ejmyw9/probes/tablet-last-after-768.png),
[control sin máscara](/var/folders/vp/1zm3yfq11_7bbzm2_t195l2r0000gn/T/monetta-gpt-reaudit-20261018.q5ejmyw9/probes/tablet-last-768-unmasked.png),
`extra-results.json` (`nav-last-before-*`, `nav-last-after-*`) y `nav-pixels.json`.

### RE-03 — Baja · observación de trazabilidad · la herramienta de capturas cambió después de la puerta

`find src verify tests package.json -type f -newer
../docs/web-redesign/correcciones-auditoria-gpt-2026-10-18/evidence/verify-report.json`
devuelve **`verify/capture-fidelity.mjs`**. El reporte terminó el 18/10 a **18:55:08** CST;
la herramienta se modificó a **19:54:44**, y sus métricas se regeneraron a **19:55:27**.

El cambio está declarado y se limita a enlaces relativos del comparador. **No refuta los
204 checks del producto.** Lo ejecuté de nuevo: 26 capturas, métricas idénticas y las
**42 imágenes** del comparador cargan en las 14 selecciones. Conviene distinguir la puerta
del producto de esta validación posterior de la herramienta, en vez de presentar una única
marca temporal como si cubriera todo el árbol final.

## 3. Contraste de las afirmaciones

| Afirmación | Estado | Evidencia |
| --- | --- | --- |
| `npm test` 49/49, sin reducir las anteriores | **Confirmada** | Ejecución nueva: 49 pass, 0 fail/skip. Se conservan las primeras seis pruebas de navegación y las suites anteriores. |
| Build correcto | **Confirmada** | Compilación nueva: CSS 68,12 kB y JS 274,30 kB; mismos tamaños declarados. |
| `verify` 204/204, D11 92/92 | **Confirmada** | Ejecución nueva: **204/204 en 437 s**, D11 92/92, problemas de consola/página/red 0. Los 424 s pertenecen a la ejecución anterior, no son una discrepancia. |
| 153 controles anteriores intactos + 51 | **Confirmada** | Los 153 pares gate/nombre siguen presentes. Suites anteriores y helpers `browser/report/capture`, además de paquete y dependencias, iguales a la base. Los 51 se reparten 12+8+3+8+11+7+2. |
| Base anterior: 10/51; corregida: 51/51 | **Confirmada** | Recompilé el `.tgz`, validé 59/59 hashes y repetí: **10/51, exit 1, 264 s**. La puerta completa actual da los 51/51. Además, 56 archivos del archivo coinciden con hashes de mi auditoría anterior. |
| Pruebas nuevas detectan defectos | **Confirmada para las mutaciones ejecutadas** | En copias temporales: reserva superior fija de 120 px falla por esperar 141,3125; reserva inferior 0 falla por esperar 106. Los mismos controles pasan en el código actual. No se ejecutaron otras comprobaciones dentro de esas dos ejecuciones seleccionadas. |
| 384 comparaciones, 378 idénticas | **Confirmada como cifra del JSON entregado; repetición parcial** | El JSON contiene 384 filas y 6 diferencias. Repetí **144 pares** (16 rutas × 3 anchos × 3 posiciones): **137 idénticos**, 7 con diferencias de 1–8 píxeles y máximo 1/255 por canal. Sin regresión visual material observada. Fotografías ocultas en esta comparación, como declara el método; las abrí en las capturas normales. |
| 106 capturas de revisión + 15 hojas; conjuntos 58 y 26 | **Confirmada en los archivos** | Índices y archivos presentes. Repetí `capture` (58) y `capture:fidelity` (26), ambos fuera del repositorio y con `--out` explícito; sin desbordes/problemas en el índice estándar. No puedo certificar qué imágenes abrió otra sesión. |
| H02/H03 y composición normal conservadas | **Confirmada en lo ejecutado** | Las 26 métricas nuevas son idénticas a las entregadas; revisión de imágenes nuevas, hojas de contacto y referencia Flutter, cuyas fotos son marcadores. |
| Comparador con enlaces corregidos | **Confirmada** | 7 pantallas × 2 tamaños × 3 imágenes cargadas, incluso con salida temporal fuera del repositorio. Sin enlaces Markdown rotos en los seis documentos principales y README revisados. |
| Los seis puntos completamente cerrados; D11 sin pendientes | **Refutada en su alcance general** | Las reproducciones originales están resueltas; GPT-05 deja el caso RE-01 y la revisión visual/teclado omite RE-02. |
| Alcance e históricos intactos | **Confirmada en los archivos comparables** | 16 archivos del prototipo añadidos/modificados: corresponden a la lista declarada. Paquete/dependencias iguales. 205 archivos históricos/prompts y 198 archivos de app/pruebas/`.claude` comparables con el inventario anterior no cambiaron. SHA del prompt original conservado. No es una prueba histórica universal de acciones externas. |

SHA-256 del prompt original:
`0a7ac81dd3910114805770dab2ce130e7dab06cfc20d40fb32f692d79d3124ed`.

## 4. Ejecuciones y evidencia reproducible

Directorio temporal de esta reauditoría, denominado **E** en los comandos:

`/var/folders/vp/1zm3yfq11_7bbzm2_t195l2r0000gn/T/monetta-gpt-reaudit-20261018.q5ejmyw9`

Los comandos npm se ejecutaron desde `design-prototype/`. `--out` siempre fue explícito
y fuera del repositorio. No ejecuté `fixtures`, instalaciones, commits ni push.

| Comando / ejecución | Resultado real |
| --- | --- |
| `git status --short`, `git rev-parse HEAD` | Lista anterior de diez archivos modificados por otras sesiones y mismos directorios sin seguimiento; HEAD `c828d684ed7ced1502a2c14ac5fc174cd882661f`. |
| `npm test` | Exit 0; 49/49; `E/npm-test.log`. |
| `npm run build` | Exit 0; `E/npm-build.log`. Sólo recompila el `dist` generado. |
| `npm run verify -- --skip-build --port=4511 --out=E/verify` | Exit 0; 204/204 en 437 s; `E/verify/verify-report.json`. |
| Extraer archivo anterior, comprobar hashes, `vite build` en `E/baseline` | 59/59; build exit 0. Enlaces a assets/dependencias actuales sin copiarlos ni modificarlos. |
| `node verify/check-audit-fixes.mjs --url=http://127.0.0.1:4515` | Exit **1 esperado**; 10/51 contra la base; `E/baseline-fixes.log`. |
| `node E/independent-probes.mjs`, `E/focused-probes.mjs`, `E/zoom-and-controls.mjs`, `E/extra-probes.mjs` | Exit 0; mediciones, navegación real, foco, AX tree, axe e insets. Resultados en `*-results.json`; el primer guion registra 67 escenarios, sin errores de JS ni peticiones externas. |
| `node E/mutation-checks.mjs` | Orquestador exit 0; dos controles actuales pasan y los mismos dos fallan en sus respectivas copias mutadas. `E/mutation-results.json`. |
| `comparar-pixeles.mjs --a=http://127.0.0.1:4515 --b=http://127.0.0.1:4514 --viewports=375x812,768x1024,1440x900 --out=E/pixels` | Exit 0; 137/144 iguales. Deltas calculados leyendo los PNG, `E/pixel-deltas.json`. |
| `npm run capture:fidelity -- --skip-build --out=E/capture-fidelity --port=4512` | Exit 0; 26 capturas; comparación de métricas 26/26 idénticas. |
| `npm run capture -- --skip-build --out=E/capture --port=4513` | Exit 0; 58 capturas. |
| `node E/comparator-check.mjs`, `node E/nav-pixels.mjs` | Exit 0; 42 imágenes cargadas y captura/píxeles del enlace de tablet. |
| `find ... -newer .../evidence/verify-report.json` | Exit 0; un archivo más reciente, descrito en RE-03. |
| `git diff --check` | Exit 0. |

Para repetir RE-01 y RE-02: servir el build en 4514 y ejecutar `node E/extra-probes.mjs`.
Este script usa además la base en 4515 para comparar la navegación de tablet antes/después.
Las instrucciones para reconstruir la base del `.tgz` están en el `RESULTADO.md` auditado;
los hashes fueron comprobados independientemente. Los servidores de esta auditoría se
detuvieron al terminar; el 5173 de otra sesión se dejó intacto.

**Errores de exploración, sin convertirlos en aprobaciones:** la primera extracción con
Python produjo `TypeError: extractall() got an unexpected keyword argument 'filter'`;
se validaron explícitamente rutas/enlaces del archivo y se extrajo con la API disponible.
El listado inicial en `/tmp` produjo `zsh:1: no matches found: /tmp/monetta-gpt-reaudit-*`:
macOS creó el directorio en `$TMPDIR`, cuya ruta real se usa arriba. Hubo lecturas con cwd
equivocado (`rg: src/styles/components.css: No such file or directory (os error 2)`,
`rg: src/styles/pages.css: No such file or directory (os error 2)`,
`sed: lib/features/product/product_header.dart: No such file or directory` y
`sed: docs/web-redesign/correcciones-auditoria-gpt-2026-10-18/revision-visual.mjs: No such file or directory`),
después leídas en su ubicación correcta. Se intentó `comparacion-pixeles/index.json`
(`No such file or directory`); el archivo real es `comparacion-pixeles.json` y se analizó.
Una lectura de `footer-novedades-collection.png` antes de terminar su captura devolvió
`unable to locate image ... (os error 2)`; luego se abrió la imagen existente.
Ninguno de estos fallos corresponde a una prueba del producto.

## 5. Límites e integridad

- No se ejecutó el control de zoom nativo ni se probaron dispositivos físicos. Los tamaños
  pequeños son viewports CSS y los insets son emulación CDP. No se infieren resultados de
  Safari, Firefox o lectores de pantalla; siguen fuera del alcance acordado.
- No repetí las 384 comparaciones completas ni una instalación limpia. Repetí 144 pares,
  la suite completa y los dos comandos de capturas. Las dependencias no cambiaron.
- La caché de retroceso/avance tiene cobertura unitaria del autor, no una reproducción real
  independiente aquí. El doble toque en la flecha conserva el comportamiento anterior ya
  declarado; no lo cuento como nuevo hallazgo.
- El recorrido auxiliar antiguo `focus:keyboard-top-and-bottom` clasifica incorrectamente
  los controles de la propia barra como si estuviesen ocultos por ella; ese dato no se usó
  para levantar un hallazgo. Sugerencias tampoco se juzgaron sólo contando etiquetas `h1`:
  se comprobó el rol en el árbol de accesibilidad real.
- Antes de escribir este informe se revalidaron **1034 archivos** fuera de worktrees:
  contenido y metadatos sin cambios durante esta auditoría; `git status` y HEAD iguales.
  Sólo se añade este informe. Los scripts, capturas y experimentos están en E; al ser
  temporales, sus enlaces requieren conservar esa carpeta.
- No puedo demostrar retrospectivamente la ausencia de todas las acciones de otra sesión
  (p. ej., un push). Sí comprobé estado local, hashes disponibles y evidencia entregada.
  Esta auditoría no hizo llamadas externas del prototipo, escrituras en Shopify ni cambios
  de fuentes, Flutter, backend, `.claude`, configuración o evidencia anterior.
