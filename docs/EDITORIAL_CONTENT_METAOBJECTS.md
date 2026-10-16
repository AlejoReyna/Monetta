# Contenido editorial de la app

Las pantallas **Conoce Monetta** y **Vende con Monetta** siempre tienen una
versión completa incluida en la app. Si Shopify Storefront no está configurado,
no hay red o faltan las definiciones descritas abajo, esa versión se conserva.

Para editar el contenido sin publicar otra versión de la app, crea las
definiciones en **Shopify Admin → Contenido → Metaobjects** y habilita acceso de
lectura para Storefront.

## `app_about`

Crear una entrada con handle `monetta` y campos de texto:

- `eyebrow`
- `headline`
- `body`
- `timeline_json`
- `trust_facts_json`

`timeline_json` usa este formato:

```json
[
  {"year":"2023","title":"Aquí comenzó todo","body":"..."},
  {"year":"AHORA","title":"Monetta en tu teléfono","body":"..."}
]
```

`trust_facts_json` es un arreglo de textos:

```json
["Productos originales", "Envíos a todo México"]
```

## `app_partner_program`

Crear una entrada con handle `vende-con-monetta` y campos:

- `eyebrow`
- `headline`
- `body`
- `steps_json`
- `terms_json`
- `faqs_json`

```json
{
  "steps_json": [
    {"number":"01","title":"Elige","body":"..."}
  ],
  "terms_json": [
    {"value":"3","label":"modelos para mayoreo"}
  ],
  "faqs_json": [
    {"question":"¿Cómo funciona?","answer":"..."}
  ]
}
```

Cada campo almacena únicamente el arreglo correspondiente, no el objeto que
los agrupa en el ejemplo.

## `reseller_catalog`

Crear una entrada por cada combinación de categoría y modalidad:

- `category`: slug estable, por ejemplo `bags`, `beauty`, `perfume`
- `category_label`: texto visible
- `mode`: `wholesale`, `suggested_prices` o `no_prices`
- `url`: enlace HTTPS del catálogo
- `description`
- `sort_order`: número
- `updated_label`: opcional
- `active`: `true` o `false`

La app solo abre catálogos alojados en Canva, Google Drive/Docs o Monetta. Un
host distinto se ignora y nunca reemplaza el fallback.

## `app_seasonal_banner`

Banner de temporada del Inicio, justo debajo de Colecciones. El contenido se
lee en cada apertura: cambiar la entrada en Shopify no requiere publicar otra
versión de la app.

Crear el tipo en **Shopify Admin → Contenido → Metaobjects** y habilitar
acceso de lectura para Storefront. Una entrada por campaña. La app muestra la
que esté vigente y, si hay varias, la de `startsAt` más reciente. Si la tienda
está configurada y ninguna campaña está en ventana, la sección desaparece por
completo. Si la app no tiene Storefront configurado, muestra el placeholder
incluido («Anuncio de temporada») en lugar de ocultarse.

Campos:

- `image` — imagen de teléfono, proporción 3:4. Archivo (`file`) o URL https.
- `ipadImage` — imagen de iPad 13", proporción 16:9. Si falta, se usa `image`.
- `tag` — texto corto, por ejemplo `OTOÑO 2026`. La app lo pone en mayúsculas.
- `title` — titular, máximo dos líneas.
- `subtitle` — máximo dos líneas.
- `ctaText` — opcional. Si tiene texto y hay colección, se muestra subrayado
  en blanco. La app añade ` →` cuando el texto no lo trae. El banner completo
  también abre la colección.
- `collectionId` — handle de la colección (por ejemplo `novedades`) o una
  referencia a colección. Un GID sin handle no abre el catálogo: la app filtra
  por handle.
- `startsAt` — fecha ISO-8601 opcional. Vacío significa que ya comenzó. El
  inicio es inclusivo.
- `endsAt` — fecha ISO-8601 opcional. Vacío significa que no caduca. El fin
  es exclusivo: en el instante de `endsAt` la campaña ya no se muestra.

La app también acepta las claves en snake_case (`ipad_image`, `cta_text`,
`collection_id`, `starts_at`, `ends_at`) por si el admin las crea así. Una
imagen que no sea https, o que no cargue, deja el placeholder (fondo crema
oscuro y la M) sin icono de error.
