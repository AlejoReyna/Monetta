# Paquete B — Búsqueda, listado, colección, marca y tarjeta compartida

Referencia visual: `docs/design-reference/monetta-client-layout.png`
(figuras 03, 04, 05, 08, 09 y la franja inferior de tipografía, componentes,
iconografía y accesibilidad).

Tokens: este paquete **consume** `lib/features/boutique/boutique_tokens.dart`
(marfil `#F8F5EE`, superficie `#F0EBE2`, dorado `#C5A052` para marcas y
`#8F6838` para texto, Playfair Display / Inter, `BoutiqueSpace`,
`BoutiqueRadius`). No lo modifica, y no toca `lib/app/theme.dart`.

---

## 1. Contrato de `ProductCard`

`lib/features/catalog/product_card.dart`. Único parámetro obligatorio:
`product`. Todo lo demás es opcional y su valor por defecto reproduce el
comportamiento anterior al rediseño, así que **ningún consumidor actual
necesita cambios**.

```dart
ProductCard({
  required Product product,
  String? urgency,                                   // restock o descuento real
  bool wide = false,                                 // compatibilidad; sin efecto
  ProductTileDensity density = ProductTileDensity.grid,
  bool showWishlist = true,
  VoidCallback? onQuickView,                         // pulsación larga (paquete C)
  VoidCallback? onTap,                               // sustituye la navegación
  Key? key,
})
```

### Densidades

| Densidad  | Imagen | Nombre   | Marca/Nombre/Precio | Alto de pie (sin escalar) |
|-----------|--------|----------|---------------------|---------------------------|
| `grid`    | 4:5    | 2 líneas | 13 / 14 / 16 px     | 98 px                     |
| `compact` | 1:1    | 1 línea  | 12 / 13 / 14 px     | 74 px                     |

`grid` es el valor por defecto y mantiene la proporción 4:5 anterior, por lo
que la aritmética de altura del carrusel de Inicio sigue siendo válida.

Alto de una tarjeta = `ancho * densidad.imageHeightFactor` +
`MediaQuery.textScalerOf(context).scale(densidad.captionHeight)`.

### Ejemplos

**A — carrusel compacto de Inicio** (sustituye el cálculo actual de
`HomeNewArrivalsRail`, que da por hecho 4:5 y un bloque de texto de 92):

```dart
final cardWidth = (MediaQuery.sizeOf(context).width * .42).clamp(150.0, 220.0);
final caption = MediaQuery.textScalerOf(context)
    .scale(ProductTileDensity.compact.captionHeight);

SizedBox(
  height: cardWidth * ProductTileDensity.compact.imageHeightFactor + caption,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemBuilder: (context, index) => SizedBox(
      width: cardWidth,
      child: ProductCard(
        product: products[index],
        density: ProductTileDensity.compact,
      ),
    ),
    // …
  ),
)
```

Si A prefiere no tocar nada, `ProductCard(product: …)` sigue funcionando igual
que hoy: misma imagen 4:5, mismas dos líneas de nombre.

**C — vista rápida**

```dart
ProductCard(
  product: product,
  onQuickView: () => showMonettaQuickView(context, product),
)
```

Se abre con pulsación larga. No se añade ningún botón: sin callback no hay
control muerto. La pulsación normal sigue abriendo la ficha.

**E — favoritos**

```dart
ProductCardGrid(
  products: saved,
  padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
)
```

`ProductCardGrid` resuelve columnas (2 / 3 a ≥720 / 4 a ≥1060, 1 por debajo de
340) y el alto de fila según el tamaño de texto del usuario. Para un ítem
suelto, `ProductCard(product: p, showWishlist: false)` quita el corazón.

### Presentación compartida sin fusionar modelos

`Product` (Shopify, MXN, checkout Monetta) y `CatalogItem` (fuente
independiente, posible USD, posible comerciante externo) **no se fusionan**:
se perderían identidad, moneda, origen y destino de compra. Lo compartido es
la vista, `MonettaProductTile`, con dos adaptadores:

```dart
ProductTileData.fromProduct(product, facets: store.facetsFor(product.id))
ProductTileData.fromCatalogItem(item)
```

`_BrowseTile` del catálogo completo ya usa esa presentación.

### Reglas de datos

- Badge `-N%`: sólo con `compare_at` real (`Product.discountFraction`).
- Badge `NUEVO`: sólo con `CanonicalFacets.newArrival`, es decir la ventana del
  archivo de reglas. No se inventa ninguna regla nueva. El descuento gana al
  badge de novedad.
