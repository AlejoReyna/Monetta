# Monetta en iPhone Duo · posturas

Resumen de una página. El detalle está en los otros archivos de esta carpeta. El logo de Welcome lo revisa el Director de Movimiento; aquí solo queda especificada su conducta.

Nada de esto está verificado en hardware, ni listo para el App Store, ni aprobado como insignia.

## Verificado (simulator)

Simulador `Monetta Duo Implementation`, iOS 27.1. Evidencia ya en el repo, no tomada en esta sesión:

- P1 exterior vertical, 466 × 678, riel a la derecha. Inicio y ficha.
- P2 exterior horizontal, 678 × 466. El carrito se capturó con el riel a la **izquierda**; la etapa `closed-again` anotó la derecha. Los dos registros valen.
- P3 interior horizontal plano, 951 × 669, banda vertical inactiva. Colección junto a la ficha, y ficha directa.
- P4 interior vertical plano, 669 × 951, barras horizontales, banda horizontal **inactiva**.
- P5 libro, la misma ventana que P3 con la banda **activa**.
- Una sesión de compra sobrevivió a esa secuencia y agregó una sola unidad. Texto muy grande solo en el carrito de P2.
- Oclusiones del exterior vertical, en el log del spike, no en la foto.

Los 84 pt y los 40 pt son de esa corrida. No son constantes.

## Especificado (design)

- Cada postura × cada pantalla de la tienda, más la regla de Rewards, Notificaciones, Ajustes, Mayoreo, Contacto, About y Admin.
- La tarea firma en todas, incluido el tránsito (P10).
- El logo se escribe una vez por instalación, en la primera bienvenida, y queda guardado en el aparato. Lo decidió Alexis el 28 oct 2026. No vuelve a animarse al recargar ni en un arranque en frío. La investigación está en `fbeac82`; los cortes de letra son los de la spec corregida 28-oct-2026. El 30/132 de la M está confirmado.
- «Comenzar» desde el primer frame, fuera de oclusiones y de divisiones activas. En P6 va abajo del corte si ese corte existe; en P7 sigue a la geometría que reporte el host; en P8 sigue el borde de **esa** ventana; en P9 no hay un segundo botón.
- Crossfade de 180 ms solo al cambiar la pieza del panel o al mostrar y ocultar ese panel por una acción. El pliegue lo anima el sistema.
- El pago y la bolsa viven en el coordinador, el controlador y el store. El layout no dispara agregado, checkout ni login. **Pendiente de revisión del tester de pagos.** El pago no está listo.

## Provisional, supuesto o no verificable

- **P6, provisional.** Apple describe apoyar el aparato en la mesa (HIG y tech talk 111463). Este simulador no mostró una división horizontal activa. Falta el check de `captures/CAPTURE_PLAN.md`. Hasta entonces el panel sentado del tablero es **concept**.
- **P9, diferido.** Apple permite un accessory de cámara en las dos pantallas (tech talk 111464). Monetta no lo usa en este lanzamiento. Una escena, una bolsa.
- **P7.** Apple dice «de canto». No dice qué pantalla mira a la persona. Sin modo propio.
- **Slide Over.** La frase no está en las páginas consultadas. Sin diseño hasta ver si Device Hub lo tiene.
- VoiceOver, alcance real, hoja de Shopify al plegar y la memoria al plegar muchas veces: hardware, guion sin ejecutar.
- Los cortes internos del logo en 3x ya están medidos: E se separa de la T en 262/263; T/T/A en 303/304 y 330/331. Esos dos últimos caen en valles de tinta. La segunda T y la A se tocan: el corte es el de menor masa de alfa, y el extremo del travesaño de esa T aparece con la A.

## Archivos

| Archivo | Qué es |
|---|---|
| `POSTURES.md` | Inventario con fuente |
| `DESIGN_SPEC.md` | Matriz y reglas |
| `board/` | Tablero **concept** (SVG y PNG) |
| `captures/` | Plan para el Mac, y JSON solo de la evidencia que ya existe |
| `GAP_ANALYSIS.md` | Huecos con archivo y línea |
| `IMPLEMENTATION_PLAN.md` | DUO-11 en adelante |
| `HARDWARE_TEST_SCRIPT.md` | Guion físico, cada paso sin verificar |

## Decisiones P6 y P9

P6 se diseña como respuesta a una división horizontal activa y queda provisional hasta el check del simulador. P9 no entra al lanzamiento: no hay tienda en las dos pantallas a la vez.
