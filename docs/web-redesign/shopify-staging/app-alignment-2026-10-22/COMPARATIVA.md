# App Flutter y tema Shopify · 22 octubre 2026

Destino único: `monetta-staging.myshopify.com`, tema borrador `192125304866`.
Preview: https://monetta-staging.myshopify.com/?preview_theme_id=192125304866

## Comparación previa

| Pantalla / dato | Flutter | Web antes | Cambio |
|---|---|---|---|
| Títulos | Playfair Display 400; pantalla −0.012em, producto/secciones −0.01em | Fuente incluida, con encabezados y título móvil de producto todavía en Inter | Todos los h1–h6 y títulos de acordeones con Playfair 400; nombre de producto con los tamaños y tracking del rol Flutter |
| Inicio: novedades | Productos recientes | Colección all en su orden actual | Orden por creación descendente; consulta hasta 250 productos de la colección |
| Inicio: estilos | Totes, Crossbody, hombro, Satchel, Hobo | Dos atajos genéricos | Módulo de estilos con arte de la app; colecciones reales y búsqueda como alternativa |
| Inicio: colecciones | Bolsas, carteras, relojes, configuración app.home_collections | Ausente | Colecciones y fotos, respetando el metafield de la app cuando existe |
| Inicio: marcas | Marcas del catálogo | Ausente | Marcas conocidas por la app y presentes en shop.vendors, con sus logotipos |
| Inicio: historia / redes | Editorial app_about, about_image_url, social_links y fallback de marca | Ausente | Historia y redes con esas fuentes y los textos/arte de la app |
| Inicio: experiencias | Reseñas y estados; también incluye fallback local de ejemplo | Ausente | Sección preparada para bloques de una app de reseñas; oculta sin datos. No se copian las reseñas de ejemplo ni el 4.9/139 del fallback |
| Colección | Imagen editorial, descripción, conteo, filtros y orden | Sin imagen; los demás datos ya existen | Imagen de collection.image cuando existe |
| Tarjetas | Marca normalizada, precio, disponibilidad, soporte de guardados | Marca basada en vendor/custom.marca; precio y descuento reales; sin guardados | Normalización de marca, etiqueta Nuevo con created_at (30 días, como la app) y guardados de navegador; conserva precios, rebajas y stock de Shopify |
| Producto: variantes | Opciones, disponibilidad, precio de variante | Ya presentes | Conservadas; muestra swatch si Shopify proporciona imagen/color nativo |
| Producto: descripción | HTML o fallback factual | Descripción desaparecía si estaba vacía | Fallback con categoría/marca identificadas, sin inventar propiedades |
| Producto: detalles | Tipo, forma, color, motivo | Marca, tipo, opciones y SKU | Añade forma, colores y motivo con vocabulario y prioridades de la app; si existe una opción Color, muestra la seleccionada y la actualiza junto con SKU al cambiar variante |
| Producto: envío/cambios | Consulta con equipo por WhatsApp | Servicios genéricos, sin panel de condiciones | Acordeón con el mismo texto de la app |
| Producto: descubrimiento | Más de la marca y vistas recientes | Recomendaciones genéricas | Carrusel por marca verificada y piezas vistas en este navegador |
| Carrito | Variantes, cantidades, subtotal, descuentos, envío, total y código | Datos básicos presentes; sin código y filas de descuento duplicadas | Formulario de códigos, eliminación de códigos y un único total de descuentos |

## Fuentes revisadas

