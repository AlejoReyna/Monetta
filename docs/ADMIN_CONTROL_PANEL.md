# Panel administrativo nativo de Monetta

> Plan de implementación para agentes: `docs/ADMIN_CONTROL_PLANE_IMPLEMENTATION_PLAN.md`. Ese documento define la arquitectura, seguridad, conexión con Shopify, paquetes de trabajo, validación y despliegue. Este documento describe la interfaz y el contrato preliminar existentes.

## Objetivo

El propietario administra Monetta desde la misma app Flutter y con el mismo
lenguaje visual del escaparate. El acceso aparece dentro de **Mi cuenta** sólo
para correos autorizados.

```text
Producto propio
App del dueño → servicio administrativo → Shopify Admin API
                                      ↘ Storefront API → app de clientes

Artículo externo
App del dueño → servicio administrativo → catalog_monitor → app de clientes
```

Shopify continúa como fuente de verdad de productos propios. El monitor externo
continúa como fuente de candidatos de compra: no agrega automáticamente esos
artículos al inventario, carrito o checkout de Shopify.

## Experiencia incluida

- Resumen de productos, stock y candidatos externos.
- Estado separado de Shopify, app y fuentes externas.
- Búsqueda y edición de nombre, precio y visibilidad de productos Shopify.
- Configuración del aviso superior y secciones de portada.
- Activación, cupo y comisión variable por proveedor.
- Comisión menor para artículos que superan el umbral configurable, inicialmente
  `$4,000 MXN`.
- Sincronización manual de los tres canales.
- Confirmación antes de cada cambio y actividad reciente dentro del panel.
- Vista previa segura cuando todavía no existe un backend administrativo.

## Acceso del propietario

La entrada se habilita mediante `--dart-define`:

```bash
flutter run \
  --dart-define=OWNER_ADMIN_EMAILS=duena@monetta.mx \
  --dart-define=ADMIN_API_BASE_URL=https://admin-api.example.com
```

Para revisar únicamente el diseño sin publicar cambios:

```bash
flutter run \
  --dart-define=ENABLE_OWNER_ADMIN_PREVIEW=true
```

`OWNER_ADMIN_EMAILS` acepta varios correos separados por coma. La lista sólo
controla la visibilidad en la app; no reemplaza autorización del servidor. En
modo en vivo la sesión de primera parte o el token de Shopify Customer se
verifica en el servicio administrativo; la app nunca recibe credenciales de
Shopify Admin.

## Contrato del servicio administrativo

| Ruta | Efecto esperado |
|---|---|
| `GET /admin/control-plane` | Estado consolidado del panel. |
| `PATCH /admin/products/:id` | Actualiza Shopify; la app vuelve a sincronizar Storefront. |
| `PUT /admin/storefront-config` | Guarda portada y configuración compartida. |
| `PUT /admin/external-policy/:id` | Guarda fuente, cupo, umbral y comisiones. |
| `POST /admin/sync` | Reconciliación explícita de Shopify, app y monitor. |

La app envía el token corto de la sesión del dueño. El servicio debe validar
identidad y rol, aplicar rate limit y guardar auditoría. El adaptador hacia
`catalog_monitor` usa una firma HMAC de servicio con timestamp y nonce; nunca
se envía esa credencial a Flutter.
El token de Shopify Admin, secretos y credenciales de Postgres viven únicamente
en el servidor.

## Permisos de Shopify pendientes de habilitar

- `read_products`, `write_products`
- `read_publications`, `write_publications`
- `read_metaobjects`, `write_metaobjects` para la configuración compartida
- permiso Storefront para leer el metaobject y la colección manual

No se necesita `write_inventory`, `write_orders` ni `write_customers` para el
primer release. Los permisos se habilitan por endpoint después de validar la
mutación en staging; editar un TOML no concede permisos por sí mismo.

Los permisos se habilitan por endpoint después de validar la mutación en la
tienda de staging. No se deben conceder todos de una vez.

## Guardas obligatorias

- Producción requiere confirmación explícita y una entrada de auditoría.
- El backend repite la autorización del dueño en cada petición.
- Un fallo de Shopify no se presenta como publicación exitosa en la app.
- Desactivar una fuente conserva historial; no elimina productos.
- Nunca hay una acción para evadir CAPTCHA o forzar un proveedor bloqueado.
- Un producto externo sólo entra a Shopify tras compra, recepción y aprobación
  manual del propietario.
