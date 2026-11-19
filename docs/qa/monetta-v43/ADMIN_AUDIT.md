# Auditoría Shopify Admin — Ofertas y Mayoreo (v4.3)

**Fecha de consulta:** 19 nov 2026 (UTC).  
**Fuentes:** Storefront API pública (`monetta.mx` / `fakcei-n9.myshopify.com`), código `storefront-theme/`, vista sin contraseña en `monetta-staging.myshopify.com`.  
**Sin acceso:** Admin autenticado ni cookie de vista previa del tema `193754824738` desde este agente (preview por URL devolvió 422; staging redirige a `/password`).

---

## Resumen ejecutivo

| Tema | En **producción** (`monetta.mx`) | Qué falta en Admin |
|------|----------------------------------|--------------------|
| **Ofertas** | No existe colección `ofertas` (404). Cero colecciones con nombre/handle de oferta en `/collections.json`. Muestra de 250 productos: **0 variantes con `compare_at_price` > precio**. | Colección + **precios comparación** en productos (sin esto la colección queda vacía y la app/web no tienen ofertas reales). |
| **Mayoreo (página)** | Página **`mayoreo` sí existe** (actualizada 2026-11-10). HTTP 200 en `/pages/mayoreo`. | Asignar plantilla de tema **`guia-mayoreo`** (hoy la página en vivo sigue renderizando layout **Atelier**, no la guía v4.1). |
| **Mayoreo (enlace guía)** | El tema resuelve URL con `monetta-guia-url` → `pages.mayoreo` o `contact` + `?view=guia-mayoreo`. | Si en un entorno falta la página `mayoreo`, el enlace cae en `/` (parece “roto”). Crear página o duplicar desde producción. |
| **Descuentos 3+ piezas** | No visible en API pública. | Revisar **Descuentos automáticos** / reglas de cantidad en Admin (QA app 2→3→4→2). |

Los 404 que viste en vista previa autenticada encajan sobre todo con **Ofertas inexistente en producción** y con **plantilla Mayoreo aún Atelier** hasta publicar/configurar el tema v4.3.

---

## 1. Ofertas

### Hallazgos en catálogo publicado

```
GET https://monetta.mx/collections/ofertas     → 404
GET https://monetta.mx/collections/offers      → 404
GET https://monetta.mx/collections.json      → 24 colecciones; ninguna handle/título “ofertas”
GET https://monetta.mx/products.json?limit=250 → 0 productos con al menos una variante en oferta (compare_at)
```

Búsqueda de colecciones en Admin con término **«ofertas»** → **0 resultados** es coherente: **no hay recurso creado con ese nombre** en la tienda que alimenta `monetta.mx`.

### Qué espera el producto (código)

- **App:** filtro `offersOnly` = `compareAtPrice > price` por variante (`catalog_query.dart`). Sin `compare_at` en Shopify, el chip Ofertas no muestra piezas.
- **Web:** no hay entrada de menú ni `monetta-guia-url` para `ofertas`; el listado sería una **colección Shopify** o filtros Search & Discovery. El tema no inventa la ruta `/collections/ofertas`.

### Checklist Admin (Ofertas)

| # | Acción | Responsable | Criterio de aceptación |
|---|--------|-------------|------------------------|
| O1 | Crear colección **manual o automática** handle `ofertas`, título «Ofertas» | Comercio | `https://monetta.mx/collections/ofertas` → 200; al menos 1 producto |
| O2 | Regla sugerida: **Precio de comparación mayor que precio** (o etiqueta acordada, p. ej. `oferta`) | Comercio | Storefront API muestra variantes con `compare_at_price` |
| O3 | Poblar **compare_at** en piezas piloto (p. ej. Café negro con oferta, dos variantes ofertadas para QA) | Comercio | Filtro Ofertas en app y prueba v43 devuelven mismas variantes |
| O4 | (Opcional web) **Search & Discovery**: filtros precio + “en oferta” alineados con la app | Comercio / Ops | Tarjeta, quick view y PDP coinciden con variante elegible |
| O5 | Enlace en menú o home si el diseño lo pide (hoy no hay nav «Ofertas» en `monetta-header.liquid`) | Diseño + Comercio | Ruta documentada en matriz QA |

**Bloqueo principal:** no es solo “falta la colección”; **también faltan precios de comparación en productos**, por eso incluso un filtro automático «en oferta» estaría vacío hoy.

### Nota staging

En `monetta-staging.myshopify.com`, peticiones anónimas a `/collections/ofertas` redirigen a contraseña (no se pudo inspeccionar el catálogo). Si en staging **sí** existe la colección pero en la vista previa del tema **193754824738** ves 404, confirma que la vista previa apunta a la **misma tienda** donde creaste la colección (staging vs `fakcei-n9` / producción).

---

