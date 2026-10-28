# Plan de capturas · simulador Monetta Duo Implementation

Quién las toma: el coordinador, en el Mac del owner. Esta sesión está en un Linux sin simulador de iOS y **no fabricó ninguna imagen**. Las nueve que ya existen se citan en `captures.json`. Etiqueta de todo lo que salga de este plan: **simulator**. No es hardware.

Aparato: `Monetta Duo Implementation`, UUID `A38CDB10-3E59-4575-A58C-4E1072B8A4CC`, iOS 27.1, Xcode 27.1. Una sola ventana de Device Hub. No hace falta descargar otro runtime: el reporte de implementación ya lo dejó instalado.

Comercio en vivo: no. El target de drive usa `config/dart_defines.ci.json`, que deja el comercio apagado. No se usa el JSON de staging en este plan y no se copia ningún define al repo.

## Qué ya no hay que repetir

Estas nueve imágenes están en `artifacts/iphone-duo/runtime-captures/` y sus SHA-256 coinciden con `resume-runtime-summary.json` (comprobado en esta revisión):

| Archivo | Postura | Pantalla |
|---|---|---|
| `01-actual-duo-outer-inicio-fixture-photos.png` | P1 | Inicio |
| `02-actual-duo-outer-product-fixture-photos.png` | P1 | Producto |
| `03-actual-duo-landscape-browse-detail-fixture-photos.png` | P3 | Catálogo + detalle |
| `04-actual-duo-landscape-direct-product-fixture-photos.png` | P3 | Producto directo |
| `05-actual-duo-partial-fold-product-fixture-photos.png` | P5 | Producto |
| `06-actual-duo-inner-portrait-product-fixture-photos.png` | P4 | Producto (división inactiva, no es P6) |
| `07-actual-duo-outer-cart-fixture-photos.png` | P2 | Carrito |
| `08a-actual-duo-accessibility-cart-heading-fixture-photos.png` | P2 | Carrito, texto muy grande, encabezado |
| `08-actual-duo-accessibility-cart-fixture-photos.png` | P2 | Carrito, texto muy grande, cantidad |

Fotos de relleno: el test asigna `debugMonettaFixtureImage` a `assets/images/home_bag_crossbody.webp` (`integration_test/duo_shopping_task_test.dart:25-26`). No son el catálogo en red.

## Invocación que ya está en el repo

Desde la raíz del repo, con FVM, en el simulador dedicado:

```sh
fvm flutter drive --no-pub \
  -d A38CDB10-3E59-4575-A58C-4E1072B8A4CC \
  --driver=test_driver/iphone_duo_driver.dart \
  --target=integration_test/duo_shopping_task_test.dart \
  --dart-define-from-file=config/dart_defines.ci.json
```

El driver escribe el PNG en `artifacts/iphone-duo/runtime-captures/<nombre>.png` (`test_driver/iphone_duo_driver.dart:6-12`). El test imprime `DUO_STAGE` y `DUO_CAPTURE_CONTEXT` (`integration_test/duo_shopping_task_test.dart:57-107`).

Poses, a mano en Device Hub, cuando el log llegue al marcador (`docs/IPHONE_DUO_IMPLEMENTATION_REPORT.md`, sección del recorrido):

| Marcador | Qué hacer en Device Hub | Predicado que el test espera |
|---|---|---|
| `outer` | Cerrado, exterior vertical | `supported`, sin divisiones, `barEdge != none` |
| `open-landscape` | Abrir y dejar interior horizontal | `canSplit`, más ancho que alto, divisiones inactivas |
| `partial-fold` | Plegar en libro, sin rotar a vertical | alguna división activa y no vacía |
| `open-flat` | Volver a abrir plano | todas las divisiones inactivas |
| `inner-portrait` | Rotar a interior vertical | más alto que ancho, hay divisiones, `barEdge == none` |
| `closed-again` | Cerrar | sin divisiones, `barEdge != none` |
| `accessibility-text` | Subir el texto del sistema a `accessibility-extra-extra-extra-large` | `scale(16) > 24` |

