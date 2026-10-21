# Predictive search: entorno independiente

Desde la raíz del repositorio:

```sh
npm --prefix tools/style-guideline-predictive-search run demo
npm --prefix tools/style-guideline-predictive-search test
npm --prefix tools/style-guideline-predictive-search run check:theme
```

La demo imprime una URL en `127.0.0.1` con un puerto libre asignado por el sistema. Ctrl+C detiene únicamente ese proceso. Para elegir un puerto propio libre:

```sh
PREDICTIVE_PORT=43187 node tools/style-guideline-predictive-search/demo.mjs
```

Prueba `bolsa`, `vacío`, `error` y `lento`. Hay dos instancias, formularios GET locales y una advertencia visible de catálogo simulado. `?locale=en` cambia la fixture al inglés; `?core=1&autofocus=1` carga los manejadores Monetta actuales en esta demo aislada.

No se instala nada. Las pruebas usan `playwright-core` y `axe-core` ya instalados en `design-prototype/node_modules`, y el ejecutable local de Brave. No ejecutan código de las suites del prototipo. Para otro Chromium instalado:

```sh
PREDICTIVE_BROWSER="/ruta/al/ejecutable" npm --prefix tools/style-guideline-predictive-search test
```

El servidor de pruebas usa su propio puerto efímero y se cierra al terminar. `check:theme` copia únicamente los archivos nuevos del componente a `theme-check-fixture/`, añade el esqueleto mínimo y ejecuta el Shopify Theme Check instalado contra esa copia. No analiza ni corrige el tema compartido; no autentica una tienda ni sube archivos.

`fixture.mjs` materializa el HTML del snippet mediante sustituciones explícitas, sin implementar Liquid. Falla si quedan enlaces de plantilla desconocidos. Las respuestas de Shopify y los productos son simulados. La sintaxis Liquid se revisa por separado con Theme Check; el render real en Shopify sigue pendiente.

La evidencia se escribe únicamente en `docs/style-guideline-migration/predictive-search/`. Consulta [INTEGRATION.md](../../docs/style-guideline-migration/predictive-search/INTEGRATION.md) y [VALIDATION.md](../../docs/style-guideline-migration/predictive-search/VALIDATION.md).