- `pubspec.yaml`, `lib/app/theme.dart`, `lib/app/monetta_tokens.g.dart` y `lib/features/boutique/boutique_tokens.dart`.
- `lib/features/home/home_screen.dart`, `home_boutique_sections.dart`, `lib/domain/home_content.dart`, `editorial_content.dart` y repositorios Shopify correspondientes.
- `lib/features/catalog/collection_screen.dart`, `product_tile.dart` y `lib/features/product/product_screen.dart`.
- `lib/data/normalize/{normalizer,rules,text}.dart`, `assets/rules/normalization_rules.json`, `lib/app/shopper_copy.dart`.
- Resumen activo del carrito Shopify y controlador de descuentos de la app.
- Shopify: [Cart Ajax API](https://shopify.dev/docs/api/ajax/reference/cart), [Liquid cart](https://shopify.dev/docs/api/liquid/objects/cart), [product_option_value](https://shopify.dev/docs/api/liquid/objects/product_option_value), [swatch](https://shopify.dev/docs/api/liquid/objects/swatch).

## Criterios y límites de datos

- La app usa Inter en ThemeData genérico, pero sus pantallas boutique aplican explícitamente Playfair Display. Se tomó el rol visible de la boutique. La fuente WOFF2 ya incluida es local, peso 400, con licencia OFL; no se añade dependencia de Google Fonts. También se carga en las plantillas auxiliares y de contraseña para cubrir todos los encabezados del tema.
- Los tamaños de pantalla son 26/30/36 px, producto 25/29/32 px y sección 23/27/30 px según el ancho. El usuario pidió todos los headings con la fuente de títulos; también se aplica a h3 de tarjetas.
- La normalización Liquid se genera desde las reglas incluidas en Flutter. `app.brand_override` y `app.category_override` tienen prioridad; no accede a posibles cambios de Firebase Remote Config. No deduce materiales, medidas, inventario ni tiempos de entrega.
- Guardados y recientes recuerdan únicamente handles en el navegador. No se sincronizan con la cuenta Flutter. Las tarjetas se vuelven a renderizar en Shopify para evitar precios/stock almacenados.
- Los filtros de color/forma dependen de datos y configuración de Search & Discovery de Shopify. El tema conserva los filtros nativos existentes; no cambia el catálogo ni la configuración global de filtros.
- Las alertas push de reposición dependen del backend de la app. En web se conserva la consulta real por WhatsApp para piezas agotadas.
- Las reseñas requieren conectar una fuente real en el editor del borrador. La sección permanece oculta hasta configurarla.
- Los códigos se envían a `/cart/update.js` sin modificar cantidades. Comparten la cola y bloqueo de checkout del carrito. Un HTTP 200 no se presenta como descuento aplicado: solo se confirma si Shopify devuelve una asignación del código. Los descuentos de envío se confirman en checkout.
- No se publica el tema. No se modifican pagos, checkout, cuenta de cliente ni el tema live. La plantilla de contraseña de la tienda recibe únicamente la fuente de títulos; no cambia su formulario ni autenticación. No se leen ni incorporan secretos.

## Copias y despliegue

- Copia remota anterior: `/tmp/monetta-theme-before-20261022`.
- Copia local anterior: `/tmp/monetta-local-before-20261022`.
- `remote-before-manifest.json` contiene hashes de los 611 archivos del borrador previo.
- El código local ya incluía ajustes de tokens y búsqueda predictiva pendientes de subir respecto al borrador remoto. Se conservaron al alinear el tema.
- La subida usa `scripts/theme-push.sh`: valida tienda, ID, nombre y rol `unpublished` antes de subir; no elimina archivos remotos.

## Validación

- Theme Check: **0 incidencias nuevas**. Antes y después conserva 187 errores y 64 avisos heredados del tema base; no se presentan como resueltos.
- Sintaxis JavaScript válida en carrito, producto y merchandising. `git diff --check` sin problemas.
- 16 pruebas Liquid de normalización aprobadas: override, prioridades, marca desde título/vendor/colección, acentos, límites de palabra y orden de colores. Véase `facet-validation.json`.
- API de secciones de Shopify: inicio, tarjeta actual y carrusel por marca responden 200, sin errores Liquid; las tres imágenes de colecciones responden 200 image/webp. Véase `section-validation.json`.
- Brave: inicio, colección, producto y carrito revisados en escritorio y a 400 CSS px. Guardar y recuperar una pieza; carrusel real Más de Guess; historial de vistas al abrir un segundo producto.
- Variante: Reloj Coach Talia Saddle pasó de Rosa Blush a Negro/Plateado. Shopify confirmó `variant=68551021658146` y el panel Color mostró Negro/Plateado. También se sincroniza SKU; los acordeones conservan su estado.
- Carrito: cantidad 1 → 2 → 1; total nativo $1,369 → $2,738 → $1,369 MXN. Código inexistente muestra que no se aplicó sin alterar el importe; Quitar códigos vacía la entrada. No se creó una promoción de prueba ni se validó un código comercial válido.
- Consola: se observaron bloqueos de telemetría de Shopify por Brave Shields; no errores de los scripts nuevos en la revisión realizada. No se cambió Shields ni la configuración de pagos.
- Capturas previas del borrador remoto y capturas posteriores en `artifacts/app-web-alignment-2026-10-22/`. Los PNG móviles de página completa se generaron desde las herramientas de Brave, con viewport de 400 px y escala 2x.

- Verificación posterior a la subida: los 649 archivos remotos coinciden con el tema local, normalizando únicamente comentarios automáticos y formato JSON. El borrador sigue `unpublished`; el tema live continúa siendo `189719183394`. Evidencia: `deployment-verification.json` y manifiestos SHA-256.

[Capturas antes / después](CAPTURAS.md)