## 2. Mayoreo

### Hallazgos en páginas publicadas (`/pages.json`)

| Handle | Título | Última actualización |
|--------|--------|----------------------|
| `contact` | Contacto | 2026-11-10 |
| `mayoreo` | Mayoreo | 2026-11-10 |
| `como-vender` | Como vender | 2026-05-29 |

```
/pages/mayoreo                    → 200
/pages/mayoreo?view=guia-mayoreo  → 200 (HTML sigue marcadores "Atelier", no guia-page)
/pages/contact?view=guia-contacto → 200 (Contacto guía funciona en tu sesión)
```

La plantilla en repo para la guía es `templates/page.guia-mayoreo.json` → sección `monetta-guia-page` mode `mayoreo`. En Admin, la página debe usar **plantilla de tema `guia-mayoreo`** (o publicar el tema que honra `?view=guia-mayoreo`).

### Resolución de enlaces en el tema

`snippets/monetta-guia-url.liquid` (clave `mayoreo`):

1. Si existe `pages.mayoreo` y `template_suffix == guia-mayoreo` → URL limpia.
2. Si no → `pages.mayoreo` o `pages.contact` + `?view=guia-mayoreo`.

Si **no hay** página `mayoreo` en una tienda de prueba, el CTA del home («Comenzar a vender») apunta a **`/`** → sensación de 404 / destino alternativo roto.

### Checklist Admin (Mayoreo)

| # | Acción | Responsable | Criterio de aceptación |
|---|--------|-------------|------------------------|
| M1 | Página **Mayoreo** publicada, handle `mayoreo` | Comercio | Existe en Páginas (ya OK en prod) |
| M2 | Plantilla de tema **`guia-mayoreo`** asignada a esa página | Comercio | HTML contiene `guia-page--mayoreo`; sin layout Atelier legacy |
| M3 | Tema **193754824738** en vista previa o publicado con `page.guia-mayoreo.json` | Ops / Dev | `/pages/mayoreo` muestra guía v4.1 (pasos, WhatsApp, catálogo) |
| M4 | Descuento mayoreo (mín. 3 piezas / reglas por variante) activo y probado en carrito de prueba **sin cobro** | Comercio | 2→3→4→2 unidades en QA; línea no elegible excluida |
| M5 | Si usas tienda staging sin páginas: **duplicar** `mayoreo` y `contact` desde producción | Ops | Nav «Mayoreo» y footer no caen en `/` |

### Por qué Contacto sí y Mayoreo “no” en preview

- Contacto ya usa `?view=guia-contacto` sobre página existente y el tema lo reconoce.
- Mayoreo en **tema publicado actual** sigue siendo **Atelier** (`page.mayoreo.json` enorme con bloques AI). Hasta M2/M3, la preview autenticada puede mostrar contenido legacy o rutas alternativas distintas a la guía.

---

## 3. Tema y entornos

| ID / host | Rol conocido |
|-----------|----------------|
| **193754824738** | Tema activo (v4.3) según tu nota |
| **192672989218** | Borrador reversión |
| `monetta.mx` | Storefront público (catálogo auditado arriba) |
| `monetta-staging.myshopify.com` | Desarrollo con contraseña; catálogo no auditable sin login |
| `fakcei-n9.myshopify.com` | Mismo catálogo que `pages.json` de producción (3 páginas, sin `ofertas`) |

**Acción Ops:** Antes de cada corrida QA, confirmar en Admin **Tienda en línea → Temas** que la vista previa usa el ID **193754824738** y la misma tienda donde existen página/colección.

---

## 4. Lo que no pude verificar desde aquí (requiere tu sesión Admin)

- Descuentos automáticos mayoreo, apartados, Rewards, seis métodos de pago en checkout de prueba.
- Search & Discovery y menús editados solo en Admin.
- Contenido exacto de colección `ofertas` en **monetta-staging** (password).

### Pasos rápidos en Admin para cerrar bloqueos QA v4.3

1. **Productos** → abrir 2–3 piezas piloto → variantes con **Precio comparación** > precio.  
2. **Productos → Colecciones** → crear **Ofertas** handle `ofertas` con condición “compare at”.  
3. **Contenido → Páginas → Mayoreo** → plantilla **`guia-mayoreo`**.  
4. **Descuentos** → revisar regla mayoreo 3+ piezas; anotar ID para QA app.  
5. Vista previa tema **193754824738** → abrir `/collections/ofertas`, `/pages/mayoreo`, footer «Mayoreo».

---

## 5. Alineación con matriz QA

Actualizar `docs/qa/monetta-v43/README.md` filas Ofertas/Mayoreo con:

- **Evidencia:** este audit + capturas tras M1–O3 en tu sesión.  
- **Fuente:** `shopify` (Admin + storefront), no `fixture`.