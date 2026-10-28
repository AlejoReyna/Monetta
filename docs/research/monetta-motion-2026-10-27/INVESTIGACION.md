# Monetta: 20 animaciones para una boutique tranquila

Investigación del 27 de octubre de 2026. Alcance principal: aplicación Flutter iOS/Android. La vista previa que encargaremos será web, aislada y con datos de demostración; no representa una migración de la app a web.

**Recomendación:** un momento de identidad al entrar y respuestas breves a acciones de compra. Dejar quietos el catálogo, los precios, la navegación y la fotografía mientras la persona decide. Estas veinte opciones son un catálogo priorizado, no veinte efectos para activar simultáneamente.

## Qué revisé en Monetta

- `README.md`: boutique de bolsas, carteras y relojes importados originales; catálogo Shopify y recomendaciones locales. No es una aplicación financiera.
- `design-system/monetta.tokens.json`: crema `#FBF8F2`, café `#745237`, dorado `#C5A052`; Inter y Playfair Display. Movimiento existente de 180/280/480 ms, curva `(0.16,1,0.3,1)`.
- `lib/app/motion.dart`: transiciones de navegación, revelados y reducción de movimiento. Hay una constante Ken Burns de 18 s; no encontré un uso activo, por lo que no debe describirse como un efecto actualmente visible.
- `lib/app/theme.dart`, `MonettaWordmark`: el logo es una imagen original; la fuente editorial no sustituye el logo. Inspeccioné visualmente `assets/images/3.0x/logo_monetta.png`: siete letras, M ornamental alta, remate/gota izquierda y letras posteriores con espaciado irregular.
- `lib/app/startup_reveal.dart`: barrido horizontal de 1100 ms después de `ready`, con bloqueo de interacción/foco durante la cubierta. Ese barrido no equivale a escritura por letra. No se debe sumar una segunda introducción a esta espera.
- `lib/features/welcome/welcome_screen.dart`: bienvenida editorial separada, con botón Comenzar; es el lugar preferido para probar la nueva identidad.
- `lib/features/home/customer_experiences_section.dart`: reseñas con avance automático de 7 s y transición de 500 ms. Proponer avance manual como parte de reducir el movimiento ambiental.
- `artifacts/animation-research-2026-10-22-motion-lab/`: ya hay seis demostraciones, comparación estática, accesibilidad y evidencia anterior. Reutilizar conceptos; no sobrescribir esa entrega ni presentar su evidencia como validación del nuevo trabajo.
- `docs/web-redesign/shopify-staging/branding-signin-2026-10-22/README.md`: documenta un GIF de entrada ya aplicado a cuentas Shopify. El SVG intermedio incrusta un PNG: no contiene trazos de las letras. Es otra superficie, no el logo animado de Flutter.

## Referentes del rubro y alcance de la evidencia

Las fichas oficiales y ayudas verifican funciones y ofrecen capturas de interfaz. **No ejecuté las apps nativas de estos competidores ni medí sus animaciones.** Las propuestas de movimiento siguientes son inferencias de diseño a partir de esos flujos, no copias verificadas. No hay evidencia aquí de que una animación específica aumente conversión.

