# Reauditoría independiente de RE-01, RE-02 y RE-03

Auditoría del estado E2 en /Users/alexis_reyna/MyCode/Monetta, iniciada el 18/10/2026 y terminada el 19/10, hora de Monterrey. Se conserva el nombre de carpeta solicitado. No corregí el prototipo ni la documentación existente. Regeneré `design-prototype/dist/` mediante el build autorizado.

Entorno ejecutado: Node 24.21.0, Vite 6.4.3, Playwright Core 1.63.0 y Brave/Chromium 155.0.8059.40 instalado. Evidencia propia: **E = `/tmp/monetta-gpt-reaudit2-20261018-hq_4tyy8`**. Los guiones propios y sus JSON están allí; los informes del autor sólo se usaron como afirmaciones que contrastar.

## 1. Veredicto

| Punto | Veredicto | Motivo y evidencia independiente |
| --- | --- | --- |
| RE-01 | **Corregido** | En 1023/1024/1280/1440 × 200/360/480, las cinco páginas dejan toda la altura disponible, sin elementos sticky/fixed del contenido. A 481 px se conserva el modo normal. La galería y las columnas recuperan dimensiones utilizables. |
| RE-02 | **Corregido** | Tab, Shift+Tab, entrada inversa, insets y estado activo/hover: 193 estados de foco de E2, 46.510 muestras a lo largo de los cuatro lados rectos del anillo, ninguna ausente. Diferencia con la máscara retirada: **0**, incluso sin tolerancia. |
| RE-03 | **Parcial: código trazable; evidencia y documentación incompletas** | El árbol sigue siendo E2 y ningún archivo de src/verify/tests/package.json es posterior a la puerta del autor. Sus logs distinguen árbol, build y herramientas. Sin embargo, el JSON «después» fue sobrescrito por una repetición interrumpida y la documentación vigente todavía describe la iteración anterior. |
| D11 | **Cierre formal pendiente** | Esta auditoría confirma técnicamente RE-01/02 y aporta la revisión visual y validaciones finales que faltaban. La entrega de Claude sigue sin RESULTADO ni actualización del ledger; no ratifico como vigente el cierre de la iteración anterior. No queda demostrado un defecto material del producto en estos dos puntos. |

**No encontré Blocker ni Alta en el alcance ejecutado.** Los hallazgos siguientes afectan las pruebas y la evidencia; no deben presentarse como tres defectos nuevos de la interfaz.

### Mediciones propias de producto

Guiones: `E/independent-metrics.mjs`, `E/independent-nav.mjs`, `E/independent-flows.mjs` y `E/filters-confirmed.mjs`.

