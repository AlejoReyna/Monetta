# Monetta: investigación visual y decisiones de movimiento

27 de octubre de 2026 · Segunda investigación, que sustituye las recomendaciones de la primera.

**Decisión:** construir una experiencia que comunique cambios con poco movimiento. Priorizar confirmación de compra, paneles, inspección de fotografías y selección. El logo es una excepción de identidad solicitada por el usuario, no una supuesta mejora de conversión. Ningún efecto queda justificado únicamente por existir en otra tienda.

Esta entrega evalúa **20 candidatos**, con referencia concreta y decisión. No recomienda implementar veinte animaciones. Hay patrones que conviene conservar estáticos y variantes que solo merecen un experimento.

## Qué evidencia se obtuvo realmente

Se descargaron para análisis clips públicos enlazados por sus autores, se extrajeron fotogramas con tiempos y se inspeccionaron visualmente. El [visor de referencias](index.html) permite consultar las hojas de fotogramas y abrir las fuentes/reproductores. El [registro](evidence/sources.json) conserva procedencia y limitaciones.

**Esto es inspección de demostraciones grabadas, no una auditoría de las aplicaciones nativas actuales.** Los casos comerciales son sitios de comercio electrónico y los demos de Motion son ejemplos técnicos. No se deducen curvas exactas, accesibilidad, latencia real o rendimiento de una grabación promocional. Los tiempos recomendados abajo son decisiones para Monetta, no mediciones de los competidores.

Se preserva la investigación anterior como historial. Se revisaron nuevamente `lib/app/motion.dart` y el estado del repositorio; no se modificó código de producto. Los hallazgos previos de bienvenida, logo y reseñas se usan como contexto de implementación, no como evidencia externa.

## Casos comerciales: observación frente a inferencia

### Jo Loves / Limesharp, lanzamiento documentado en 2020

