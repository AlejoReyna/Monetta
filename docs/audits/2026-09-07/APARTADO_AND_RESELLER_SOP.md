# Apartado y mayoreo — SOP honesto (F27)

**Estado:** procesos manuales. La app abre WhatsApp / enlaces de catálogo; no reserva inventario, no cobra anticipo, no crea pedido Shopify, no aprueba revendedores ni calcula comisiones.

## Apartado (menudeo)

1. Cliente elige pieza/variante en la app y toca apartado.
2. La app abre WhatsApp con título, precio, link y código `MN-XXXX`.
3. Operador verifica disponibilidad en Shopify Admin.
4. Si procede: cobra anticipo de referencia ($400 MXN menudeo / $800 MXN mayoreo), crea el pedido en Shopify, etiqueta con el código `MN-XXXX` y vincula al cliente correcto.
5. Stock y saldo restante se operan en Shopify; la app sólo refleja pedidos ya espejados/vinculados.

**No afirmar en UI ni soporte:** “apartado confirmado” sólo por abrir WhatsApp.

## Mayoreo / “Vende con Monetta”

1. Persona abre catálogos (Canva/Drive) o cotiza por WhatsApp desde el hub.
2. Operador responde, confirma términos y crea el pedido manualmente si hay compra.
3. No hay registro privado de revendedor, ledger de comisiones ni checkout mayorista en app.
4. Los enlaces de catálogo del contenido editorial son públicos salvo que el negocio decida restringirlos fuera de la app.

## Soporte

Teléfono de referencia en app: `826 106 6868`. Vigencia de grupos WhatsApp/Facebook y permisos de catálogos: responsabilidad del propietario del negocio.

## Prueba unitaria

El mensaje prefabricado incluye variante/producto y deja explícito que el chat no reserva ni confirma anticipo (`cart_attribution` / `shopper_copy` tests).
