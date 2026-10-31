# Revisión y ajustes después de generar la vista previa

Esta fase se ejecuta cuando exista la salida del modelo generador. No constituye una revisión ya realizada.

## Encargo para retomar conmigo

> Revisa la vista previa en `artifacts/monetta-motion-preview-2026-10-27/` usando la investigación de `docs/research/monetta-motion-2026-10-27/`. Arranca su servidor, prueba las veinte opciones y las tres escenas completas. Comprueba el logo A/B contra el PNG original, movimiento reducido, teclado, interrupciones y estados de error. Haz los ajustes de diseño y código necesarios dentro de la vista previa; conserva el trabajo original y entrega un antes/después con evidencia. Todavía no integres ni publiques en la app o Shopify. Explica qué opciones recomiendas conservar y por qué.

## Orden de revisión y correcciones previstas

| Prioridad | Criterio | Ajuste si falla |
|---|---|---|
| Bloqueante | Logo original, siete letras, dos T distinguibles, final fiel. | Corregir máscaras/recorridos. Si B deforma letras, mantener A como ganadora y dejar B experimental. |
| Bloqueante | Comenzar funciona durante la escritura; no hay espera decorativa. | Cancelar el efecto al navegar; retirar bloqueo o una segunda entrada. |
| Bloqueante | Éxito, precios, cantidad y disponibilidad corresponden al estado confirmado. | Corregir lógica antes de pulir movimiento; quitar éxito anticipado. |
| Bloqueante | Movimiento reducido sin efectos, mismo contenido/acciones y respuesta al cambio de preferencia. | Centralizar política; cancelar controladores/timers activos y mostrar estado final. |
| Alta | Reposo durante 10 s: nada decorativo sigue moviéndose. | Eliminar repeat/autoplay y efectos activados por hover persistente. |
| Alta | Reabrir/cancelar/transicionar rápidamente no deja capas, bloqueo o foco perdido. | Hacer cancelables las transiciones y restaurar estado/foco; evitar timers de cierre obsoletos. |
| Alta | Una confirmación dominante por acción. | Elegir check o panel; dejar badge estático si compite. |
| Alta | El área táctil y el texto no se mueven bajo el dedo. | Animar contenido interno, reservar dimensiones y retirar cambios de layout innecesarios. |
| Media | Galería clara, sin mezclar imágenes/productos ni destellos al cargar. | Esperar decodificación, descartar respuestas viejas y reducir el crossfade. |
| Media | Logo se siente elegante a tamaño real, no como terminal o anuncio. | Quitar cursor, rebotes, brillo; ajustar pausas entre letras y acortar duración si se percibe lenta. |
| Media | Navegación mantiene continuidad y gesto de regreso. | Mantener transición nativa; descartar foto compartida si complica el retorno o duplica movimiento. |
| Media | Escena completa se siente tranquila. | Desactivar entrada editorial durante logo y retirar efectos de menor utilidad aunque funcionen aislados. |

## Evidencia que debe quedar

1. `REVISION.md` con hallazgo → cambio → comprobación, por ID de animación.
2. Capturas antes/después a 390 px y una vista amplia; frames intermedios del logo y paneles.
3. Video o secuencia temporal reproducible de bienvenida → catálogo → producto → agregar, además de error y movimiento reducido.
4. Registro de verificaciones realizadas y pendientes. No atribuir tasas de cuadros de dispositivo físico a pruebas de escritorio.
5. Selección final pequeña de efectos para integración. Descartar explícitamente efectos redundantes.

## Paso posterior: integración en Flutter

Después de revisar la vista previa, portar los efectos seleccionados sin cambiar los contratos de catálogo, carrito, checkout o cuentas. Comenzar por logo/bienvenida y feedback de compra; continuar con paneles/galería y filtros. Usar los tokens existentes y la API disponible en Flutter 3.44.8. Revisar la cobertura real de Reduce Motion en iOS y Remove animations en Android, incluyendo cambios en caliente.

Las pruebas relevantes son cancelación/dispose del logo, no repetición al reconstruir, interacción antes de finalizar, doble toque al agregar, error sin falso éxito, respuestas fuera de orden y foco en paneles. No basta con golden tests: el helper `reduceMotion` del repositorio devuelve true en widget tests, de modo que también hace falta una prueba que ejercite la ruta animada y validación de integración en dispositivo.

Para rendimiento, perfilar una compilación profile en un teléfono representativo con Flutter DevTools. Reportar frames UI/raster y pausas; tomar 16.7 ms como presupuesto de un display a 60 Hz y 8.3 ms para 120 Hz, no como una medición ya obtenida. Reducir máscaras/capas costosas si incumplen el objetivo.

Para utilidad, comparar estático/propuesto con las mismas tareas: buscar bolsa, filtrar, guardar, cambiar variante, agregar y corregir error. Observar tiempo, dudas, dobles toques y comprensión del estado. No prometer una mejora de conversión sin un experimento posterior.