El reporte dice que el tamaño de texto se cambia «for example with `simctl ui`». **No quedó el argv exacto** en el repo. Usar el mismo comando que produjo la captura 08. No inventar otro flag.

`simctl` que sí se puede usar para una foto manual, fuera del driver:

```sh
xcrun simctl io A38CDB10-3E59-4575-A58C-4E1072B8A4CC screenshot \
  docs/iphone-duo-postures/captures/<archivo>.png
```

Eso es una inferencia de `simctl io screenshot`. No sustituye el JSON de geometría. Si no hay un `DUO_CAPTURE_CONTEXT` en el log, los campos de geometría se dejan `null` y `geometryStatus` queda `pending`. No se rellenan con los números de otra pose.

## Hueco del target actual

`duo_shopping_task_test.dart` no abre Welcome, Búsqueda, Filtros, Vista rápida, Guardados, Cuenta, Pedidos ni la hoja de Shopify. Tampoco pliega en vertical. Ampliar el target sería un cambio de código de prueba: está en el backlog (DUO-23) y **no se hace en esta rama**. Hasta entonces las capturas nuevas son manuales: la app de ese mismo `flutter drive` o una corrida debug con los defines de CI, navegar, y `simctl io screenshot`.

Cada archivo nuevo va a `docs/iphone-duo-postures/captures/` con el nombre de abajo. No se commitean el runtime, `build/` ni un export del simulador.

## Comprobaciones de pose (antes de diseñar encima)

**P6.** Después de que el log muestre `inner-portrait` (669 × 951, banda horizontal inactiva, `barEdge none` en la corrida anterior), plegar en Device Hub **sin** rotar a apaisado. Anotar el `DUO_GEOMETRY` siguiente.

- Activa, ancho de la banda ≥ 0,8 del ancho, ventana más alta que ancha: guardar `p6-seated-product.png` y poner `postureConfirmed: true`.
- Si no se puede, o la ventana pasa a 951 × 669, o la banda sigue inactiva: no guardar una imagen con nombre de P6. Anotar el rechazo en el JSON con `capture: null` y `postureConfirmed: false`.

**P7.** Si Device Hub tiene una pose de canto o tienda, una sola foto `p7-stand-whatever-the-host-shows.png` más el JSON. Si no hay pose, no se inventa la foto; `postureConfirmed: false`.

**P8.** Split View con Monetta a la izquierda y a la derecha, y los dos extremos de tamaño que Device Hub permita. Nombres: `p8-split-left-catalog.png`, `p8-split-right-catalog.png`, `p8-narrow-product.png`, `p8-wide-product.png`. Anotar `barEdge` de cada una. Slide Over: solo si Device Hub muestra un control con ese nombre. Si no aparece, `slideOver: "not found in Device Hub on this pass"` y sin imagen.

**P9.** No hace falta una captura de dos pantallas para el lanzamiento. Si al abrir el interior el exterior muestra otra cosa que el wallpaper del sistema, una foto y una nota. No se diseña encima.

**P10.** Durante el drive ya existente, no hace falta otra pose. Sí hace falta, cuando exista target nuevo, un frame con teclado, uno con hoja de filtros y uno con «AGREGANDO…». Esos tres no están en el target de hoy.

## Lista a tomar (P1–P8)

Nombre de archivo, sin inventar la imagen ahora. Texto de sistema por defecto, salvo la fila que dice AX.

