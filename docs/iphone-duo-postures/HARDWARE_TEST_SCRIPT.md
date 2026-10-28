# Guion de hardware · iPhone Duo

No ejecutado. Cada paso de abajo está **sin verificar**. Un simulador no sustituye este guion: no mide alcance del pulgar, ni el tacto sobre el pliegue, ni VoiceOver en el aparato, ni la hoja real de Shopify.

Lo corre Alexis, en un Duo físico que él tenga, con la build de **staging** y una **tarjeta de prueba**. Nadie más dispara un pago. Este documento no autoriza a un agente ni a CI a hacer checkout en vivo. CI deja el comercio apagado.

Antes de empezar: anotar el commit, la configuración (staging) y que la bolsa está vacía. No se pega aquí ningún define, token ni número de tarjeta.

Marca al lado de cada paso, el día que se haga: hecho, o qué falló. Hasta entonces todos dicen **sin verificar**.

## Preparación

1. **Sin verificar.** Instalar la build de staging que Alexis indique. No usar el JSON de defines dentro del repo de evidencias.
2. **Sin verificar.** Confirmar que la cuenta de prueba y la tarjeta de prueba son las de staging. No una tarjeta real.
3. **Sin verificar.** Bolsa vacía en la app y en el admin de Shopify de esa tienda de prueba.
4. **Sin verificar.** Texto del sistema en el tamaño por defecto. Reduce Motion apagado. VoiceOver apagado.

## Alcance y oclusión

5. **Sin verificar.** P1, exterior vertical, mano con la que se usa el teléfono. Llegar a «AGREGAR A BOLSA» sin cambiar de mano. Anotar si el riel o la cámara estorban.
6. **Sin verificar.** P2, exterior horizontal. Repetir. El riel puede quedar a la izquierda o a la derecha: anotar el lado real, no el del simulador.
7. **Sin verificar.** P5, libro. Tocar la acción primaria. No debe caer sobre el pliegue. Nombre, precio y botón se leen sin asomarse al corte.
8. **Sin verificar.** P6, si el aparato la produce al apoyarlo como laptop. Si no se puede formar la pose, escribir «no producida» y no inventar un layout. Si se produce: la galería se lee arriba y el botón se toca abajo.
9. **Sin verificar.** P7, de canto, si la persona puede dejarlo así. Anotar qué pantalla queda de frente. La compra tiene que poder terminar en esa pantalla. No se espera un modo especial.
10. **Sin verificar.** Oclusión de la cámara exterior: el wordmark de Welcome y «Comenzar» no quedan debajo. En la interior, con la cámara apagada, no debe haber un hueco falso.

## VoiceOver y teclado

11. **Sin verificar.** VoiceOver en P1. Orden: «Comenzar» en el primer frame de Welcome, luego, ya en la tienda, Atrás, la acción primaria, los cuatro destinos (Inicio, Catálogo, Carrito, Cuenta).
12. **Sin verificar.** El mismo recorrido en P3 y en P5. En P5 el foco no salta al otro lado del pliegue en medio de un control.
13. **Sin verificar.** Teclado de hardware en Búsqueda, P2, con poco alto. El campo y la primera sugerencia siguen en pantalla. Escape cierra la hoja de filtros y no aplica.

## Hojas

14. **Sin verificar.** Abrir filtros en P5. Cerrar se toca entero, fuera del pliegue. Aplicar no ocurre al plegar.
15. **Sin verificar.** Vista rápida en P3. Cerrar no agrega. Elegir variante y agregar suma una unidad, una sola vez.
16. **Sin verificar.** Compartir desde la ficha, plegar con la hoja del sistema abierta, cerrar la hoja. La ficha sigue en la misma variante.

## Checkout · cancelar y volver

Todo este bloque: **sin verificar**, staging, tarjeta de prueba, lo corre Alexis. **Pendiente de revisión del tester de pagos** como protocolo; el resultado todavía no existe. No es una declaración de pago listo.

17. **Sin verificar.** Armar una bolsa de una pieza, una línea, cantidad 1. Abrir la hoja de Shopify con «Continuar al checkout» y luego el pago seguro.
18. **Sin verificar.** Con la hoja abierta, plegar, desplegar y rotar. No se abre una segunda hoja.
19. **Sin verificar.** Cancelar. Se vuelve a la misma pantalla de checkout, con el estado «revisando tu pago» (o la copia que esa build muestre para el pago no completado). La bolsa sigue en 1 línea, cantidad 1. No se abre otra hoja sola.
20. **Sin verificar.** Tocar pagar otra vez. Se abre una hoja. La bolsa sigue en una línea.
21. **Sin verificar.** Repetir un agregado con el pliegue **durante** «AGREGANDO…». Al terminar hay una sola unidad de esa variante.
22. **Sin verificar.** En el admin de Shopify de la tienda de prueba: el carrito tiene una línea y no hay pedidos duplicados de este guion.
23. **Sin verificar.** Cancelar el checkout en P1, en P3 y en P5, y volver después de un pliegue en cada una. Misma bolsa, una línea, cantidad 1, ninguna segunda hoja, ningún segundo pedido.

## Memoria

24. **Sin verificar.** En una build de profile o release, repetir abrir, plegar, rotar y pasar a segundo plano unas decenas de veces sobre la misma ficha. Guardar el trazo que Alexis use (Instruments o el que ya tenga el equipo). Buscar crecimiento monótono, decodificaciones repetidas de la misma foto y un segundo motor Flutter. No hay un techo numérico elegido: primero la línea base.
25. **Sin verificar.** Anotar si la sesión sigue siendo una: un carrito, una ficha montada, «Comenzar» no vuelve a escribir el logo.

## Cierre

26. **Sin verificar.** Borrar la pieza de prueba de la bolsa y anotar los pedidos de prueba creados, si los hubo, para no confundirlos con una venta.

Si un paso falla, se para ese bloque. No se «completa igual» el checkout para seguir. El fallo se anota con la postura y el commit. Sigue sin ser una aprobación de insignia.