- **Ventanas bajas:** 80 combinaciones por estado: cuatro anchos × cuatro alturas (200/360/480/481) × Inicio, colección, ficha, búsqueda y bolsa. Los 60 casos de E2 con altura ≤480 no tienen elementos sticky/fixed fuera de overlays/toasts. En colección 1024×200, tras scroll de 800: cabecera sticky, borde 146 y 54 px libres en E0 → static y **200 px libres** en E2; reserva superior 162 → 16 px.
- **Columnas a 1280×200:** visor **0×0 → 570,875×713,594 px**, miniaturas **7 → 760 px**, filtros **23 → 978 px**; panel y resumen pasan a static. A 1024×480 el visor mide 431,672 px de ancho; a 481, 196,797×245,984. Este salto corresponde al cambio explícito de modo: no lo clasifico como defecto por sí solo; ambos modos conservan contenido y acciones accesibles.
- **Modo normal:** a 1024×768 y 1440×900, las cinco páginas conservan cabecera sticky de **146 px**; se mantienen las columnas sticky correspondientes. A 1024/1440×481 el visor sigue midiendo 196,797 px de ancho. Se sostienen las cifras de DESIGN_SPEC §§5/7 e IMPLEMENTATION_HANDOFF §§4/10/11 relativas a estas reglas.
- **Acciones reales:** añadir y aumentar cantidad, abrir/cerrar checkout, aplicar disponibilidad, buscar «tote», Atrás y Adelante; cuatro ventanas: 1024×200, 1280×240, 1440×360 y 812×375 con insets 44. Restauración de scroll medida en pointerdown → Atrás: **600→600, 558→558, 488→488 y 427→427**. Veinte paradas del pie, con centro dentro de la ventana. La aplicación efectiva del cajón se confirmó aparte en 1024×200 y 812×375: URL `?filter.v.availability=1`, diálogo cerrado.
- **Navegación:** cinco anchos 768/812/1023/1024/1440, con y sin insets 44; también 812×375 con insets y entrada inversa a 768/812/1023. En 768, último enlace: scroll **249→330**, texto **630,266…736,422 → 549,266…655,422**, caja hasta 667,422; máscara desde 675,84. Contraste mínimo de la tinta central, calculado con luminancia sRGB sobre blanco: **2,35:1 → 14,74:1**. En E0 faltan los lados superior/inferior; en E2 los trazos rectos están completos, dejando fuera las esquinas redondeadas. Activo + hover a 768/1024/1440 conserva anillo y subrayado separados.
- **Insets y resize:** en 1024×200 y 812×375, insets emulados de 44 px, las cinco páginas no desbordan. Con el buscador enfocado, resize CSS 390×844→480→360→481→844 conserva el input en y=117…167: la cabecera cambia a static hasta 480, el dock sale de la zona visible mientras se escribe y vuelve el modo normal al aumentar altura. **No es una prueba de teclado nativo ni de zoom.**
- **Regresión visual:** ejecuté el comparador del autor sobre mis builds E0/E2 y analicé independientemente los PNG con Pillow: **480 pares**, 16 rutas × 10 viewports × tres posiciones. **377 idénticos; 96 diferencias confinadas a la navegación** (48 a 1023×900 y 48 a 1024×768); siete diferencias restantes de **1–8 píxeles, máximo 1/255**. Fotografías ocultas sólo para esta comparación. Incluye 375×812, 440×956, 768×1024, 1024×768, 1440×900 y anchos 900/1000/1023/1060/1280 a 900 de alto.

La fila de 1023 sí cambia unos **5,58 px** desde los botones finales: el relleno adicional termina de comprimir sus SVG, que ya se encogían en E0. A 1023 el rango de scroll pasa de 0 a 105; a 1000, de 17 a 125. Es un efecto menor del espacio necesario para salir del degradado, sin pérdida de texto enfocado ni de acciones comprobada. No sostengo que todo sea idéntico fuera de 1024–1059: **1023 es la excepción observada**. A 1060/1280/1440 las posiciones de escritorio coinciden con E0; `fit-content` funciona en el Brave probado. No extrapolo a otros motores.

## 2. Hallazgos por severidad

### R2-01 — Media · evidencia · defecto: el JSON «después» actual está incompleto

**Fuente:** `docs/web-redesign/correcciones-reaudit-gpt-2026-10-18/logs/reproducciones-despues.log:1`; `despues/resultados-despues.json:1194`; guion `reproducciones-reaudit.mjs:235` y :243 de esa carpeta.

**Reproducción:** leer ese log y consultar `findings.re02` del JSON. El log comienza el **18/10 23:40:00 CST**, dice `measured re01`, después:

```text
ERROR re02: page.screenshot: Target page, context or browser has been closed
Saved .../despues/resultados-despues.json
```

El JSON tiene `measuredAt: 2026-10-19T05:40:02.196Z` y RE-02 sólo contiene ese error. Por tanto, la afirmación de que el comando interrumpido no se ejecutó ni cambió nada **no coincide con los archivos**. No es simplemente la ausencia declarada de una repetición: se sustituyó la salida «después».

**Causa:** el guion captura errores por hallazgo y escribe siempre al mismo destino; no establece un código de salida fallido en ese catch. No hay marcador de finalización de esta ejecución en el log.

**Impacto:** las cifras atribuidas a RE-02 ya no pueden comprobarse contra el JSON «después» vigente. Mis mediciones las confirman, pero no reparan retroactivamente la traza del autor.

**Corrección sugerida:** conservar cada ejecución en un destino único, marcar resultados parciales y finalizar con error cuando falte un hallazgo; publicar una comparación completa identificada con E2.

### R2-02 — Media · pruebas · riesgo: la exención por altura admite un foco totalmente fuera de pantalla

**Fuente:** `design-prototype/verify/probes.mjs:346` y :350.