[Caso del autor](https://limesharp.net/projects/jo-loves-2019). El autor distingue descubrimiento de nuevos clientes y compra rápida de recurrentes; reporta +70% de conversión móvil y +30% global para el proyecto completo. Son cifras del proveedor, sin experimento aislado de animación ni validación independiente: **no atribuirlas al movimiento**.

| Ref. | Clip de la página, con ventana de inspección | Observación |
|---|---|---|
| J1 | `910873603`, 12–29 s | Listado, incorporación a bolsa y panel derecho sobre fondo atenuado; cambia su contenido. |
| J2 | `910873603`, 35–48 s | Panel de filtros con categorías y opciones sobre el listado. |
| J3 | `910873554`, 0–15 s | Fotografía de producto y contenido editorial cambian durante el recorrido. |
| J4 | `910873683`, 0–9 s | Menú lateral; conserva visible parte de la composición de origen. |
| J5 | `910873713`, 0–4 s | Imágenes de ingredientes aparecen sobre la lista al recorrerla. |

Adaptación propuesta: contexto espacial en paneles y consulta deliberada de imágenes. No trasladar los fondos móviles de la presentación, sus encuadres ni los adornos de ingredientes al catálogo de bolsas.

### Paul Smith / Limesharp, rediseño documentado en 2025

[Caso del autor](https://limesharp.net/projects/paul-smith-2025-redesign). El caso explica simplificación de tarjetas, uso contenido del color y exposición de información importante que antes se perdía en paneles desplegables. Apoya reducir complejidad antes de añadir efectos.

| Ref. | Reproductor público | Observación |
|---|---|---|
| P1 | [ps7](https://player.vimeo.com/video/1181182346), 0–12 s | Recorrido de ficha: fotos, selector visual de variantes y ampliación de detalle. |
| P2 | [ps9](https://player.vimeo.com/video/1181192926), 0–9 s | Dos composiciones móviles; en la ficha aparecen información, selección y un control inferior persistente. |
| P3 | [montaje](https://player.vimeo.com/video/1181178813), 0–6 s | Presentación de varias pantallas. No sirve para inferir transiciones de navegación reales. |

Adaptación propuesta: selección identificable, fotografía protagonista y acción estable. No imitar la densidad del escritorio en un teléfono ni confundir cortes de edición del video con animaciones de la interfaz.

### Material revisado y excluido

- [Christopher Ward / Limesharp](https://limesharp.net/projects/christopher-ward): los cinco clips revisados muestran comunicaciones de email/CRM. Aunque es una marca de relojes pertinente, no prueba cómo se anima una aplicación. Se conserva como ejemplo de descarte metodológico.
- [NET-A-PORTER / One Darnley Road](https://www.onedarnleyroad.com/work/net-a-porter): caso histórico con intro de app y wishlist. Se consultó la descripción, pero no se verificó visualmente su película en esta revisión; no sustenta ninguna implementación.
- Dribbble de Jo Loves: la descripción fue accesible, pero la descarga directa devolvió una respuesta vacía. Se utilizó el material público del propio estudio, sin presentar la ficha de Dribbble como un video observado.
- Algunos resultados de Motion incluyen videos de ejemplos relacionados. Se comprobó la correspondencia del identificador del clip con la página y se descartaron los que no tenían un clip propio. Un título correcto junto a un video equivocado no es evidencia.

## Principios que gobiernan todas las decisiones

1. **Utilidad antes que apariencia:** describir qué debe entender la persona: acción recibida, estado confirmado, selección o ubicación. Si el efecto no comunica nada adicional, elegir el estado estático.
2. **Minimalismo funcional:** conservar etiquetas, precios, disponibilidad y acciones; reducir señales competidoras. Minimalismo no equivale a ocultar controles. [NN/g, estética y minimalismo](https://www.nngroup.com/articles/aesthetic-minimalist-design/).
3. **Atención proporcional:** un efecto local para una acción local. No arrastrar la mirada hasta una esquina para confirmar un toque. Considerar propósito, frecuencia y disparador antes de animar. [NN/g, atención y comprensión](https://www.nngroup.com/articles/animation-usability/).
4. **Orientación:** un panel temporal puede entrar desde un borde; el catálogo de debajo permanece reconocible. No cambiar toda la pantalla para señalar una selección. [NN/g, propósito de la animación](https://www.nngroup.com/articles/animation-purpose-ux/).
5. **Control:** interrumpible, sin espera artificial, respetando reducir movimiento. WCAG 2.3.3 es AAA; se adopta como criterio de diseño, sin confundirlo con una certificación de conformidad. [W3C](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html).
6. **Reposo real:** cero animaciones decorativas cuando no hay interacción. Galerías/reseñas manuales. La alternativa estática puede evitar problemas de carruseles y es más sencilla de implementar correctamente. [Baymard](https://baymard.com/research-articles/homepage-carousel).
7. **Verdad transaccional:** completar animación no significa completar compra. Estados y mensajes dependen de la operación real; una simulación se etiqueta como tal.

## Veinte candidatos y su justificación

R = recomendado para primera comparación con versión estática. C = condicionado a una necesidad o prueba. X = descartado en la primera implementación. No son resultados de pruebas con usuarios de Monetta.

### 01 · Confirmación local al agregar — R

**Referencia visible:** [Multi state badge](https://motion.dev/examples/vue-multi-state-badge), clip 0–1.97 s: Processing → Done → error → Start; [Copy Button](https://motion.dev/examples/vue-copy-button), 0–1.12 s, conserva la confirmación dentro del control. Demos técnicas, no tiendas.

**Problema / diseño:** después de tocar Agregar, la persona necesita saber si se recibió y confirmó la acción. Mantener la respuesta en el mismo lugar conserva proximidad y jerarquía.

**Minimalismo / alternativa:** «Agregado» estático podría bastar. Probar un cambio de icono/opacidad de 180 ms, sin cambiar el ancho del botón. No combinar check, toast, badge rebotando y panel automático.

**Implementación / criterio:** estados idle/pending/success/error; éxito solo con confirmación de carrito; doble toque no duplica la operación. Conservar si disminuyen dudas/dobles toques sin retrasar la compra; si no, usar solo texto.

### 02 · Bolsa que entra como panel — R

**Referencia visible:** J1, especialmente 17–20 s. [Fotogramas detallados](evidence/jo-loves-cart-detail.jpg).

**Problema / diseño:** consultar la bolsa sin perder el producto. La capa temporal y el fondo atenuado explican la relación espacial.

**Minimalismo / alternativa:** conservar una página de bolsa si ya resuelve mejor la tarea. Si se usa panel: 280 ms de entrada y salida, un único scrim, sin mover ni reducir la pantalla de fondo.

**Implementación / criterio:** reutilizar la hoja existente, no duplicarla. Foco, cierre, gesto y regreso al invocador; abrir/cerrar/reabrir durante la transición debe funcionar. Si se abre automáticamente al agregar, evitar otra celebración de #01.

### 03 · Filtros en panel reversible — R

**Referencia visible:** J2, 35–48 s.

**Problema / diseño:** editar criterios sin confundir filtros con otra página. El listado visible detrás conserva contexto; aplicar explícitamente permite revisar varias opciones.

**Minimalismo / alternativa:** en una pantalla de filtros nativa ya clara, mantener la transición del sistema. En panel propio, 280 ms; no animar cada categoría ni todos los resultados al cerrar.

**Implementación / criterio:** mantener selección y foco; mostrar cantidad de resultados con texto. La prueba debe confirmar que cerrar y volver no pierde los filtros. No trasladar literalmente el ancho del panel de escritorio al móvil.

### 04 · Galería manual con miniaturas — R

**Referencia visible:** [Carousel: Thumbnail gallery](https://motion.dev/examples/vue-carousel-thumbnail-gallery), 0.09–1.55 s del clip propio; las imágenes y miniaturas cambian coordinadamente.

**Problema / diseño:** explorar ángulos de una bolsa y saber qué fotografía se está viendo. Deslizamiento horizontal coherente con el gesto.

**Minimalismo / alternativa:** la foto estática más miniaturas también es válida. En toque de miniatura, transición de hasta 280 ms; arrastre sigue al dedo. No autoplay, parallax, inclinación 3D ni rebote.

**Implementación / criterio:** conservar imagen anterior hasta decodificar la nueva y descartar respuestas obsoletas. Evaluar encontrar bolsillo/cierre en la foto; no basta con que el carrusel se vea fluido.

### 05 · Ampliación de fotografía — R

**Referencia visible:** [Carousel: Lightbox](https://motion.dev/examples/vue-carousel-lightbox), 0–1.2 s, foto ampliada y regreso; P1, tramo final, acercamiento al detalle.

**Problema / diseño:** inspeccionar textura, costuras y herrajes. La continuidad de la misma imagen explica que es una ampliación, no otro producto.

**Minimalismo / alternativa:** abrir un visor inmediato es suficiente con movimiento reducido. Probar 180–280 ms, una sola imagen; botón Cerrar siempre visible, sin controles ornamentales.

**Implementación / criterio:** mantener índice/zoom y devolver foco; no usar una miniatura borrosa como imagen de alta resolución. Conservar si mejora orientación al volver sin aumentar tiempo de inspección.

### 06 · Cambio de variante con fotografía estable — R

**Referencia visible:** P1, aproximadamente 4–9 s, variantes visuales junto a la ficha y cambio de imagen.

**Problema / diseño:** saber qué color/modelo se comprará. Selección, nombre, foto y disponibilidad deben corresponder; el movimiento es secundario.

**Minimalismo / alternativa:** check/borde inmediato en el selector; fundido opcional de 180 ms solo en la foto nueva. Precio se actualiza legiblemente, sin contar números ni animar la ficha entera.

**Implementación / criterio:** manejar carga/error y cambios rápidos; nunca dejar que la foto de una respuesta antigua sustituya la selección vigente. Si el fundido mezcla dos colores de forma ambigua, quitarlo.

### 07 · Presión breve en el botón — C

**Referencia visible:** [Svelte: Press](https://motion.dev/examples/svelte-press), 0.07–0.49 s, contracción y recuperación del cuadrado.

**Problema / diseño:** confirmar contacto antes de la respuesta de red. La deformación pequeña puede dar sensación de control directo.

**Minimalismo / alternativa:** el feedback del botón nativo suele bastar. No copiar la amplitud 0.8 del demo; probar 0.985→1, 180 ms y sin rebote.

**Implementación / criterio:** el área táctil no cambia. Cancelar al arrastrar fuera. Añadir únicamente donde la respuesta nativa sea insuficiente; no aplicar otro efecto encima del existente.

### 08 · Check de filtro seleccionado — C

**Referencia visible:** [Base UI: Checkbox](https://motion.dev/examples/react-base-checkbox), 0.03–0.47 s, trazo que completa la marca.

**Problema / diseño:** distinguir selección sin depender solo del color. El check tiene significado aprendido y ocupa el mismo espacio.

**Minimalismo / alternativa:** check estático es la base. Probar dibujo de 180 ms solo si no retrasa selecciones consecutivas; no cambiar también escala, fondo y contenedor.

**Implementación / criterio:** estado accesible cambia inmediatamente. Conservar si las selecciones se comprenden igual o mejor; eliminar la animación ante errores o sensación de lentitud.

### 09 · Logo Monetta escrito por letras — C, prioridad de marca

**Referencia visible:** [Split text](https://motion.dev/examples/vue-split-text), 0.12–2.19 s, revelado escalonado de texto; [Path drawing](https://motion.dev/examples/react-path-drawing), 0.14–2.49 s, trazos que se completan. Son mecanismos observados, **no un logo de lujo idéntico ni escritura manual verificada en una tienda**.

**Problema / diseño:** expresar identidad en la primera bienvenida; no resuelve una carencia de compra. Su justificación es de marca y preferencia explícita del usuario.

**Minimalismo / alternativa:** el logo estático sigue siendo la referencia. Probar siete máscaras M–O–N–E–T–T–A en 1000 ms, sin mover su centro, sin cursor ni bucles. Variante de trazos solo si conserva perfectamente la marca.

**Implementación / criterio:** PNG original, no otra fuente. Comenzar activo desde el primer frame; no repetir al volver. No sumar escritura al bloqueo actual de `StartupReveal`. Comparar recuerdo/reconocimiento y percepción de espera; conservar solo sin fricción. Véase el plan actualizado en [LOGO_Y_ENTREGA.md](LOGO_Y_ENTREGA.md).

### 10 · Acordeón con señal de apertura — C

**Referencia visible:** [Radix: Accordion](https://motion.dev/examples/vue-radix-accordion), 0.09–1.55 s, apertura, cierre y cambio de contenido.

**Problema / diseño:** indicar relación entre encabezado y detalles secundarios. Agrupar información puede reducir longitud, pero no debe ocultar lo necesario para comprar.

**Minimalismo / alternativa:** cuerpo inmediato y chevron de 180 ms; evitar la animación de altura de toda la descripción. El aprendizaje del caso Paul Smith favorece exponer talla/ajuste y datos críticos.

**Implementación / criterio:** no mover el botón de compra bajo el dedo. Encontrar envío, medidas y devolución no debe requerir adivinar qué panel abrir. Si la información es esencial, hacerla visible y eliminar el acordeón.

### 11 · Indicador local de pestaña activa — C

**Referencia visible:** [Smooth tabs](https://motion.dev/examples/vue-smooth-tabs), 0.11–1.95 s, indicador entre Activity y Home; el demo también mueve/desenfoca contenido.

**Problema / diseño:** reforzar ubicación con continuidad local.

**Minimalismo / alternativa:** conservar etiqueta/icono seleccionado estáticos. Si se anima, mover solo el indicador en 180 ms; descartar blur y barrido del cuerpo del demo.

**Implementación / criterio:** selección accesible y contenido cambian sin esperar. Verificar que no compite con la transición de navegación que ya trae Flutter. No reemplazar el gesto nativo de regreso.

### 12 · Retirada de un elemento de la bolsa — C

**Referencia visible:** J1, cambios de contenido en 20–29 s. El clip muestra actualización de la bolsa; no demuestra por sí solo persistencia, reversión ni todas las causas de cada cambio.

**Problema / diseño:** que la persona entienda qué desapareció y pueda recuperarlo.

**Minimalismo / alternativa:** eliminación inmediata con mensaje y Deshacer es la base. Si hace falta continuidad, opacidad de fila durante 180 ms y reflujo final; sin vuelo, encogimiento dramático ni expulsión lateral.

**Implementación / criterio:** confirmación de servidor, foco estable y reversión ante error. Deshacer exige una operación real; no es una mera animación. Mantener la fila si falla y comprobar que no se elimina dos veces.

### 13 · Indicador local de operación pendiente — C

**Referencia visible:** Multi state badge de #01, segmento Processing al inicio.

**Problema / diseño:** una espera real puede confundirse con un toque perdido. El indicador informa actividad; no inventa porcentaje.

**Minimalismo / alternativa:** texto «Agregando…» suficiente en modo reducido. Un único indicador local únicamente mientras la operación está pendiente. No poner spinner en botón, badge y panel simultáneamente.

**Implementación / criterio:** forma parte de la misma máquina de estados de #01, no otra biblioteca/efecto independiente. Debe terminar en éxito/error recuperable; no imponer espera mínima para exhibirlo. Sin demora real, omitirlo.

### 14 · Error comunicado dentro de su contexto — C

**Referencia visible:** Multi state badge, alrededor de 1.21 s, estado de error.

**Problema / diseño:** distinguir fallo de una operación en curso y saber cómo reintentar.

**Minimalismo / alternativa:** priorizar mensaje persistente junto al control. Opacidad de hasta 180 ms es opcional; no copiar la expansión de ancho del demo si mueve botones.

**Implementación / criterio:** no sacudir, no culpabilizar, no desaparecer antes de leerse. Conservar contenido del formulario, anunciar error y permitir recuperación. Esta es otra condición de #01, no motivo para añadir más movimiento.

### 15 · Confirmación al copiar número de pedido — C

**Referencia visible:** Copy Button, 0–1.12 s: icono y texto pasan entre confirmación y acción.

**Problema / diseño:** el portapapeles es invisible. Confirmar localmente comunica el resultado sin abrir un diálogo.

**Minimalismo / alternativa:** texto «Copiado» en el mismo espacio; crossfade de 180 ms si aporta continuidad. No añadir toast además de la etiqueta.

**Implementación / criterio:** solo introducir si Monetta ofrece una acción útil de copiar pedido/seguimiento. Cambiar estado después del éxito del portapapeles; exponer fallo si lo hay. No crear la función solo para justificar el efecto.

### 16 · Menú que conserva la pantalla de origen — C

**Referencia visible:** J4, 0–9 s, menú lateral sobre parte de la composición.

**Problema / diseño:** distinguir navegación temporal de cambio de página. El origen visible ayuda a cerrar y retomar.

**Minimalismo / alternativa:** reutilizar el drawer nativo y sus tiempos antes que fabricar uno. Sin escalonar enlaces ni animar el fondo.

**Implementación / criterio:** mismo contrato de foco/cierre de #02–03; un componente compartido, no tres sistemas de movimiento. Mantener navegación esencial visible; no ocultarla por estética.

### 17 · Favorito como cambio de estado — C, adaptación

**Referencia visible:** Checkbox de #08 aporta un cambio local de selección; no es evidencia directa de un corazón de una app de moda.

**Problema / diseño:** confirmar guardado y distinguir guardado/no guardado mediante forma además de color.

**Minimalismo / alternativa:** corazón relleno inmediato. Solo probar fundido de 180 ms. Se retira el rebote propuesto en la investigación anterior: no hay necesidad demostrada que lo justifique.

**Implementación / criterio:** persistencia/rollback y etiqueta accesible «Quitar de favoritos». Si el estado estático se reconoce bien, conservarlo sin animación. No aumentar el tamaño de la tarjeta ni añadir partículas.

### 18 · Revelado escalonado de textos editoriales — X por defecto

**Referencia visible:** Split text de #09, texto que se vuelve visible progresivamente.

**Problema / diseño:** podría señalar jerarquía en una campaña, pero también obliga a esperar para leer.

**Minimalismo / alternativa:** título y descripción visibles inmediatamente. Para Monetta, reservar el escalonado al logo; no a precios, títulos de producto ni promociones.

**Implementación / criterio:** no implementar en el recorrido de compra. Una campaña independiente requeriría una hipótesis y comparación específica antes de reabrir esta decisión.

### 19 · Deslizar para mostrar acciones — X en la primera versión

**Referencia visible:** [Swipe actions](https://motion.dev/examples/vue-swipe-actions), 0.18–3.21 s, opciones laterales y expansión de la acción.

**Problema / diseño:** ahorra espacio, pero reduce descubribilidad y puede competir con gestos de galería/navegación.

**Minimalismo / alternativa:** botón Eliminar visible y Deshacer. Ocultar una acción no garantiza una interfaz más usable.

**Implementación / criterio:** no adoptarlo solo por familiaridad con otras apps. Reconsiderar si pruebas de bolsas largas demuestran necesidad; conservar siempre una alternativa visible y accesible.

### 20 · Producto que vuela al carrito — X

**Referencia visible:** [Add to basket](https://motion.dev/examples/js-add-to-basket), demo con recorrido curvo, impacto y halo en destino. El clip inspeccionado de 1.4 s recoge sobre todo el final/recuperación; la página ofrece la demo completa y código.

**Problema / diseño:** intenta relacionar producto y bolsa, pero mueve un objeto grande, aleja la atención y añade varios acentos a una acción frecuente.

**Minimalismo / alternativa:** #01 junto al botón, con contador actualizado sin rebote. Misma información con menos movimiento.

**Implementación / criterio:** no portar vuelo, impacto ni halo. El hecho de que sea una demo bien ejecutada técnicamente no demuestra que sea adecuada para Monetta.

## Selección para la siguiente fase

**Primera comparación:** #01–06 y #09. #07 solo si falta respuesta nativa. Producir por separado bolsa automática y confirmación inline; elegir una respuesta dominante después de verlas juntas.

**Condicionados:** #08 y #10–17. Varios son estados del mismo componente; no contarlos como implementaciones distintas ni activarlos todos. **Descartados inicialmente:** #18–20.

Del primer informe se retiran como recomendaciones independientes: animación del contador de bolsa, subtotal, seguimiento del pedido y cascada de resultados. La información debe actualizarse, pero no se encontró una necesidad suficientemente sólida de animarla. El check de pedido confirmado puede ser estático; no necesita una celebración adicional.

## Regla de aprobación de cada implementación

Una implementación solo pasa si tiene: problema específico, fuente visual que realmente muestre el mecanismo, adaptación explícita, alternativa estática comparable, estados de éxito/error/cancelación, movimiento reducido, prueba de utilidad y coste de renderizado aceptable. Una referencia visual demuestra existencia; no demuestra eficacia.

Medir en tareas equivalentes: dudas tras Agregar, dobles toques, precisión de variante, capacidad de cerrar y retomar contexto, tiempo para encontrar un detalle y comprensión del estado. No inventar umbrales estadísticos ni prometer conversión. Una primera ronda cualitativa sirve para detectar fallos; una conclusión comercial requeriría experimento con muestra y métrica definidos.

En el prototipo: 180 ms para feedback; 280 ms para panel/media; logo 1000 ms. Son puntos de partida compatibles con tokens locales. Cero movimiento decorativo en reposo durante 10 s. En Flutter: validar en dispositivo y perfilado real, no deducir fluidez de un MP4 o del navegador.
