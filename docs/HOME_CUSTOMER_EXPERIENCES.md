# EXPERIENCIAS DE CLIENTES

La home de la app reproduce la sección **EXPERIENCIAS DE CLIENTES** de
[monetta.mx](https://monetta.mx). No es una copia estática de las reseñas
actuales: la app lee la misma fuente pública que usa la tienda, así que un
review nuevo o editado puede aparecer sin publicar otra versión de Flutter.

En el sitio la sección es un app block de Loox (`loox-dynamic-carousel`) más un
trust badge. En la app vive en `CustomerExperiencesSection`, al final del home,
después de **Nuestras redes**.

## Qué ve la compradora

- Título centrado: `EXPERIENCIAS DE CLIENTES`
- Carrusel de reseñas publicadas con foto
- Estrellas, texto (máximo 200 caracteres), nombre público y sello de compra
  verificada
- En pantallas ≥ 720 px: panel de texto a la izquierda y **dos fotos** a la
  derecha, con flechas anterior/siguiente
- En móvil: una foto, el texto debajo, swipe horizontal, sin flechas
- Autoplay cada 7 segundos, sin loop, desactivado si hay reducción de movimiento
- Badge inferior: estrellas + `{n} reseñas` (hoy 4.9 / 139 en la tienda)
- En la home se muestran solo las primeras **5** reseñas y el botón `VER
  TODAS LAS RESEÑAS` abre una pantalla dedicada.
- La pantalla dedicada usa una lista lazy y solicita lotes de **20** cuando la
  compradora se acerca al final del lote actual.

No se muestran email, teléfono, dirección ni IDs internos. El nombre del
producto no se pinta en la tarjeta; solo se usa como descripción de la foto,
igual que el `alt` del widget web.

## De dónde salen las reseñas

La tienda **no** mete las reseñas en el HTML inicial. El widget de Loox las pide
por JavaScript. El Storefront API de Loox (`storefront-api.loox.io`) no es usable
desde el cliente: responde 401 sin una credencial privada.

La fuente real del carrusel de `monetta.mx` es:

```
https://loox.io/widget/{LOOX_PUBLIC_STORE_ID}/dynamic-carousel/reviews/
```

El id `o68QLEOJFW` ya está publicado en el HTML de la tienda. No es un secreto.
El cliente solo envía GET; no hay Admin API ni tokens privados.

La pantalla dedicada usa la vista pública paginada del mismo widget:

```
https://loox.io/widget/{LOOX_PUBLIC_STORE_ID}/reviews?page=1&limit=20&language=es
```

Cada respuesta incluye el botón público de siguiente página. La app conserva
el total y avanza de 20 en 20; no descarga las páginas posteriores hasta que
la lista se acerca a su final.

Contrato del JSON:

```json
{
  "data": {
    "agg": {
      "reviews": [
        {
          "id": "WpVh3R2iuj",
          "rating": 5,
          "reviewer": "Gaby E.",
          "review": "Me encanta que todo sea 100% original…",
          "verified": true,
          "midImage": "//images.loox.io/uploads/….jpg",
          "poster": "//images.loox.io/uploads/….jpg",
          "productName": "Cartera Guess Negra Monograma",
          "altText": "Customer photo review of …",
          "type": "photo"
        }
      ]
    }
  }
}
```

La app:

- Conserva el orden que manda Loox
- Toma como máximo **20** reseñas (límite del widget live)
- Convierte `//images.loox.io/…` a `https://`
- Rechaza cualquier imagen que no sea HTTPS
- Sanitiza HTML del texto
- Sustituye un “nombre” que parezca email o teléfono por `Cliente Monetta`

Para la pantalla completa también:

- Lee únicamente los elementos de reseña publicados del HTML del widget
- Usa `SliverList`/`SliverChildBuilderDelegate` para construir solo las tarjetas
  visibles
- Deduplica reseñas repetidas entre lotes antes de agregarlas a la lista

El total del badge (4.9 / 139) no viene en ese JSON. Si hace falta, se lee del
widget público de reseñas. Si esa lectura falla, se conserva el último total
conocido o el bundled (4.9 / 139).

## Cómo se actualiza sola

```
abrir la app
   │
   └─ HomeContentController.refresh()
         │
         ├─ GET carrusel Loox
         ├─ (opcional) GET resumen de reseñas
         └─ notifyListeners() → la home se redibuja
```

No hay que editar Dart cuando entra un review nuevo. El flujo es:

1. La clienta deja la reseña y Loox la **publica** (con foto, si debe salir en
   el carrusel).
2. El JSON público cambia.
3. El siguiente `refresh()` de la app trae la lista nueva.

`refresh()` corre al **abrir la app** y cuando el panel de admin pide refrescar
contenido. La sección escucha el controlador: no hace falta reiniciar el
proceso.

### Qué sí se refleja y qué no

| Situación | ¿Se ve en la app? |
|---|---|
| Review publicado, con foto, dentro de las 20 del carrusel | Sí, en el próximo refresh |
| Review editado o reordenado en Loox | Sí, misma fuente |
| Review pendiente, privado o no publicado | No |
| Review solo texto, sin foto | Puede subir el total del badge; **no** entra como tarjeta, igual que en la web |
| App ya abierta, sin refresh | No aparece hasta reabrir o refrescar |
| Caché CDN de Loox (`max-age` ~30 min) | Puede haber un desfase corto respecto al admin de Loox |

No es un socket en vivo. Es la misma autoridad remota que la tienda, leída en
cada refresh.

### Pantalla dedicada

```
home:  5 reseñas + “VER TODAS LAS RESEÑAS”
              │
              └─ pantalla dedicada
                    │
                    ├─ lote 1: 20 reseñas
                    ├─ cerca del final → lote 2: 20 reseñas
                    └─ repetir mientras Loox entregue otra página
```

El primer lote se pide al abrir la pantalla. El indicador aparece al final de
la lista y los errores de un lote permiten reintentar sin perder lo ya leído.

## Estados en la app

| Estado | Qué se muestra |
|---|---|
| `loading` | Título + esqueleto del mismo tamaño que el carrusel. Sin salto brusco de layout. |
| `live` | Reseñas del JSON público. |
| `empty` | Loox respondió 200 sin reseñas publicadas. Título, sin tarjetas ni fallback. |
| `fallback` | Sin red, error HTTP o id vacío. Las 3 reseñas bundled (Monse, Gaby, Guadalupe). El texto visible nunca dice “Loox”, “API” ni “fallback”. |

Si ya hubo un payload live y un refresh posterior falla, se **conserva** el
último live. El fallback bundled solo aparece cuando nunca se logró leer Loox.

## Layout (medido en la tienda)

Theme live: **Atelier** (`#149125824663`). App block:

- `corner-radius`: 24
- `items-per-view`: 2
- `items-per-view-mobile`: 1
- `max-characters`: 200
- `autoplay`: true, delay 7 s
- `stars-color` / `main-color`: `#aa7d44`
- `verified-badge-color`: `#0994d4`
- `quote-marks-icon`: none
- corte responsive: `max-width: 720px`

## Configuración

`LOOX_PUBLIC_STORE_ID` es el id público del widget. Va en
`config/dart_defines.*.json` (ver `config/README.md`).

- Con id (o el default de código `o68QLEOJFW`): la app pide el JSON live.
- Vacío (`--dart-define=LOOX_PUBLIC_STORE_ID=`): no hay fetch; se quedan las
  reseñas bundled.

No usar Admin API tokens ni el Storefront API privado de Loox en el cliente.

## Código

| Pieza | Rol |
|---|---|
| `lib/data/reviews/loox_reviews_repository.dart` | GET público, mapeo, sanitizado |
| `lib/app/home_content_controller.dart` | Refresh, estados loading/live/empty/fallback |
| `lib/domain/home_content.dart` | `HomeTestimonial` y orden de secciones del home |
| `lib/features/home/customer_experiences_section.dart` | UI del carrusel |
| `lib/features/home/customer_experiences_screen.dart` | Pantalla dedicada y lazy loading por lotes de 20 |
| `lib/features/home/home_screen.dart` | La monta como última sección (`testimonials`) |

El orden del home lo puede cambiar Shopify con el metafield `app.home_sections`.
El valor `testimonials` / `reviews` / `experiencias` es esta sección.

## Pruebas

- `test/data/reviews/loox_reviews_repository_test.dart`
- `test/app/home_content_controller_test.dart`
- `test/features/home/customer_experiences_section_test.dart`
- `test/features/home/customer_experiences_screen_test.dart`
- `test/features/home/home_editorial_sections_test.dart` (posición en el home y
  update cuando llega live)

Cubren render, orden y límite, estrellas, texto largo, sin foto, URL insegura,
ausencia de PII, loading, vacío, error/fallback, update del controlador,
overflow móvil, dos fotos en ancho, swipe/controles, semántica, reduced motion
y que esta feature no importa checkout/carrito.

## Diferencias respecto al widget web

Loox en el browser usa Swiper con efecto “material” (la foto de al lado se asoma
en 3D), iframe y un empty-state de merchant. Eso no se reproduce.

La app sí copia jerarquía, medidas, 1 vs 2 fotos, autoplay 7 s, sin loop,
estrellas, sello verificado, radio 24, badge y el JSON público. El título en el
theme tiene un doble espacio accidental (`EXPERIENCIAS DE  CLIENTES`); la app
usa uno solo.

## Cómo comprobar un review nuevo

1. Publicar en Loox una reseña **con foto**.
2. Esperar a que salga en el carrusel de [monetta.mx](https://monetta.mx)
   (o al menos en
   `https://loox.io/widget/o68QLEOJFW/dynamic-carousel/reviews/`).
3. Cerrar y abrir la app, o disparar el refresh de contenido.
4. La tarjeta debe aparecer en el mismo orden que en la web, sin cambiar código.