**Reproducción propia:** `node E/independent-flows.mjs`, caso `focusProblems oversized offscreen control`, en `E/flows/results.json`. Con foco en el primer enlace del pie, sólo en esa página de navegador añadí altura de 2000 px y una traslación vertical de 5000 px.

La sonda informa **oversize=true, centerOffscreen=true**, caja y=5409,42…7409,42 y cuatro lados fuera de pantalla; **`focusProblems([stop])` devuelve `[]`**. No modifiqué ningún fuente del repositorio.

**Causa:** `fits` condiciona también la comprobación del centro fuera de pantalla. La justificación de tolerar los extremos de una tarjeta demasiado alta no justifica perder su centro.

**Impacto:** una regresión que saque un control alto de la ventana puede aprobar la sonda. Es una debilidad del verificador; no demuestra que el producto E2 presente ese estado.

**Corrección sugerida:** exigir siempre un centro visible y no tapado; limitar la exención a los extremos que físicamente no caben.

Otros límites revisados, sin convertirlos en defectos nuevos del producto: el cajón de filtros en `check-reaudit-fixes.mjs:264` sólo espera visibilidad de layout y comprueba y/altura, no x ni que aplicar cambie los resultados. Mi primera captura lo alcanzó durante su entrada, con el botón en x=1125,78 en una ventana de 1024. Por eso repetí la prueba esperando la posición final y **apliqué** un checkbox. `pinnedElements` excluye overlays/toasts deliberadamente: su barrido no certifica esos paneles.

### R2-03 — Media · evidencia/herramienta · defecto: el comparador falla al resolver un alias de carpeta

**Fuente:** `design-prototype/verify/capture-fidelity.mjs:20` y :23. Este archivo coincide con E0: **no es una regresión introducida en E2**.

**Reproducción ejecutada:**

```sh
npm run capture:fidelity -- --skip-build --out=/tmp/monetta-gpt-reaudit2-20261018-hq_4tyy8/capture-fidelity --port=4712
node /tmp/monetta-gpt-reaudit2-20261018-hq_4tyy8/comparator-check.mjs
```

El comando genera las 26 capturas y termina con exit 0. Sin embargo, el HTML calcula tres `../` desde `/tmp/...`; al abrirlo por su ubicación real `/private/tmp/...`, las columnas «app» y «antes» apuntan a **`file:///private/Users/alexis_reyna/...`**, que no existe. Ambas imágenes tienen naturalWidth=0; «después» carga. La espera agotó 30.000 ms; el diagnóstico de 2500 ms confirmó las URLs.

**Control:** repetí con salida explícita `/private/tmp/.../capture-fidelity-realpath`, sin cambiar código: **14 selecciones y 42 imágenes cargadas**.

**Causa:** `path.resolve` normaliza segmentos, pero no resuelve el enlace simbólico antes de calcular rutas relativas.

**Impacto:** una salida temporal permitida produce un comparador roto pese al exit 0. No afecta el catálogo ni los PNG/JPG originales.

**Corrección sugerida:** calcular enlaces entre rutas canónicas y comprobar la carga de las tres columnas al validar la herramienta.

### Pendientes declarados y observaciones, sin contarlos como hallazgos nuevos

- **Documentación:** no existe `correcciones-reaudit-gpt-2026-10-18/RESULTADO.md`. STATUS:13 y :91 mantiene D11 cerrado; VERIFICATION:7/:39 sigue en 49/204/92; FINAL_REPORT:22/:124 también. DESIGN_SPEC y HANDOFF sí describen las reglas nuevas. Es el trabajo interrumpido declarado, no una aprobación nueva que atribuya a Claude. Además, `logs/E1-superado/LEEME.txt:11` dice «todo lo demás se repitieron sobre E2» y enlaza ese RESULTADO inexistente: debe limitarse a lo realmente terminado.
- **Conservación de E0:** no hay tgz completo. Recuperé la copia temporal: la aplicación coincide con E0, pero `verify/probes.mjs` coincide con E2 y existe el control nuevo. La copié a E antes de probar. No presento esa carpeta mixta como un árbol E0 completo de 64 archivos.
- **Capturas:** abrí las seis hojas de los conjuntos nuevos estándar/fidelidad —58+26 vistas—, hojas propias y recortes individuales de anillo, ventanas bajas y diálogos. Una salida inicial de fidelidad mostró fotografías del riel sin pintar (`ficha_recomendaciones_375x812.jpg`); tres reproducciones posteriores con lectura de complete/naturalWidth/decode sí las muestran. No lo atribuyo a E2 como defecto del catálogo. Los waits fijos de la captura no garantizan pintura final; un índice sin errores no sustituye abrir las imágenes.

