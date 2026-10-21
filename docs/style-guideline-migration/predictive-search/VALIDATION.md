# Validación local del buscador predictivo

Resultado: **29/29 pruebas aprobadas**, sin excepciones JavaScript no controladas. **Theme Check sin incidencias** sobre la copia aislada de esta entrega. No se ha realizado validación contra una tienda Shopify ni se ha subido el tema.

Comandos desde la raíz:

```sh
npm --prefix tools/style-guideline-predictive-search test
npm --prefix tools/style-guideline-predictive-search run check:theme
node --check storefront-theme/assets/monetta-predictive-search.js
npm --prefix tools/style-guideline-predictive-search run demo
```

La demo imprime su propia URL de loopback y usa un puerto efímero. Las pruebas abren otro servidor propio y lo cierran. No se ejecutaron builds, suites ni servidores de Claude. No se instalaron dependencias.

## Entorno y evidencia

- Node `v24.21.0`; Shopify CLI instalado `4.9.4`.
- Brave local con motor Chromium `155.0.8059.40`, mediante `playwright-core` ya instalado.
- `axe-core` ya instalado; comprobaciones WCAG 2 A/AA, 2.1 A/AA y 2.2 AA del componente en seis combinaciones de ancho/tamaño de texto, sin infracciones detectadas.
- [Reporte de las pruebas](test-results.json), con fecha UTC, nombres de casos, navegador y tiempos.
- [Resultado de Theme Check](theme-check.json): `[]`. [stderr](theme-check.stderr.txt) vacío.
- Se inspeccionaron visualmente las seis capturas listadas abajo.

Las fixtures se materializan desde el snippet entregado mediante sustituciones explícitas. No son un intérprete Liquid ni ejecutan Shopify. Las pruebas cargan los JS/CSS de producción y simulan el HTML de respuesta de la API. Theme Check analiza por separado los cuatro archivos Liquid y los dos assets, junto con un esqueleto mínimo, en `tools/style-guideline-predictive-search/theme-check-fixture/`. Su resultado no certifica el resto del tema.

## Cobertura ejecutada

| Área | Comprobación |
| --- | --- |
| Petición y debounce | Una petición tras escritura rápida, parámetros exactos, consulta con caracteres especiales y endpoint de locale. |
| Respuestas fuera de orden | Fetch simulado que ignora abortos; una respuesta vieja no reemplaza la nueva, tampoco durante el debounce ni al reconectar con la misma consulta. |
| Disponibilidad | Error de red, HTTP 417/429/503, HTML inesperado, petición detenida y respuesta posterior al timeout. |
| Estados | Carga, resultados, vacío y error; anuncios locales y `aria-busy`; acceso a resultados completos. |
| Navegación real del navegador | Enter sin selección envía GET; seleccionar producto conserva el destino y variante devueltos por la fixture; el enlace de resultados conserva la consulta. |
| Teclado y cierre | Flechas con recorrido circular, `aria-activedescendant`, foco en el campo, Enter, Escape, Tab sin trampa, cierre explícito y exterior. |
| Monetta actual | Se cargan `monetta-core.js` y `monetta-listing.js` sin modificarlos; autofocus, un solo evento al borrar y reconexión sin peticiones duplicadas. |
| Diálogo | Primer Escape cierra sugerencias; segundo cierra el diálogo actual mediante un solo `cancel`. |
| Varias instancias | Consultas, peticiones, selección e IDs independientes; una respuesta de la instancia anterior no reabre su panel. |
| Historial | Persistencia tras recarga, ámbito por idioma, selección con Enter, JSON corrupto, texto no confiable, límite y deduplicación. |
| Almacenamiento bloqueado | Getter de `localStorage` y métodos que lanzan `SecurityError`; historial en memoria y borrado funcional. |
| Entrada y mejora progresiva | Composición IME; formulario funcional con JavaScript desactivado y con `fetch` ausente. |
| Layout | 390, 834 y 1440 px; texto al 100 % y 200 %; nombres largos; acciones de al menos 48 px y sin truncamiento; footer alcanzable por scroll. |
| Viewport | Campo estrecho junto al borde, resize, contenedor que se oculta, insets laterales simulados y viewport móvil corto con apertura superior. |

## Capturas

| Ancho | Texto 100 % | Texto 200 % |
| --- | --- | --- |
| 390 px | [Móvil](screenshots/predictive-390-100.png) | [Móvil ampliado](screenshots/predictive-390-200.png) |
| 834 px | [Tablet](screenshots/predictive-834-100.png) | [Tablet ampliado](screenshots/predictive-834-200.png) |
| 1440 px | [Desktop](screenshots/predictive-1440-100.png) | [Desktop ampliado](screenshots/predictive-1440-200.png) |

El escalado se aplica al tamaño raíz de texto, no emula el zoom óptico de un dispositivo. Las capturas usan los tokens vigentes, datos simulados y fuentes de respaldo del navegador: la demo no carga el snippet de fuentes del layout. No son una aprobación del nuevo diseño cálido ni de la composición final de la cabecera. Con texto grande, parte de la lista queda detrás del scroll del propio panel; las acciones permanecen alcanzables.

`screenshots/failure-12.png` conserva un diagnóstico de una ejecución previa del caso de diálogo, corregido después. El reporte JSON y las seis capturas nombradas en la tabla corresponden a la validación final.

## Validaciones pendientes y límites

1. **Shopify real:** render de Liquid de los archivos nuevos en un tema no publicado; catálogo, imágenes sin/ con media, mínimo de precio y moneda de presentación, URLs de variantes, locale/mercado y disponibilidad del servicio. No se realizaron peticiones a una tienda para declarar aprobado este componente.
2. **Integración de Claude:** aplicar los dos cambios de [INTEGRATION.md](INTEGRATION.md), revisar fuentes/estilos definitivos, superposición con navegación y barras fijas, y correr la verificación del tema integrado bajo su propio flujo.
3. **Theme Editor:** añadir, reordenar, quitar y volver a añadir la sección; cambiar sus límites, desactivar historial, y comprobar la carga inicial de assets en una página que antes no usaba el componente.
4. **Plataformas y accesibilidad manual:** Safari, Firefox, iOS/Android, teclado virtual real, pinch zoom, VoiceOver/NVDA y lectores de pantalla. Axe y Chromium no sustituyen esas comprobaciones.
5. **Persistencia:** historial por navegador y ámbito; no se sincroniza con cuenta/dispositivos. Si el almacenamiento está bloqueado, la copia en memoria se pierde al recargar o navegar a otro documento.
6. **Idiomas y geometría:** UI española/inglesa y respaldo español explícito en otros idiomas. Validar RTL si se incorpora. Un ancestro con transformaciones/contención puede cambiar el bloque de referencia de un panel fixed; revisar si el shell introduce ese patrón.

No hay publicación, cambios remotos, medición de rendimiento de tienda ni afirmación de validación comercial. La integración en los archivos compartidos queda para Claude conforme a los límites del encargo.