| Postura | Pantalla | Archivo | Cómo |
|---|---|---|---|
| P1 | Welcome, frame 0 con «Comenzar» | `p1-welcome.png` | Manual. El drive actual salta la bienvenida con el botón (`duo_shopping_task_test.dart:32-42`). |
| P1 | Búsqueda | `p1-search.png` | Manual |
| P1 | Filtros abiertos | `p1-filters.png` | Manual |
| P1 | Vista rápida | `p1-quick-view.png` | Manual |
| P1 | Guardados | `p1-guardados.png` | Manual |
| P1 | Cuenta | `p1-cuenta.png` | Manual |
| P1 | Pedidos | `p1-pedidos.png` | Manual |
| P1 | Carrito | `p1-cart.png` | Manual. La captura 07 es P2, no P1. |
| P2 | Inicio | `p2-inicio.png` | Manual, exterior horizontal |
| P2 | Producto | `p2-product.png` | Manual |
| P2 | Búsqueda con teclado | `p2-search-keyboard.png` | Manual |
| P3 | Welcome | `p3-welcome.png` | Manual, interior horizontal plano |
| P3 | Inicio | `p3-inicio.png` | Manual |
| P3 | Búsqueda | `p3-search.png` | Manual |
| P3 | Filtros | `p3-filters.png` | Manual |
| P3 | Guardados | `p3-guardados.png` | Manual |
| P3 | Carrito | `p3-cart.png` | Manual |
| P3 | Cuenta | `p3-cuenta.png` | Manual |
| P4 | Welcome | `p4-welcome.png` | Manual, interior vertical plano |
| P4 | Inicio | `p4-inicio.png` | Manual |
| P4 | Catálogo sin pieza elegida | `p4-catalog.png` | Manual |
| P4 | Carrito | `p4-cart.png` | Manual |
| P4 | Cuenta | `p4-cuenta.png` | Manual |
| P5 | Catálogo + detalle | `p5-browse-detail.png` | Manual, libro. La 05 es la ficha directa. |
| P5 | Carrito | `p5-cart.png` | Manual |
| P5 | Filtros | `p5-filters.png` | Manual |
| P6 | Producto, solo si el check confirma | `p6-seated-product.png` | Device Hub, ver arriba |
| P6 | Welcome, solo si el check confirma | `p6-seated-welcome.png` | Igual |
| P7 | Lo que el host muestre, solo si hay pose | `p7-stand.png` | Device Hub |
| P8 | Las cuatro de Split View de arriba | `p8-*.png` | Device Hub |
| P2 | Carrito ya existe en AX | no repetir 08 y 08a | — |
| P1 | Inicio y producto ya existen | no repetir 01 y 02 | — |
| P3 | Browse y directo ya existen | no repetir 03 y 04 | — |
| P4 | Producto ya existe | no repetir 06 | — |
| P5 | Producto ya existe | no repetir 05 | — |

Modo oscuro, Bold Text, Increase Contrast, Reduce Motion y Reduce Transparency: una pasada extra de P1 Inicio y P3 producto cuando las anteriores estén. Nombres `p1-inicio-dark.png`, `p3-product-reduce-motion.png`, etc. VoiceOver no se captura con una foto; va al guion de hardware.

## Esquema del JSON

Un objeto por toma. El driver de hoy emite solo una parte; el resto se llena a mano o queda `null`.

```json
{
  "id": "p3-inicio",
  "label": "simulator",
  "posture": "P3",
  "screen": "inicio",
  "file": "docs/iphone-duo-postures/captures/p3-inicio.png",
  "sha256": null,
  "textScale": { "base": 16, "scaled": null },
  "geometry": {
    "size": [null, null],
    "barEdge": null,
    "safeInsets": { "left": null, "top": null, "right": null, "bottom": null },
    "divisions": [],
    "occlusions": []
  },
  "geometryStatus": "pending",
  "sourceLog": null,
  "notes": ""
}
```

`sha256` es del PNG, hex en minúsculas. `scaled` es `TextScaler.scale(16)`, el mismo número que imprime `DUO_CAPTURE_CONTEXT`. `divisions` y `occlusions` usan `active` y `frame` `[x, y, width, height]` como el log de etapas. El contexto de captura actual **no** imprime divisiones ni oclusiones (`duo_shopping_task_test.dart:92-105`); si la foto es manual y no hay otro log, `geometryStatus` es `pending`, no se copian los números de `resume-runtime-summary.json` de otra pantalla.

Después de guardar el PNG:

```sh
shasum -a 256 docs/iphone-duo-postures/captures/<archivo>.png
```

Añadir la entrada a `captures.json`. No marcar `label` como hardware.