**Qué falta para formalizar D11:** RESULTADO de E2 y actualización coherente de STATUS, VERIFICATION y FINAL_REPORT; enlazar y conservar una salida «después» íntegra y la evidencia final válida, con sus árboles y tiempos. Esta auditoría **ya ejecutó** comparación E0↔E2, mutaciones E2, ambos comandos de capturas y revisión visual: no los dejo como pruebas sin ejecutar ni exijo repetir lo que aquí está demostrado. Los riesgos de pruebas indicados deben quedar explícitos y no convertirse en una promesa universal de accesibilidad.

## 3. Contraste de afirmaciones

| Afirmación | Estado | Evidencia propia |
| --- | --- | --- |
| E2 actual conserva sus 65 hashes | **Confirmada** | Recalculados; ninguna diferencia con manifiesto E2. |
| Ocho archivos distintos de E0; E1→E2 sólo dos | **Confirmada** | Siete modificados + un archivo nuevo; components.css y el control nuevo son las únicas diferencias E1→E2. |
| Las 49 unitarias y los 204 controles anteriores se conservan | **Confirmada en lo verificable** | Unitarias anteriores conservadas, tres añadidas; suites anteriores iguales por hash. Los 204 pares gate/nombre permanecen en el mismo orden. El helper compartido probes sí cambió; no lo califico de byte idéntico. |
| 52 unitarias y build aprobados | **Confirmada** | Ejecuciones nuevas, exit 0. |
| 227 checks; D11 115; D10 limpio | **Confirmada** | Ejecución propia: **227/227 en 752 s**, D11 115/115, D10 1/1, problems vacío. Los 618 s son la ejecución del autor. |
| 23 nuevos = 12 RE-01 + 11 RE-02 | **Confirmada** | Tres repeticiones **23/23**, en 180/218/206 s; base **2/23, exit 1**, 204 s. Los 21 fallos corresponden a las condiciones que conservaba E0. |
| Nuevas pruebas detectan cada pieza de la solución | **Confirmada para las mutaciones ejecutadas** | Control 23/23; sin relleno 3 pasan/8 fallan; anillo exterior 1/10; límite de ancho 2/10; sin columnas 7/5; fila centrada con desborde 0/2. Validé dirección y número de resultados, no sólo el exit del harness. |
| 54→200 px, 0×0→571×714, 7→760, 23→978 | **Confirmada** | Matriz independiente y capturas en E/independent. |
| Scroll 249→330; cuatro lados pintados | **Confirmada** | Guion propio, captura con/sin máscara y barrido de lados, incluyendo regreso y hover/current. |
| «Después» conserva la ejecución completa descrita | **Refutada para el archivo vigente** | Se sobrescribió a 23:40; RE-02 contiene un error. |
| No cambió código después de la puerta de E2 | **Confirmada para el conjunto auditado** | Hashes coincidentes; find -newer no devuelve fuentes, verificadores, tests ni paquete. |
| Comparador funciona en cualquier --out | **Refutada** | Alias /tmp falla; salida canónica /private/tmp carga 42/42. |
| 26 métricas de fidelidad conservadas | **Confirmada** | Las 26 son idénticas a las de la corrección anterior; 58 capturas estándar sin desbordes/problemas registrados. Esto no certifica por sí solo que cada foto esté pintada. |
| Sin cambios visibles fuera de la franja de escritorio afectada | **Con matiz** | A 1023 también cambia la navegación. Fuera de esas filas, siete diferencias de raster de máximo 1/255; no observé regresión material. |
| D11 y documentos actuales ya reflejan esta iteración | **Refutada como estado del repositorio; pendiente admitido** | Faltan RESULTADO/ledger; la afirmación de cierre visible corresponde a la iteración anterior. |

