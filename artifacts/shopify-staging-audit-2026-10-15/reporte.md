# Revisión de pagos de Monetta Staging

Fecha: 15 de octubre de 2026.

Tienda revisada: `monetta-staging.myshopify.com`. El admin muestra “Monetta Staging” y la identifica como tienda en desarrollo creada para pruebas. La revisión se realizó en modo de solo lectura.

| Proveedor o método (nombre en la interfaz) | Estado observado |
| --- | --- |
| Pasarela de pago de prueba | Activo |
| Shopify Payments | Configuración pendiente: “Completar configuración” |
| PayPal | Inactivo; muestra el logotipo “PayPal Express” |
| Shop Pay | Se muestra como opción disponible de Shopify Payments, cuya configuración está pendiente; no como método activo independiente |
| Apple Pay | Se muestra como opción disponible de Shopify Payments, cuya configuración está pendiente; no como método activo independiente |
| Google Pay | Se muestra como opción disponible de Shopify Payments, cuya configuración está pendiente; no como método activo independiente |

Mercado Pago no aparece entre los proveedores configurados en la página de Pagos.

## Métodos manuales

No hay métodos configurados en “Formas de pago manuales”; solo aparece el control para agregar una forma de pago. Por ello no hay nombres individuales ni instrucciones que evaluar.

| Banco en instrucciones | Titular en instrucciones | CLABE en instrucciones |
| --- | --- | --- |
| No | No | No |

## Modo de prueba

**Sí.** “Pasarela de pago de prueba” figura como “Activo”. Su detalle indica que permite simular transacciones aprobadas, rechazadas o errores de pasarela. Shopify Payments todavía requiere completar su configuración.

No se mostró una opción directa para crear un pedido de prueba en las pantallas revisadas; la pasarela sí muestra instrucciones para realizar pruebas. No se creó ningún pedido ni se realizó ningún cobro.

## Webhooks de pedidos

En **Configuración > Notificaciones > Webhooks**, la lista está vacía y solo aparece “Crear webhook”.

| Evento | ¿Existe en esa pantalla? | Dominio de destino |
| --- | --- | --- |
| Creación de pedidos | No | No aplica |
| Actualización de pedidos | No | No aplica |

Como contexto separado, el archivo local `shopify/shopify.app.staging.toml` declara suscripciones de app `orders/create` y `orders/updated`, ambas hacia `monetta-accounts-staging.fly.dev`. Esa declaración local no confirma su despliegue ni su vigencia y no debe confundirse con la lista revisada en Notificaciones.

## Capturas

Las tres capturas se generaron con la función “Capture full size screenshot” del navegador y se revisaron visualmente:

1. [Página completa de Pagos](01-pagos.png): pasarela de prueba, configuración pendiente de Shopify Payments, PayPal inactivo y ajustes de pagos. La vista estrecha agrupa algunos logotipos bajo “+3”.
2. [Detalle de la pasarela de prueba activa](02-pasarela-prueba-activa.png): instrucciones de simulación y control “Desactivar”. En esta vista el encabezado y la etiqueta de estado se abrevian; el nombre completo aparece en el apartado “Acerca de”.
3. [Página completa de métodos manuales](03-metodos-manuales.png): lista sin métodos configurados.

El reporte y las capturas adjuntas no contienen CLABEs, números de cuenta, tokens ni contraseñas. No se modificó configuración, no se activaron ni desactivaron métodos y no se accedió al admin de producción.
