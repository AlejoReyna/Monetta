# Mi cuenta y Mis pedidos — 30/10/2026

Implementado originalmente en el borrador `192125304866` y después integrado en el tema activo de staging `192672989218` («Monetta logos y XL 2026-10-29»).
Última subida verificada: 2026-10-30 07:02 UTC. El tema sigue sin publicar.

- [Mi cuenta](https://monetta-staging.myshopify.com/?preview_theme_id=192125304866&view=account)
- [Mis pedidos](https://monetta-staging.myshopify.com/?preview_theme_id=192125304866&view=orders)

Las referencias móviles se adaptaron a una columna en teléfono y a perfil / navegación
lateral más contenido en escritorio. Se reutilizan el logotipo, las fuentes y los
recursos existentes de Monetta. El avatar usa la inicial del cliente cuando no hay foto.

## Integración

Los enlaces de cabecera, menú y navegación inferior llevan a las nuevas vistas.
Son plantillas alternativas `index.account.json` / `index.orders.json`: no requieren
crear páginas, modificar la configuración de cuentas ni registrar otro cliente OAuth.
El acceso usa `/customer_authentication/login` con retorno relativo a la vista solicitada.
Los pedidos y la identidad Shopify se renderizan en Liquid desde `customer`. Las preferencias de foto y nombre mostrado se guardan por cliente en este navegador, como se indica en el editor.
Las dos vistas tienen `noindex, nofollow`.

La cuenta muestra el perfil, Rewards, los accesos solicitados, el último pedido en
escritorio, un catálogo para compartir y cierre de sesión. Los paneles de direcciones,
preferencias y pedidos muestran los datos reales. Shopify conserva la edición del perfil
y las direcciones, y gestiona los datos de pago en checkout. Favoritos reutiliza la lista
existente del navegador; no implica sincronización con la app. Las notificaciones explican
las actualizaciones por correo; no se simula una bandeja de notificaciones.

Los pedidos muestran imágenes, fecha, importe, estados, filtros y detalle con partidas,
importes, dirección y rastreo cuando Shopify proporciona un enlace. El historial se pagina
en grupos de 20; los filtros se aplican a la página mostrada. `fulfilled` se presenta como
«Enviado», no como entrega confirmada. «Completado» requiere el dato verificado
`order.metafields.monetta.delivery_status = delivered`; Liquid no proporciona por sí solo
una confirmación del transportista. Los pedidos cancelados se conservan en «Todos».

Rewards solo muestra puntos si existe `customer.metafields.monetta.rewards_points`.
Sin saldo disponible ofrece consultar beneficios; no se inventan los 320 puntos de la
referencia. El destino del programa es configurable en la sección. Compartir usa la hoja
nativa o copia el enlace del catálogo; no implementa atribución ni abonos por referidos.

## Verificación

- Firefox aislado: cuenta y pedidos a 320, 390, 768, 1024 y 1440 px, sin desbordamientos.
- Filtros, estado vacío, historial sin compras, aislamiento sin sesión, retorno del acceso,
  nombres / correos largos, paneles, cierre con Escape y restitución del foco.
- Axe sobre las dos vistas a 390 y 1440 px: cero incidencias.
- Cero excepciones JavaScript en la revisión local.
- Revisión real en Firefox con sesión Shopify: perfil y último pedido cargados; historial
  con dos pedidos reales, sus imágenes e importes; filtro sin coincidencias, restablecimiento
  de todos los pedidos y apertura del detalle con partidas y dirección.
- Theme Check sin incidencias en los archivos modificados. El tema completo conserva
  187 errores preexistentes en archivos ajenos a este cambio; no se declara un pase global.
- `git diff --check` sin incidencias.

Las imágenes `account-*.png` y `orders-*.png` de esta carpeta usan exclusivamente datos
de prueba (Ana, pedidos MNT2343–MNT2345, saldo 320). No son capturas de datos personales
ni de la sesión real de Shopify. `local-verification.json` identifica estos fixtures.

## Ajuste del menú lateral

El menú de cuenta en tablet y escritorio queda fijo en el borde izquierdo, sin
margen exterior ni esquinas redondeadas, inmediatamente debajo de la barra
superior. Su altura usa el espacio disponible de la ventana; en ventanas bajas
permite desplazar el propio menú para alcanzar todos los accesos. El contenido
y el pie de página reservan su ancho. Se eliminaron la navegación de categorías
de la cabecera en estas dos vistas, las migas de navegación y «Tu espacio Monetta».

Se verificaron 320, 390, 750, 768, 1024 y 1440 px; las coordenadas del menú
permanecen iguales antes y después de desplazar la página, con borde izquierdo
en 0 y borde superior coincidente con el final de la cabecera. Axe sin incidencias
a 390 y 1440 px, filtros y paneles correctos, y Theme Check sin incidencias en
los archivos de este ajuste.

## Acceso desde el tema activo y editor de perfil

El botón original apuntaba a Shopify en el tema activo, mientras que el rediseño
solo estaba en el borrador. Se integraron las dos vistas en el tema activo de
staging y se corrigieron la cabecera, el menú, la barra inferior y «Ver mi cuenta»
de la portada. La integración conserva los archivos actuales de marca, búsqueda
predictiva y navegación; `active-theme-integration/` contiene respaldo, diferencias
y verificación mediante descarga de Shopify. El portado se reproduce con
`scripts/port-account-to-active-theme.mjs` usando una descarga de los archivos
del tema activo (incluida `sections/monetta-guia-home.liquid`) como `--base`.

El avatar / nombre abre «Editar mi perfil» dentro de Monetta. Permite seleccionar
una foto, quitarla, editar el nombre mostrado y guardar o cancelar. La foto se
recorta al centro y se reduce a 512 × 512 px; acepta JPG, PNG, WebP y AVIF de hasta
10 MB. El nombre y la foto son preferencias locales de este navegador, separadas
por ID de cliente y dominio; no actualizan el nombre legal de Shopify ni se
sincronizan entre dispositivos. La interfaz indica esta persistencia.

Se verificaron 13 comportamientos del editor: subida y preparación de imagen,
persistencia al recargar y cambiar de cuenta a pedidos, cancelación, eliminación,
formatos / archivos corruptos, tamaño máximo, nombre vacío, almacenamiento sin
espacio, separación entre clientes y estado sin sesión. Axe sin incidencias en
el editor a 390 y 1440 px; cero excepciones JavaScript. Se comprobó en Firefox
con sesión real que Cuenta abre `/?view=account` en la tienda normal y que el
avatar abre el editor con el selector de foto y el campo del nombre.

Accesos normales de staging:
- [Mi cuenta](https://monetta-staging.myshopify.com/?view=account)
- [Mis pedidos](https://monetta-staging.myshopify.com/?view=orders)
