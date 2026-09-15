# Guía del propietario: administrar Monetta desde la app

Esta guía explica qué tocar en el panel, qué cambia en vivo y qué hacer si algo
no se confirma. No necesitas entrar a Shopify para la operación diaria.

## Antes de entrar

Necesitas:

- una cuenta Monetta de propietario ya provisionada;
- iniciar sesión en **Mi cuenta** con esa cuenta;
- una versión de la app conectada al backend correcto;
- conexión a internet.

Abre **Mi cuenta → ADMINISTRAR MONETTA**. Si la opción no aparece, cierra y
vuelve a abrir sesión. Si sigue sin aparecer, pide que revisen el ID estable de
tu cuenta y la configuración del build; no compartas tu contraseña ni el token
de sesión.

## Comprueba el modo antes de cambiar algo

La franja superior muestra uno de estos estados:

- **CONTROL EN VIVO**: los cambios confirmados se envían a Shopify o al servicio
  correspondiente.
- **VISTA PREVIA**: puedes explorar la interfaz, pero nada se publica.

Si esperabas trabajar en vivo y ves **VISTA PREVIA**, detente y pide que revisen
la configuración. No uses la preview como comprobante de que un cambio quedó
publicado.

## Resumen

La pestaña **Resumen** muestra el total de productos, piezas con stock,
artículos externos, estado de los canales y actividad reciente.

Usa **SINCRONIZAR TODO** cuando un cambio confirmado no aparezca después de un
refresh normal o después de corregir una integración. Espera el resultado: no
toques el botón varias veces. Una fuente externa degradada no significa que
Shopify esté caído.

La actividad reciente indica **Publicado** o **Vista previa**. Para ver eventos
anteriores, toca **CARGAR MÁS**.

## Catálogo de hoy

Ve a **Productos → Catálogo de hoy**.

1. Busca una pieza o usa los filtros **Con stock**, **Mostrándose hoy** y
   **Sin descripción**.
2. Toca **Mostrar hoy**.
3. Espera el mensaje **Producto confirmado en Catálogo de hoy**.
4. Para retirar una pieza, toca **Quitar de hoy** y espera la confirmación.
5. Para cambiar el orden, arrastra las piezas de la lista superior por el
   icono de líneas. Espera **Orden actualizado en Shopify**.

No hay un botón adicional de “Guardar”: agregar, quitar y reordenar son cambios
individuales en vivo. La selección admite como máximo 12 productos.

Sólo aparecen piezas activas y ya visibles en el canal Headless. Si una pieza
no es elegible, primero corrige su estado/publicación en **Editar productos** o
en Shopify. El filtro **Sin descripción** es una advertencia: una pieza puede
mostrarse, pero su ficha tendrá contenido incompleto.

## Editar un producto

Ve a **Productos → Editar productos**, busca la pieza y tócala.

Puedes cambiar:

- el nombre;
- el precio de una variante específica;
- si está visible en la publicación Monetta.

Si el producto tiene varias variantes, selecciona la variante exacta antes de
editar el precio. El panel nunca copia un precio a todas las variantes de forma
implícita.

Revisa los valores, toca guardar y confirma **¿Guardar este producto?**. No
des por terminado el cambio hasta ver **Producto actualizado en Shopify y la
app**. Ocultar una pieza la despublica de Monetta; no la elimina de Shopify.

## Cambiar la portada

Ve a **Tienda**.

1. Escribe el aviso superior (máximo 70 caracteres).
2. Activa o desactiva **Campaña principal**, **Novedades**, **Catálogo de hoy**
   y **Selección externa**.
3. Revisa la vista previa del teléfono.
4. Toca **GUARDAR PORTADA**.
5. Confirma **¿Publicar cambios de portada?**.
6. Espera **Portada publicada en Shopify y la app**.

La vista previa dentro de esta pantalla sirve para revisar composición; el
cambio sólo queda publicado después del botón, la confirmación y el mensaje de
éxito. Otros teléfonos lo verán en su siguiente refresh normal.

## Fuentes externas

Ve a **Fuentes** y toca un proveedor.

Puedes pausar/reanudar el monitoreo y ajustar:

- máximo de artículos;
- comisión base;
- umbral de precio;
- comisión de alta gama.

Toca **REVISAR Y GUARDAR**, revisa la confirmación y espera el mensaje de
éxito. La nueva política se usa en la siguiente ejecución del monitor. Pausar
una fuente conserva su historial; no elimina productos de Shopify ni compra
artículos. Si la sección dice **Revisar** o **Sin conexión**, no habilites una
fuente repetidamente: reporta el estado para revisar el proveedor.

Esta función puede estar visible pero bloqueada durante un rollout. En ese
caso, el backend rechazará el guardado y el resto del panel seguirá operativo.

## Avisos y automatizaciones

Ve a **Avisos**. Si el servicio está habilitado:

1. Escribe título y mensaje.
2. Elige la audiencia: personas suscritas, alta intención, marca o categoría.
3. Decide si la notificación abre la portada o un producto.
4. Toca **CREAR Y REVISAR AUDIENCIA**.
5. Revisa cuántos dispositivos son elegibles.
6. Usa **ENVIAR PRUEBA A ESTE TELÉFONO** antes de una campaña real.
7. Cuando el contenido y destino sean correctos, toca **ENVIAR AHORA** y
   confirma la acción.

El servidor vuelve a aplicar consentimiento, horario silencioso y límite de
frecuencia. El número elegible puede ser mayor que el número finalmente
aceptado por los servicios push.

Los interruptores de **Automatizaciones** cambian reglas futuras. No los uses
como una forma de reenviar una campaña manual.

## Si aparece un error

- **Sesión inválida o vencida**: vuelve a iniciar sesión.
- **No autorizado**: pide que revisen tu principal de propietario; no envíes
  capturas con tokens ni contraseñas.
- **El recurso cambió mientras lo editabas**: refresca, revisa el valor actual y
  decide otra vez. No repitas automáticamente tu cambio anterior.
- **Demasiadas solicitudes**: espera y vuelve a intentar una sola vez.
- **Shopify/fuente no disponible**: no asumas que se publicó. Revisa el estado
  del canal en **Resumen**.
- **Escrituras deshabilitadas**: el panel está en una fase segura del rollout;
  un operador debe habilitar la clase de cambio correspondiente.
- **Catálogo de hoy no configurado**: es un problema de deployment, no de la
  pieza. Reporta el mensaje.

Cuando pidas ayuda, comparte:

- la hora aproximada;
- la sección y acción;
- el texto del error;
- el `requestId`, si aparece.

No compartas contraseña, token de sesión, secretos de Shopify, URL privada de
Postgres ni datos personales de clientes.

## Rutina recomendada

Para una actualización diaria normal:

1. Abre **Resumen** y confirma que Shopify esté disponible.
2. En **Catálogo de hoy**, revisa stock, descripción y orden.
3. En **Tienda**, confirma que las secciones deseadas estén activas.
4. Si habrá campaña, envía primero una prueba a tu teléfono.
5. Vuelve a **Resumen** y revisa **Actividad reciente**.
6. Abre la app como cliente y refresca para verificar el resultado final.