Las tres unitarias nuevas explican la aritmética del scroll con valores conocidos; por sí solas no demuestran fidelidad. Las pruebas de navegador sí fallan en E0 por razones observables. `maskInfluence` cuenta diferencias >24: no es igualdad de píxel; mi contraste adicional fue de tolerancia cero. En E2 dio cero en todos los estados examinados. La refactorización de keyboardTraversal conserva el recorrido predeterminado con salto al contenido y añade opciones para recorrer cabecera; no encontré supresión de los controles anteriores. El muestreo de la suite lee cuatro puntos del anillo, no todos sus lados; el barrido propio amplía esa evidencia.

## 4. Ejecuciones y evidencia reproducible

Comandos npm desde `design-prototype/`; guiones propios desde E. Mis previews: E2 en 4714 y aplicación E0 recompilada en 4715. Los scripts propios usan esas URLs. No usé 4601/4602 como fuente de aprobación.

| Ejecución | Resultado real / salida |
| --- | --- |
| git status --short; git rev-parse HEAD | Diez modificaciones ajenas y directorios esperados; HEAD conservado. |
| npm test | **52/52**, exit 0; E/npm-test.log. 18/10 23:46:54 CST. |
| npm run build | **Exit 0**; E/npm-build.log. Regeneró dist. |
| npm run verify -- --skip-build --port=4711 --out=E/verify | **227/227, 752 s, exit 0**; 18/10 23:47:14–23:59:46 CST. |
| node verify/check-reaudit-fixes.mjs --url=http://127.0.0.1:4714, tres veces | **23/23** en 180, 218 y 206 s, exit 0 cada vez. |
| Mismo guion con --url=http://127.0.0.1:4715 | **2/23**, exit **1 esperado**; E/reaudit-base.log. |
| Vite build/preview de E/base | Exit 0; aplicación E0 reconstruida localmente, sin depender del servidor de Claude. |
| node E/independent-metrics.mjs; --extras-only | 160 filas E0/E2 + extras; primera ejecución falló al llegar a insets. Los datos previos se conservaron; extras repetidos con CDP correcto. JSON metrics-first-pass y metrics. |
| node E/independent-nav.mjs; --tail-only | 211 estados: 193 E2, 18 E0. Primer intento falló al llegar a insets; la continuación correcta cubre lo pendiente. |
| node E/independent-flows.mjs | 24 escenarios + mutación de la sonda, sin errores de ejecución. JSON flows/results. |
| node E/filters-confirmed.mjs | Repetición final **exit 0**, checkbox aplicado y diálogo cerrado en los dos cajones. |
| comparar-pixeles.mjs --a=http://127.0.0.1:4715 --b=http://127.0.0.1:4714 --out=E/pixel-comparison --viewports=375x812,440x956,768x1024,1024x768,1440x900,900x900,1000x900,1023x900,1060x900,1280x900 | **377/480 idénticos**, exit 0. E/pixel-analysis.json añade clasificación y máximos por canal. Herramienta del autor, ejecutada por mí. |
| node E/mutations-run.mjs --tmp=E/mutation-copies --out=E/mutations-E2.json | Seis ejecuciones; todas las mutaciones negativas detectadas. Copia del harness del autor, cambiando sólo raíz absoluta y puertos a 4721–4726. |
| npm run capture -- --skip-build --port=4713 --out=E/capture | **58**, exit 0. |
| npm run capture:fidelity -- --skip-build --port=4712 --out=E/capture-fidelity | **26**, exit 0; comparador por alias falla según R2-03. |
| Mismo capture:fidelity, --port=4716 --out=/private/tmp/.../capture-fidelity-realpath | **26**, exit 0; comparator-check --realpath: **14 selecciones, 42 imágenes**. |
| node E/rail-readiness.mjs | Tres reproducciones; imágenes visibles completas y decodificadas en las tres. No reprodujo las fotos vacías de la primera salida. |
| find src verify tests package.json -type f -newer ../docs/web-redesign/correcciones-reaudit-gpt-2026-10-18/evidence/verify-report.json | **Sin resultados**. |

