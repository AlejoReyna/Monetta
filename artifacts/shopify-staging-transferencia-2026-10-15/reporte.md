# Operación en Monetta Staging

Tienda: `monetta-staging.myshopify.com`.
Fecha: 15 de octubre de 2026.

| Punto | Acción realizada | Estado final |
| --- | --- | --- |
| Método manual | Creado y guardado; reabierto para verificar los datos persistidos | **Transferencia bancaria**, activo |
| Proveedores | Revisados sin modificarlos | **Pasarela de pago de prueba: Activo**. Shopify Payments pendiente de completar configuración. PayPal inactivo. Mercado Pago no aparece configurado. No se activó otro proveedor |
| Webhooks | Revisada la pantalla Configuración > Notificaciones > Webhooks, sin crear ni borrar registros | Lista vacía: no aparecen webhooks de creación ni de actualización de pedidos. Dominio y versión de API: no aplica |

Nombre exacto del método, copiado tal como lo muestra Shopify:

`Transferencia bancaria`

Instrucciones de pago guardadas:

> Te enviaremos los datos de pago por WhatsApp después de confirmar tu pedido.

“Detalles adicionales” quedó vacío. No se incluyeron banco, titular ni CLABE.

Shopify mostró la confirmación “Transferencia bancaria activado”. Al reabrir el método se verificaron las instrucciones exactas y el campo adicional vacío. Después se abrió el detalle de la pasarela de prueba y se verificó la etiqueta “Activo”.

La pantalla de Webhooks no tiene registros, por lo que no hay dominios ni versiones de API de webhooks que informar en esa pantalla. No se abrió el formulario para crear webhooks.

Capturas:

- [Método manual creado e instrucciones guardadas](01-transferencia-bancaria-creada.png).
- [Pantalla de Pagos](02-lista-pagos.png).
- [Pantalla de Webhooks con firma oculta](03-webhooks-firma-oculta.png).

Para la captura de Webhooks, el bloque de firma se sustituyó temporalmente en la vista local del navegador por “[OCULTA PARA LA CAPTURA]”. Esto no modifica la firma ni la configuración guardada en Shopify. Después se navegó a otra página. Las tres imágenes se revisaron visualmente antes de entregarlas y no incluyen secretos ni datos bancarios reales.

No se realizaron cobros, no se crearon pedidos y no se accedió a producción. El único cambio guardado en Shopify fue el método manual solicitado.
