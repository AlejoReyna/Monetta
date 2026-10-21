# Auditor de contenido de la migración visual

Auditor **1.0.1**; payload `contractVersion: 1.0.0`, con revisión de validación `1.0.1`. La entrega inicial, su código y sus informes están archivados en `docs/style-guideline-migration/content-readiness/reports/archive/initial-1.0.0/`.

Node **20 o posterior**, sólo módulos nativos. No requiere `npm install`, credenciales, Shopify CLI, proxy o acceso a red. No ejecuta builds, capturas ni suites de Flutter/prototipo/tema.

Desde la raíz del repositorio:

```sh
node tools/style-guideline-content/audit.mjs
node --test tools/style-guideline-content/test/*.test.mjs
node tools/style-guideline-content/audit.mjs --live
node tools/style-guideline-content/audit.mjs --strict
# Pruebas propias + reproducciones contra la versión archivada + CLI y huellas.
node tools/style-guideline-content/verify-corrections.mjs
```

También se pueden usar `npm --prefix tools/style-guideline-content test` y los scripts `audit`, `audit:live`, `audit:strict`, `verify:corrections`.

## Entradas y salidas

Datos por defecto: `docs/style-guideline-migration/content-readiness/`.

- `content-contract.v1.schema.json`: modelo normalizado V1 y definición del inventario de assets.
- `content-baseline.json`: contenido realmente respaldado más omisiones deliberadas, recursos legacy, decisiones y capacidades fechadas. Los IDs normalizados/copy de sección no prueban disponibilidad remota.
- `route-map.json`: destinos, tipos, aliases no asumidos equivalentes, estados y extractos de evidencia.
- `screen-requirements.json`: cobertura de PDF 1–19, módulos, marcas/categorías y plantillas requeridos.
- `field-map.json`: campos actuales, ampliaciones y responsables.
- `evidence/source-manifest.json` + `evidence/snapshots/`: fecha, SHA-256 y texto congelado de las fuentes. Los binarios originales se identifican por hash/metadatos; no se necesita que el PDF siga en Desktop para la ejecución offline.

La ejecución escribe `reports/offline/audit.json` y `reports/offline/audit.md`. `--live` escribe en `reports/live/` y añade comparación SHA-256 contra los archivos locales actuales, sin alterar las fuentes congeladas ni reinterpretar el contenido modificado.

Los informes actuales son del auditor 1.0.1. Los anteriores se archivaron **antes** de regenerarlos. `reports/correction-1.0.1/` distingue pruebas, reproducciones y salidas de esta corrección; `reports/reproducibility.json` apunta al resultado de verificación actual. No se han refrescado `content-baseline.json`, `source-manifest.json`, `snapshots`, rutas, requisitos o field-map.

Los archivos binarios de campaña se comprobaron al preparar el inventario. Offline se valida su existencia documentada, hash de referencia, dimensiones y aprobación; `--live` detecta eliminación o cambio local. No descarga imágenes de Shopify ni demuestra disponibilidad en CDN.

```sh
node tools/style-guideline-content/audit.mjs \
  --data-dir docs/style-guideline-migration/content-readiness \
  --out-dir tools/style-guideline-content/resultados
```

Las salidas deben permanecer dentro de `tools/style-guideline-content/` o `docs/style-guideline-migration/content-readiness/`. Las pruebas usan un directorio temporal propio dentro de `tools/style-guideline-content/` y lo borran al terminar.

| Exit code | Significado |
| --- | --- |
| `0` | Informe generado correctamente, aunque describa contenido pendiente. |
| `1` | Sólo con `--strict`: hay pendientes/errores de preparación o deriva local. Es el resultado esperado para esta baseline. |
| `2` | Error de argumentos, entrada ilegible/JSON inválido o fallo de ejecución. |

Los resultados offline no contienen el reloj de ejecución: fecha de captura y hash de entradas estables permiten comparar dos ejecuciones byte por byte. La comparación live sí añade su hora. El SHA de entradas describe datos/esquema/manifiesto; conservar la versión del auditor junto a los resultados.

## Qué comprueba

- Campos requeridos, tipos, enums, IDs duplicados y focales fuera de 0..1.
- Referencias exactas a fuentes congeladas y SHA-256 del texto.
- Destinos ausentes, propuestos, sin respaldo o con tipo incorrecto; destinos incompatibles con su slot.
- Separación Bolsas `guess` / marca Guess `guess-1`, incluso si se retira el guard dentro de una ruta.
- Catálogos HTTPS con host exacto, modalidad y restricciones de compartir; no confía en dominios que sólo contienen el nombre permitido.
- Coincidencia entre categoría/modalidad del catálogo y las del destino registrado. Compartir se valida contra la modalidad del destino; metadata ausente genera incertidumbre explícita.
- Falta de recursos, aprobación/crops, portada distinta del logo y campos de campaña por tamaño.
- Diferencias de selección/orden, módulos home, contenido por pantalla, capacidades registradas y layouts de plantillas.
- Fuentes `collection` con una colección existente y tipada; `curated` con exactamente una colección o handles explícitos válidos; recomendaciones/providers legítimos sin una ruta obligatoria artificial.
- Compatibilidad `kind/contentRef`, familia de contenido y estructura V1 completa de los ocho tipos de módulo, incluidas sus listas.
- Conservación del modelo MXN/autoridad de Rewards y exclusión de precios/stock/puntos del contenido editorial.