- `CatalogItem` no genera badge: no tiene `compare_at`, y `sourcePrice` es el
  precio del comerciante, no un descuento de Monetta.
- Precio desconocido → `Consultar precio`, nunca `$0`.
- El corazón usa `CatalogStore.toggleWishlist` (persistencia existente) y sólo
  aparece cuando la superficie lo soporta. Pulsarlo no abre la ficha.
- Agotado se marca con cápsula + borde (no sólo color) y **no** impide abrir.
- `BoxFit.contain` sobre fondo neutro: asas y correas no se recortan.

---

## 2. Puntos de entrada para el orquestador

| Destino | Función | Archivo |
|---|---|---|
| Búsqueda | `openSearch(context, {initialQuery, prompt})` | `search_screen.dart` |
| Listado completo | `openCatalogBrowse(context, items: …)` | `catalog_browse_screen.dart` |
| Colección / categoría | `openCollection(context, CollectionScreen(...))` | `collection_screen.dart` |
| Marca | `openBrand(context, brandSlug: 'coach')` | `brand_screen.dart` |

`CollectionScreen` acepta ahora, de forma aditiva y opcional:
`description`, `heroImageUrl`, `heroImageAsset`, `ctaLabel`. Sin artwork
renderiza una cabecera tipográfica; no se dibuja un rectángulo gris en lugar de
una fotografía que no existe.

`BrandScreen` acepta `brandSlug` (valor canónico de faceta, nunca `vendor`
crudo), y opcionalmente `title`, `tagline`, `story`, `heroImageUrl`,
`heroImageAsset`.

Navegación objetivo (Inicio · Buscar · Categorías · Favoritos · Cuenta, Bolsa
aparte): estas pantallas siguen usando `MonettaBottomNavigation` tal cual y
quedan listas para reconectar sin cambios internos.

---

## 3. Dependencias abiertas

**Historial de búsqueda — persistencia.** `lib/features/catalog/search_history.dart`
define `SearchHistory` (8 entradas, deduplicación normalizada, más reciente
primero, borrado individual y total, **una lista por cuenta**, nunca mezcladas)
detrás del puerto `SearchHistoryPersistence`. Hoy vive en memoria de la sesión:
una tabla Drift exigiría subir la versión del esquema y regenerar
`database.g.dart`, que es almacenamiento compartido y no se toca de forma
unilateral.

Para hacerlo duradero hacen falta dos cosas del orquestador:

1. Una tabla `SearchQueries(query, accountId, searchedAt)` con la misma
   convención de `WishlistStore.scopeKey` (`''` = invitado), y un adaptador que
   implemente `SearchHistoryPersistence`.
2. Construir `SearchHistory(persistence: …)` una sola vez y llamar a
   `setScope(accountId)` junto a `CatalogStore.setAccountScope(accountId)` en
   `main.dart` (`onAccountScopeChanged`).

Mientras tanto, la pantalla ya toma el ámbito de `AccountScope` si está en el
árbol, así que dos cuentas en el mismo dispositivo nunca comparten historial.

**Contenido editorial de colecciones y marcas.** Banner, frase y texto "Sobre la
marca" vienen por parámetro. Si el propietario los publica en Shopify
(`Collection.description`, `imageUrl`) o en el panel de administración, basta
con pasarlos; no se infiere ni se inventa nada.

---

## 4. Recursos visuales y briefs pendientes

Usados: `assets/images/brands/*.webp` como logotipo de marca, resuelto por slug
canónico (`coach`, `michael_kors`, `guess`, `steve_madden`, `tommy_hilfiger`,
`anne_klein`, `dior`, …) con reserva tipográfica si el archivo no existe.

No usados deliberadamente: `home_collection_*.webp`, `home_bag_*.webp`,
`campaign_*.jpg`, `hero_poster.jpg`. Son material de Inicio (paquete A) y
ninguno puede atribuirse a una marca concreta, así que **no** se reutilizan como
banner de marca.

Briefs pendientes de fotografía:

| Uso | Proporción | Composición | Espacio reservado |
|---|---|---|---|
| Banner de colección | 3:2, se recorta a 200–340 px de alto | escena cálida, producto a la derecha | mitad inferior izquierda para título, descripción y CTA |
| Banner de marca | 3:2 | fotografía verificable de esa marca | franja superior centrada para el logotipo, inferior para una frase |
| Silueta de categoría | 1:1 | producto completo sobre fondo neutro, una sola escala | sin texto |

---

