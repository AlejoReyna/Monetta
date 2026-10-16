# Auditoría en app real (staging) — checklist
Dispositivos: iPhone (6.1"), Android (~6.5"), iPad 13". Capturas en es-MX, modo claro.

## 0. Preparación
- [ ] Build staging conectada (catálogo Shopify real, login funciona)
- [ ] Fuentes reales (New York, Inter) cargadas
- [ ] Cuenta de prueba con pedidos en varios estados

## 1. Inicio + PR #15 (MON-UX-07/08)
- [ ] Banner de temporada bajo Colecciones, borde a borde; 3:4 iPhone, 16:9 iPad
- [ ] Degradado detrás del texto, legible sobre la imagen
- [ ] Sin campaña: la sección desaparece; sin imagen: placeholder crema oscuro con M al 15%
- [ ] Bloque de registro "OBTÉN" con acento, sin ":)"
- [ ] Tres promesas, "100% originales" por defecto
- [ ] Línea "Pagos seguros con…" Inter 13, gris secundario, máx. 2 líneas; sin Apple/Google Pay
- [ ] WhatsApp, footer, padding inferior = nav bar + 24 px
- [ ] iPad: el ancho no estira textos ni rompe la grilla

## 2. Lista de productos (PLP)
- [ ] Proximidad/similitud: precio, marca y nombre agrupados
- [ ] Imágenes con proporción consistente; estado sin stock
- [ ] Filtros y orden alcanzables con el pulgar

## 3. Ficha de producto (PDP) — U10 primero
- [ ] Jerarquía: foto, marca, nombre, precio, CTA
- [ ] CTA fijo visible; señales de confianza (originalidad, envío, devoluciones) sin prometer políticas no confirmadas
- [ ] Explicación de recomendaciones en lenguaje claro

## 4. Carrito y pago (MON-UX-03)
- [ ] Tres banners de pago fallido con sus textos
- [ ] Nunca se reabre el pago si ya existe pedido

## 5. Cuenta
- [ ] Orden del menú Cuenta
- [ ] Privacidad y datos > Eliminar mi cuenta (MON-ACC-01): reingreso, botón deshabilitado 2 s, bloqueo con pedido activo + WhatsApp

## 6. Pedidos (PR #14/#16)
- [ ] Etiquetas de la hoja de estados, pago antes que envío
- [ ] Transferencia: "Esperando tu transferencia" + "Ver datos de pago" en lista y detalle
- [ ] Sin método: "¿Elegiste transferencia?"; otro método: "¿Dudas con tu pago?"
- [ ] Ningún texto dice "Te avisaremos"

## 7. Transversal
- [ ] Contraste AA, áreas táctiles ≥ 44 pt / 48 dp
- [ ] Texto grande del sistema no rompe pantallas
- [ ] Ícono de notificación legible a 24 px en Android

Salida: findings v2 con captura anotada por hallazgo; aprobado/no aprobado del PR #15.