Los estados de capacidad y las decisiones son datos revisables respaldados por fuentes. El auditor no demuestra la implementación de una nueva capacidad sólo porque alguien cambie su etiqueta. Requieren nueva evidencia y revisión de integración. Los hallazgos pueden describir varias consecuencias del mismo trabajo pendiente; no son un conteo de tickets ni de defectos desplegados.

El validador implementa el vocabulario usado por el esquema entregado: `$ref` local, `type`, `required`, `properties`, `additionalProperties`, `const`, `enum`, `minLength`, `pattern`, `minimum`, `maximum`, `items`, `minItems`, `uniqueItems`, **`anyOf` y `oneOf`**. `anyOf` exige al menos una rama válida y `oneOf` exactamente una; ambas conservan el root para referencias locales anidadas. Las regresiones se ejecutan contra el esquema V1 real y fixtures reducidos. No se presenta como implementación completa de JSON Schema. Si se amplía el esquema con otro vocabulario, ampliar/validar el motor a la vez. No resuelve referencias por red.

## Verificar la corrección de la revisión independiente

```sh
node tools/style-guideline-content/verify-corrections.mjs
```

El comando ejecuta únicamente las pruebas Node propias; compara en memoria las cuatro reproducciones con el auditor/esquema 1.0.0 archivados y los corregidos; ejecuta CLI normal dos veces, estricto y comparación local; verifica identidad byte por byte de JSON/Markdown y registra huellas de implementación. Comprueba además los 109 archivos de datos congelados, el archivo de las 35 pruebas originales y los 24 archivos archivados. No utiliza Git para restaurar archivos.

La suite contiene **81 pruebas**: las 35 originales sin cambiar y 46 nuevas. En la ejecución previa al fix, 34 de las 46 nuevas fallaron y 12 controles pasaron. Esas salidas quedan en `reports/correction-1.0.1/regressions-before.tap`; las pruebas actuales, en `tests.tap`. `reproductions.md`/`reproductions-after.json` muestran códigos y paths concretos por reproducción; `verification.json` conserva comandos, exit codes, hashes, preservación y deriva posterior. Los fixtures de familias son datos de prueba, sin términos comerciales nuevos.

La baseline sin mutaciones sigue produciendo 47 errores y 196 avisos: las parejas originales son válidas y los campos ausentes ya eran hallazgos. Las mutaciones ahora sí añaden errores específicos. Los totales se registran desde la ejecución; no se compensan ni se fijan en el auditor. La comparación posterior puede detectar cambios de otras sesiones y no actualiza los hechos de la captura.

## Captura y mantenimiento

```sh
# Añade fuentes de source-list.json aún no capturadas; preserva capturas existentes.
node tools/style-guideline-content/capture-sources.mjs
# Reconstruye sólo route-map.json desde la captura original, sin consultar la tienda.
node tools/style-guideline-content/build-inventory.mjs
```

`source-list.json` es una lista explícita de fuentes públicas del proyecto, no configuración secreta. La captura no lee `.env` ni `dart_defines` reales. El generador de rutas exige anchors exactos y recuentos conocidos; si cambian los seeds hay que revisar su interpretación. Las propuestas/editoriales de ese generador describen esta revisión fechada y no sustituyen una revisión comercial posterior.

Para una auditoría nueva, conservar este conjunto, crear otro directorio de datos bajo los dos árboles permitidos y preparar un manifiesto/snapshots coherentes con `captureSources()` exportado. Revisar datos, anchors, estados y requisitos; ejecutar con `--data-dir`. No borrar o refrescar silenciosamente la captura inicial mientras otra sesión modifica las fuentes.

No hay comprobaciones remotas en esta entrega. Un `httpStatus:200` añadido a una ruta no la certifica. Una alegación de revisión de catálogo exige documento capturado identificado como `remote_catalog_snapshot`, categoría/modalidad coincidentes, alcance `document_content`, fecha y responsable; una URL local o una respuesta de login no satisfacen esa condición. Respuestas 401/403, contraseña, rate limit o restricción de proveedor permanecen desconocidas; no se clasifican como enlace roto.

La documentación de integración está en [REPORT.md](../../docs/style-guideline-migration/content-readiness/REPORT.md) y [CONTENT_CONTRACT.md](../../docs/style-guideline-migration/content-readiness/CONTENT_CONTRACT.md).
