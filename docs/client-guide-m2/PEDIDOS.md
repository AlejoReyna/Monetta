# M2 — Mis pedidos (guía, página 12)

Comparación previa: la guía pide cabecera de marca, título centrado serif, filtros “Todos / En camino / Completos”, tarjetas con identidad, fecha, estado, tres fotos, total y botón marrón “Ver detalles”, además del menú, búsqueda y navegación inferior. La app tenía cabecera de texto y título repetido, filtros oscuros, tarjetas sin imágenes y acciones subrayadas.

Implementado: cabecera de marca con menú y búsqueda conectados a destinos existentes, título centrado, filtros marrones, etiqueta visual “Completos”, navegación inferior Inicio/Categorías/Carrito/Cuenta, tarjetas con identidad serif, fecha, iconos de estado, total y acción marrón con flecha. Las imágenes ausentes se explican en un panel visible. Rewards se conserva debajo de los pedidos; carga, vacío, error, caché y sesión caducada conservan sus estados y acciones. El detalle comparte la presentación de estado y muestra el marcador comercial pendiente.

Pendiente: miniaturas reales (el modelo `OrderSummary` no contiene líneas ni fotos). “Categorías” abre el catálogo existente; el menú ofrece los cuatro destinos de esta pantalla y conserva el regreso del sistema. No replica el resto de secciones del menú general de Inicio. El filtro “Completos” sigue siendo exactamente el conjunto de entregados con evidencia: no se renombra ningún estado real ni se convierte “En camino” en entregado. Los filtros sin pedidos se ocultan como antes; Apartados permanece disponible cuando corresponde.

Sin cambios en `order_status.dart`, repositorios, datos, transferencia, cancelaciones, reembolsos, “Pago en proceso”, ayudas o destinos de WhatsApp. La cápsula visual es optativa y solo se activa en lista/detalle de pedidos.

Validación: 97 pruebas correctas de pedidos, incluidas reglas de pago y navegación al detalle; capturas con datos sintéticos `#DEMO-1/2`, sin correos, cuentas bancarias ni servicios externos. Revisiones en 390×844 claro/oscuro, 320×568 con texto 200 % y tablet 834×1194. `flutter analyze`: sin incidencias. Capturas: [claro](screenshots/orders-390.png), [oscuro](screenshots/orders-390-dark.png). Ningún golden de referencia modificado.