| Ref. | Producto y evidencia consultada | Qué estudiar y cómo aplicarlo |
|---|---|---|
| R1 | [NET-A-PORTER, ficha oficial](https://apps.apple.com/us/app/net-a-porter-luxury-fashion/id318597939): 4.9/5 y aproximadamente 49 mil valoraciones en la ficha de EE. UU. consultada. Catálogo por diseñador/color/talla, contenido editorial y wishlist sincronizada. | Referente de adopción y afinidad con boutique. Estudiar la separación entre inspiración y compra; Monetta puede reservar la expresividad para entrada/editorial y dar feedback discreto al guardar. |
| R2 | [FARFETCH, ficha oficial](https://apps.apple.com/us/app/farfetch-shop-luxury-fashion/id906698760): 4.9/5 y aproximadamente 218 mil valoraciones en EE. UU.; documenta visor 360° de bolsas y prueba virtual. | Es especialmente pertinente por bolsas y relojes. Aprovechar la idea de inspección del producto controlada por el usuario. Empezar por galería y zoom; no presupone que Monetta tenga modelos 3D ni justifica producirlos ahora. |
| R3 | [Mytheresa, app](https://www.mytheresa.com/gb/en/shopping-app-intro) y [ayuda de wishlist](https://www.mytheresa.com/us/en/customer-care/faq): listas de deseos, alertas y paso de wishlist a bolsa. | Estudiar continuidad entre guardar y comprar. Confirmación local clara y acceso directo a la bolsa. Sin afirmar que usa un rebote, vuelo o duración determinada. |
| R4 | [Lyst, capacidades de la app](https://help.lyst.com/hc/en-gb/articles/36133679317778-What-can-I-do-on-the-Lyst-App): carpetas de favoritos, preferencias de talla, recomendaciones y alertas. | Estudiar la orientación al filtrar y conservar selecciones. Monetta puede dar feedback a chips/resultados y explicar recomendaciones, sin mover toda la lista. |
| R5 | [NET-A-PORTER, apps](https://www.net-a-porter.com/en-gb/content/our-apps/): wishlist, alertas y contenido PORTER. | Referencia adicional para un bloque editorial que termine quieto y para separar novedades de notificaciones. |

Las cifras son una señal pública de uso y valoración, no un ranking comercial ni prueba causal de buena animación. Pueden variar por país/fecha. Mytheresa y Lyst se incluyen por pertinencia funcional, sin atribuirles métricas no verificadas.

Para inspección visual posterior: abrir las capturas oficiales de R1/R2; recorrer home → listado → producto → favorito → bolsa. Para certificar movimiento real, registrar plataforma, versión, fecha, gesto y video de la app instalada. No inferir curvas o tiempos a partir de una captura estática.

## Top 20, en orden de prioridad para esta aplicación

Prioridad A = primera selección; B = segunda iteración; C = exploración opcional. Coste relativo B/M/A = bajo/medio/alto, no estimación contractual. El ranking combina claridad de compra, frecuencia, identidad solicitada, riesgo y esfuerzo. Todos los tiempos son propuestas iniciales de Monetta.

En **todas** las opciones, movimiento reducido significa estado final inmediato, con textos/semántica equivalentes. Ninguna necesita repetición automática. Las respuestas de red no se retrasan para terminar un efecto.

| # | Opción y beneficio | Disparador, movimiento y límite | Prioridad / coste | Referencia del flujo |
|---|---|---|---|---|
| 01 | **Logo escrito letra por letra.** Identidad memorable. | Primera bienvenida: siete máscaras, 1000 ms total; una sola reproducción; Comenzar disponible desde el primer frame. Ver PLAN_LOGO.md. | A / M; trazos A | Identidad propia; T1 |
| 02 | **Respuesta de presión en CTA.** Confirma que se tocó. | Presionar: contenido a escala 0.985, volver a 1 en 180 ms; área táctil estable; cancelar al arrastrar fuera. No añadir si el control ya tiene respuesta equivalente. | A / B | T1 |
| 03 | **Agregar → agregando → agregado.** Reduce dudas y dobles acciones. | Éxito confirmado: sustituir icono por check en 180 ms, dentro del mismo botón. Pendiente/error tienen texto real. Elegir entre este feedback y la hoja actual, sin acumular ambos. | A / M | R1, R3 |
| 04 | **Favorito con llenado suave.** Hace visible el guardado. | Tap: corazón de contorno a relleno en 180 ms; opcional escala 1→1.06→1, una vez. No partículas. Reversión clara si falla la persistencia. | A / B | R1, R3, R4 |
| 05 | **Hoja de filtros/bolsa contextual.** Conserva la ubicación. | Abrir/cerrar: panel en 280 ms y scrim con opacidad; permitir interrupción y reversión. Un panel a la vez; fondo inactivo. | A / M | Flujos R1/R3; T6 |
| 06 | **Galería de producto controlada.** Facilita inspeccionar detalles. | Swipe directo; al pulsar miniatura, transición 280 ms. Imagen nueva solo tras decodificar; ante error conservar anterior. Sin autoplay ni zoom ambiental. | A / M | R2 |
| 07 | **Selección de variante.** Evita confundir color/tamaño. | Borde/check del selector en 180 ms. Precio, disponibilidad y etiqueta se actualizan de forma legible con el estado correcto; la foto usa #06. Respuesta más reciente gana. | A / M | R1, R2 |
| 08 | **Aplicar filtros con cambio contenido.** Confirma el nuevo conjunto. | Tras respuesta: fundido del bloque de resultados, 180 ms, sin cascada por tarjeta. Conservar foco y anunciar cantidad; no reorganizar mientras se eligen filtros. | A / M | R1, R4 |
| 09 | **Sugerencias de búsqueda discretas.** Relaciona consulta y resultados. | Tras consulta vigente: opacidad 180 ms del panel, sin mover el campo/teclado. Debounce y demora de red son lógica, no duración de animación. | B / M | R4 |
| 10 | **Contador de bolsa.** Confirma el total actualizado. | Cuando el servidor confirma: crossfade de 180 ms en caja de ancho reservado. Sin rodillo de números. Alternativa a #03 como señal principal, no otra celebración. | B / B | R1, R3 |
| 11 | **Cantidad y subtotal estables.** Permite entender el cambio. | Tras escritura confirmada: crossfade 180 ms solo en el valor que cambió; ancho reservado. Operaciones serializadas y límites visibles; sin interpolar dinero. | B / M | Bolsa Monetta; R3 |
| 12 | **Chevron de acordeón.** Explica abierto/cerrado. | Tap: rotación 180 ms. Texto aparece inmediatamente; no animar la altura de un párrafo largo. Conservar el patrón existente si ya cumple. | B / B | Producto Monetta; T1 |
| 13 | **Imagen cargada sin salto.** Suaviza la llegada de contenido. | Placeholder estático con proporción fija → foto decodificada en 180 ms. Una vez por carga; caché inmediata. No shimmer permanente en veinte tarjetas. | B / B | Catálogo Monetta; T5 |
| 14 | **Continuidad catálogo → producto.** Mantiene orientación. | Conservar transición nativa y gesto de regreso. Explorar foto compartida de 280 ms únicamente si sustituye la transición existente; no superponer las dos. Imagen clonada nunca mueve el layout. | B / A | R2; navegación Monetta |
| 15 | **Indicador de sección activa.** Aclara dónde está el usuario. | Tap en navegación: indicador local en 180 ms, iconos fijos. Cambio de contenido inmediato o transición del sistema, sin barrido de toda la pantalla. | B / B | Navegación Monetta; T1 |
| 16 | **Eliminar y deshacer.** Conserva control sobre la bolsa. | Éxito: opacidad de fila 180 ms, luego reflujo inmediato; mover foco a control estable. Deshacer persistente hasta otra acción o cierre, con nueva mutación real. Ante fallo conservar fila. | B / M | Bolsa Monetta; T7 |
| 17 | **Validación contextual tranquila.** Hace comprensible un error. | Error: aparición de mensaje en espacio reservado, 180 ms; no sacudir formulario ni desplazar botón. Error permanece hasta corrección y se anuncia. | B / B | T7 |
| 18 | **Pedido confirmado con check único.** Cierre claro de compra. | Solo tras confirmación válida: dibujar check en 280 ms; número de pedido visible inmediatamente. Sin confeti ni repetir al volver al detalle. | B / M | Pedidos Monetta; T7 |
| 19 | **Actualización de seguimiento.** Señala un cambio real. | Al llegar un estado nuevo verificado: transición de color/check en 180 ms. Nunca camión viajando, barra ficticia o animación al reabrir sin novedades. | C / M | Pedidos Monetta; T7 |
| 20 | **Entrada editorial única.** Aporta delicadeza a una campaña. | Un bloque de home al entrar en viewport: opacidad 280–480 ms, sin desplazamiento preferentemente. Una vez por visita; desactivarlo cuando compita con el logo. Catálogo y precios siempre visibles. | C / B | R1, R5 |

## Selección inicial y presupuesto de movimiento

Prototipar las veinte por separado, pero integrar primero **01, 03, 04, 05, 06, 07 y 08**. Usar #02 solo donde falte una respuesta de presión. No es necesario añadir #10 si #03 ya explica suficientemente el éxito.

Para cada acción, una respuesta visual dominante; las señales relacionadas pueden cambiar simultáneamente sin animarse todas. En reposo, cero animaciones decorativas activas. No alterar los precios, mover un botón bajo el dedo o retener una respuesta por cumplir una coreografía. No introducir parallax, logos en bucle, fondos que respiran, carruseles automáticos ni productos que vuelan al carrito.

Antes de añadir efectos: evaluar la retirada del autoplay de reseñas y evitar que `StartupReveal` y la bienvenida creen dos esperas de marca. Son propuestas de esta investigación, todavía no cambios aplicados.

## Reglas técnicas y fuentes primarias

- **T1 — [Apple, Motion](https://developer.apple.com/design/human-interface-guidelines/motion):** propósito, moderación, posibilidad de omitir e interrumpir. Sustenta la política general; no prescribe nuestros milisegundos.
- **T2 — [W3C, Animation from Interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html):** permitir desactivar movimiento no esencial; este criterio es AAA. En esta propuesta se adopta por diseño.
- **T3 — [Flutter, animaciones](https://docs.flutter.dev/ui/animations/overview):** controladores, curvas y widgets de animación permiten implementar estos efectos sin una nueva biblioteca general.
- **T4 — [Flutter, disableAnimations](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html):** revisar la API contra Flutter 3.44.8 fijado en `.fvmrc`. La documentación consultada distingue actualmente Reduce Motion de iOS del indicador de Android; no asumir que `disableAnimations || accessibleNavigation` cubre todo. El SDK local no estaba enlazado en `.fvm/flutter_sdk` durante esta revisión. Verificar la API disponible y el resultado en ambos dispositivos antes de cambiar código.
- **T5 — [web.dev, animaciones eficientes](https://web.dev/articles/animations-guide):** preferir transform/opacity en el prototipo web y medir renderizado. No equivale a garantía de 60 fps en Flutter o navegador.
- **T6 — [W3C, diálogo modal](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/):** foco dentro, Escape, devolución al invocador y fondo inactivo para la vista previa web.
- **T7 — [W3C, mensajes de estado](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html):** éxito, espera y error deben exponerse a tecnología asistiva sin depender del movimiento.
- **T8 — [MDN, prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-motion):** respetar preferencia del sistema y cambios en caliente en la vista previa web.

## Entrega a otro modelo y revisión posterior

Usar [PROMPT_GENERACION.md](PROMPT_GENERACION.md), que encarga una galería reproducible y tres escenas completas. El plan específico del logo está en [PLAN_LOGO.md](PLAN_LOGO.md). Después ejecutar [REVISION_Y_AJUSTES.md](REVISION_Y_AJUSTES.md) sobre la entrega generada.

Esta entrega contiene investigación, especificación y prompts. No incluye nuevas animaciones implementadas ni una revisión visual de una salida que todavía no existe. La validación del laboratorio del 22 de octubre pertenece exclusivamente a ese laboratorio.
