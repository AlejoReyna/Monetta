# Tema Shopify en staging — seguimiento

Seguimiento de la traslación de `design-prototype/` a un tema de `monetta-staging.myshopify.com`. Es independiente del programa `/refactor` y de las auditorías históricas de `docs/web-redesign/`.

| Archivo / carpeta | Contenido |
|---|---|
| [`ENTREGA.md`](ENTREGA.md) | Informe de la primera entrega: tema, base y respaldo, archivos, diferencias, fuentes de datos, sincronización app↔web, verificación, limitaciones y siguiente bloque |
| [`RUNS.md`](RUNS.md) | Índice generado de las ejecuciones (tienda, tema, estado del código, comando, hora, resultado) |
| `THEME.env` | Tienda e ID del único tema autorizado |
| `baseline/` | Respaldo (`.tgz`) y manifiesto SHA-256 de la copia de Atelier 3.5.0 usada como base, lista de temas «antes», Theme Check de la base |
| `runs/` | Una carpeta por ejecución (`result.json` o `result.partial.json`, capturas, hojas de contacto); `antes-de-corregir/` conserva el registro de la ejecución interrumpida que encontró defectos de anillo |
| `scripts/` | `theme-push.sh` (subida con guardián), `start-theme-dev.command` (proxy autenticado), `port-css.mjs` y `port-icons.mjs` (portado reproducible del CSS y de los iconos), `shot.mjs`, `runs-index.mjs`, `e2e/` (verificadores con Brave y `playwright-core`) |