## 5. Diferencias respecto a la lámina, y por qué

1. **Barra inferior flotante de la figura 05** (`Filtros · Ver 124 resultados ·
   bolsa`). No se reproduce: tapa la última fila y compite con la navegación
   inferior. El conteo va en la cabecera y los filtros en los chips y el icono
   de la barra superior. `extendBody` queda en `false` en el listado.
2. **Dorado `#D4AF37` de la paleta de la lámina.** Se mantiene el `#C5A052` de
   los tokens compartidos para líneas y marcas, y `#8F6838` para texto dorado.
   Texto blanco sobre dorado mide 2,6:1, por debajo de AA; el badge `NUEVO` usa
   tinta sobre dorado (~7:1) y el de descuento blanco sobre rojo de rebaja
   (~7,4:1).
3. **Pestaña "Más vendidas" de la figura 09.** No existe: la app no tiene
   ranking de ventas con el que ordenar. Se ofrecen "Todo" y las categorías que
   sí tienen piezas.
4. **Tamaños de texto.** La densidad de píxeles de la lámina implica 8–11 px.
   Se respeta el suelo del brief: 14–16 corriente, 12–14 secundario, 24–32
   editorial.
5. **Chip de orden.** Dice "Ordenar", no el orden vigente: la hoja de filtros es
   el único lugar donde se ve y se cambia el criterio.
6. **Conteo de resultados.** Se calcula siempre sobre la misma lista que se
   renderiza, y búsqueda y colección comparten el mismo comparador
   (`catalog_query.dart`), para que "Ver todo" no cambie el número.

---

## 6. Dos ajustes de altura en archivos de A y C

No los toco (no son míos). Ambos son la misma cuenta: una tarjeta mide
`ancho * densidad.imageHeightFactor + textScaler.scale(densidad.captionHeight)`.

**A — `home_screen.dart`, `_CatalogGrid`.** Usa `childAspectRatio: 0.52` fijo.
Con dos columnas a 320 pt de ancho la celda da ≈258 pt y la tarjeta necesita
≈266; con texto ampliado el margen desaparece en cualquier ancho. Sustituto
directo:

```dart
gridDelegate: productGridDelegate(
  context,
  availableWidth: constraints.maxWidth - BoutiqueSpace.gutter * 2,
),
```

(exportado desde `features/catalog/product_card.dart`; también resuelve las
columnas 2 / 3 / 4 que `_CatalogGrid` ya calcula a mano).

**C — `product_screen.dart`, `_Rail`.** `tileWidth * 1.25 + 120` funciona a
escala de texto 1.0, pero el pie mide 98 sin escalar: a partir de ≈1.23 se
desborda. Sustituto:

```dart
height: tileWidth * ProductTileDensity.grid.imageHeightFactor +
    MediaQuery.textScalerOf(context).scale(
      ProductTileDensity.grid.captionHeight,
    ),
```

`HomeNewArrivalsRail` ya usa exactamente esa fórmula con
`ProductTileDensity.compact`.

---

## 7. Estado de verificación

**No se ejecutaron `flutter analyze` ni `flutter test` en esta sesión, y no hay
capturas renderizadas.** El motivo es del entorno, no del código:

- El shell que ve esta carpeta corre en una VM Linux **arm64** sin Flutter, y
  Flutter no publica SDK para linux-arm64.
- El contenedor en la nube es x86_64, pero la política de egress bloquea
  `storage.googleapis.com` (403 en el CONNECT), que es de donde se descargan el
  SDK de Flutter y los artefactos del engine.
- La Terminal de este Mac sólo puede concederse en modo *click*: se puede ver y
  hacer clic, no escribir. No hay forma de lanzar `fvm flutter` desde aquí.

Queda por verificar, en el Mac, con `fvm flutter analyze` y
`fvm flutter test test/features/catalog/`:

- compilación y análisis estático de los cinco archivos nuevos y los cuatro
  modificados;
- las pruebas nuevas (`product_card_test`, `search_history_test`,
  `brand_screen_test`) y las tres actualizadas;
- fidelidad visual real contra las figuras 04, 05, 08 y 09: composición,
  proporción del banner, densidad de la cuadrícula y legibilidad de precios en
  móvil pequeño, móvil grande, texto ampliado y tema oscuro.

Lo que **sí** se comprobó de forma estática: equilibrio sintáctico de los 18
archivos, que todos los tipos y funciones usados están declarados e importados,
y que las claves y los textos que asertan las pruebas existentes siguen
presentes.
