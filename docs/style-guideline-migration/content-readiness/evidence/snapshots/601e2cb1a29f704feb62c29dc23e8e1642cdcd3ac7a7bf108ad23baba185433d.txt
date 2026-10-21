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