En E están los logs npm, JSON, scripts, PNG/JPG, hojas de contacto, diferencias y manifiestos. Para repetir, levantar los previews con `npm run preview -- --host=127.0.0.1 --port=4714` y el equivalente desde E/base en 4715; usar los guiones de E. Las salidas propias no se copiaron encima de evidencia histórica.

**Errores de exploración, sin convertirlos en aprobaciones ni defectos del producto:**

- Nombre CDP incorrecto en los dos primeros guiones: `Protocol error (Emulation.setSafeAreaInsets): 'Emulation.setSafeAreaInsets' wasn't found`. Se corrigió únicamente el guion temporal a `Emulation.setSafeAreaInsetsOverride` y se repitió lo dependiente.
- Consultas iniciales a rutas supuestas: `comparar-pixeles-reaudit.mjs`, `verify/fixtures.mjs`, `src/components/product-card.js`, `src/lib/images.js`, `estados/E2.sha256`, `src/components/overlays.js` y `src/lib/overlays.js`: **No such file or directory**. Se localizaron los nombres reales.
- Una consulta de mi JSON lanzó `KeyError: 'width'` al incluir el caso resize, que usa viewport; corregí la consulta y repetí.
- La primera prueba adicional de aplicar filtros agotó **page.waitForURL: Timeout 30000ms exceeded**: mi selector pulsaba el primer radio de orden ya seleccionado. Repetí con el primer checkbox de disponibilidad: ambas URLs cambiaron correctamente.
- El comparador por alias agotó **page.waitForFunction: Timeout 30000ms exceeded**; el diagnóstico a 2500 ms conservó las URLs fallidas. El control con ruta canónica sí pasó.

## 5. Límites e integridad

Recalculé independientemente los digests de las líneas de cada manifiesto:

| Estado | Archivos | SHA-256 del árbol |
| --- | --- | --- |
| E0 | 64 | c64c9a523e49b5a55b680519fa53614ee1a0a44f01693411ef185dd619cb0a0e |
| E1 | 65 | f3a58b2dc6673f70544c5e76b10468fb37e10fc97d8ab78e301f8ed712588290 |
| E2 | 65 | d81416b09eb1e6f177e20d9c1e5efae434f79868c71a66ca9497fc17a31029e0 |

E2 coincide archivo a archivo con el repositorio. Los ocho cambios respecto de E0 son README, scrollers.js (sólo comentario), components.css, pages.css, chrome.test.mjs, probes.mjs, run-all.mjs y el nuevo check-reaudit-fixes.mjs. Los otros 57 archivos coinciden con E0; paquete, lockfile y suites anteriores permanecen iguales. El digest no cubre public/fixtures/dist ni los guiones documentales: los contrasté mediante inventarios separados, sin atribuirle una cobertura que no tiene.

Comparé **2169 archivos preexistentes** inventariados al comenzar: **ningún hash cambió durante la auditoría**; dist queda fuera del inventario por ser el generado autorizado. Frente al inventario de mi reauditoría anterior, **560 archivos históricos/prompts comparables permanecen idénticos**. Aquel inventario precedía a la creación de su propio informe; ese informe sí quedó protegido por el inventario de esta sesión.

SHA-256 del prompt original conservado:

`0a7ac81dd3910114805770dab2ce130e7dab06cfc20d40fb32f692d79d3124ed`

Git mantiene la lista inicial y HEAD `c828d684ed7ced1502a2c14ac5fc174cd882661f`. Sólo añadí este informe al repositorio, además del dist generado permitido. No ejecuté fixtures, instalaciones, commits, push, publicaciones ni escrituras en Shopify. Mis mediciones no registraron peticiones externas; el gate completo registra problems vacío. Eso no permite certificar históricamente lo que otra sesión pudo ejecutar ni probar que nunca hubo un push anterior.

Cerré mis previews y conservé los servidores ajenos 4601, 4602 y 5173. No modifiqué Flutter, backend, .claude, secretos ni configuración.

Sin verificar: dispositivos físicos, Safari/Firefox, lectores de pantalla, teclado virtual real, zoom nativo, Shopify en producción o staging y la revisión de imágenes que otra persona afirma haber hecho. Los insets son emulación CDP; los tamaños son viewports CSS. Los scripts y las capturas en E son temporales y pueden desaparecer: conservarlos es parte del cierre documental pendiente.

