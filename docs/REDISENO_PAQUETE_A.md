# Rediseño boutique — Paquete A (bienvenida, onboarding, inicio)

Handoff para el orquestador.

**Referencia usada:** `docs/design-reference/monetta-client-layout.png`
(1024×1536). Examinada: figuras 01, 02, 03 y 05 a 5–6×, y la franja inferior de
paleta, tipografía, componentes, iconografía y accesibilidad.

## 1. Archivos

**Nuevos (propiedad del paquete)**

| Archivo | Qué es |
|---|---|
| `lib/features/boutique/boutique_tokens.dart` | Capa local de tokens: color, radios 8–12, escala 4/8/12/16/24/32, tipografía, `BoutiqueButton`, `BoutiqueSectionHeader`. |
| `lib/features/welcome/welcome_screen.dart` | Pantalla 01. |
| `lib/features/welcome/welcome_gate.dart` | Regla de primera visita + `WelcomeScope`. |
| `lib/features/home/home_boutique_sections.dart` | Buscador, banner editorial, rail de Novedades, Compra por estilo. |
| `test/features/welcome/welcome_gate_test.dart` | Primera visita, omitir, continuar sin selección, persistencia. |

**Modificados:** `features/onboarding/onboarding_sheet.dart` (reescrito),
`features/home/home_screen.dart`, `features/home/home_account_invitation.dart`,
`lib/main.dart` (una línea — §3.1), y los tests de home, onboarding, espaciado e
integración.

**No tocados:** `lib/app/theme.dart`, `pubspec.yaml`, todo
`features/catalog/`, `features/navigation/`, controladores, modelos y
persistencia. (`features/catalog/` y `pubspec.yaml` aparecen modificados en
`git status`: son cambios de la sesión del paquete B sobre el mismo árbol de
trabajo, no de este paquete.)

## 2. Decisiones

- **Tokens localizados, no sustitución del tema.** El sistema compartido es
  blanco y de esquinas rectas (`kSquare`). El marfil, los radios y el dorado
  viven en `boutique_tokens.dart` y solo afectan a estas pantallas. El archivo
  documenta la migración global línea por línea.
- **La paleta se midió sobre la lámina, no se copió de su tabla.** La franja
  rotula el fondo `#FBF9F2` y el dorado `#D4AF37`, pero las pantallas rendean
  `#F8F5EE` y `#C5A052` — que son además los valores propuestos en el encargo.
  Gana lo rendeado. Otros puntos medidos: tarjeta `#F6F5EC`, buscador
  `#F6F0E9`, tile de silueta `#F5EEE6`, chip de filtro `#E6E2D8`, badge
  `NUEVO` `#DBBE93`.
- **Contraste comprobado.** `#737373` sobre marfil da 4.1:1 (por debajo de AA),
  así que el gris secundario es `#6B6660` (5.2:1). El dorado `#C5A052` da
  2.3:1: solo líneas y marcas; el texto dorado usa `#8F6838` (4.6:1).
- **Reparto tipográfico según la lámina.** Playfair Display queda para los
  momentos editoriales y de marca — logotipo de bienvenida, titular del banner,
  portadas de marca y colección. Inter lleva todos los títulos de interfaz
  (`Novedades`, `Compra por estilo`, `Personaliza tu experiencia`, `Marcas
  favoritas`), texto, precios y botones. Es lo que dice la franja
  (*Playfair — títulos y acentos*, *Inter — texto y botones*) y lo que hacen
  las figuras.
- **Modo oscuro.** `BoutiquePalette` delega en `MonettaColors.dark`, así que el
  tema oscuro existente sigue usable sin una segunda paleta inventada.
- **Primera visita.** `WelcomeGate` lee el único marcador que ya existe,
  `app_preferences.onboarding_state`. `pending` → bienvenida; cualquier otro
  valor → directo a la tienda. No escribe preferencias nuevas ni reinicia
  ninguna. `StartupReveal` no se tocó y la bienvenida se dibuja sobre un inicio
  ya construido: no añade espera.
- **Permisos.** El permiso de notificaciones sigue en el inicio, nunca en el
  onboarding, y ahora espera a que la bienvenida se cierre para no aparecer
  encima de ella.
- **Orden de secciones.** `_resolveSectionOrder` aplica el orden del rediseño
  *solo* cuando el storefront todavía trae el orden por defecto incluido en la
  app. Una tienda que publicó su propio orden en Shopify se respeta tal cual.
- **Onboarding sin selección.** `Continuar` siempre habilitado. Con selección
  vacía no se escribe perfil y el feed se queda en tendencias. `Omitir` hace lo
  mismo y persiste `skipped`.
- **Marcas y categorías reales.** Marcas de `CatalogStore.availableBrands`;
  categorías calculadas de las facetas del catálogo. Ya no hay lista fija.
- **Selección accesible.** Borde + relleno + check circular, nunca color solo.
  Cuadrículas con `Wrap`, así que el texto ampliado agranda la tarjeta en vez
  de recortarla.

## 3. Dependencias del orquestador

### 3.1 `lib/main.dart` — punto de integración de arranque (aplicado)

`const HomeScreen()` quedó envuelto en `WelcomeGate(child: HomeScreen())`
dentro de `OnboardingScope`. Única línea tocada en un archivo compartido, con
comentario en el sitio. Revisar y aprobar.

### 3.2 `ProductCard` — estado del contrato con el paquete B

No se modificó ningún archivo de `features/catalog/`. Al revisar el árbol de
trabajo, la sesión del paquete B ya había publicado el contrato nuevo
(`ProductCard` como envoltorio delgado sobre `MonettaProductTile`), y el
paquete A lo consume tal cual:

- El rail de Novedades usa `ProductCard(product: …, density:
  ProductTileDensity.compact)` — la densidad que el propio paquete B documenta
  como *"Home rails and any narrow carousel"*.
- La altura del rail sale de `density.imageHeightFactor` y
  `density.captionHeight`, no de aritmética duplicada aquí, así que si la
  tarjeta cambia de proporción el rail la sigue sin tocar este archivo.
- **El recorte de imagen ya está resuelto en origen:** `product_tile.dart`
  dibuja el producto con `BoxFit.contain`, que es lo que piden las figuras 03 y
  05. El pedido que este paquete tenía preparado ya no hace falta.

Queda un solo punto abierto, y es de catálogo, no de home:

- **Formato de precio.** La lámina escribe `$6,490 MXN` (entero, sufijo de
  divisa). `kMoney` produce `$ 6,490.00`. Decisión del paquete B; se señala sin
  tocarlo.

Nota de coordinación: `product_tile.dart` ya importa `BoutiqueSpace` de
`features/boutique/boutique_tokens.dart`. La capa de tokens de este paquete es,
de hecho, compartida con el paquete B; conviene que el orquestador decida si se
promueve a `lib/app/` y quién la mantiene.

### 3.3 `pubspec.yaml` — tipografía

Faltan Playfair Display e Inter. `boutique_tokens.dart` ya las nombra primero
en cada `fontFamily`, con la cadena de respaldo del sistema detrás, así que en
cuanto se registren los assets las pantallas las toman sin ningún otro cambio.

### 3.4 `data/local/tables.dart` + migración a esquema 8 — opcional

Las instalaciones anteriores a este paquete también están en `pending` (el
panel nunca se abría solo), así que verán la bienvenida una vez. Evitarlo pide
un flag `welcome_seen` propio. `WelcomeGate` está escrito para que ese flag
entre como segunda condición y nada más se mueva.

### 3.5 Navegación

Sin tocar. La lámina prevé Inicio · Buscar · Categorías · Favoritos · Cuenta
más un botón flotante de bolsa; `MonettaBottomNavigation` sigue como estaba y
no se añadió ningún destino sin funcionalidad.

## 4. Recursos visuales

**Usados**

- Bienvenida: `campaign_terracotta.jpg` — escena oscura y cálida, bolsa de piel
  protagonista, espacio libre arriba para la identidad.
- Banner de inicio: `campaign_olive.jpg` como fotograma de reposo del film de
  campaña (`MonettaVideo` se conserva; solo cambia el póster).
- Compra por estilo: `home_bag_tote/crossbody/shoulder.webp`, `contain`.
- Marcas: `assets/images/brands/*.webp`, ahora `contain` en tarjeta clara.
- Identidad: `assets/images/logo_monetta.png` vía `MonettaWordmark`.

**Descartados tras inspeccionarlos**

- `campaign_welcome.png` — no es una fotografía, es una captura de una tarjeta
  web con texto.
- `hero_poster.jpg` — fotograma velado, casi blanco.

**Briefs pendientes**

| Necesidad | Proporción | Composición |
|---|---|---|
| Foto de bienvenida | 9:19.5 vertical | Bolsa de piel negra protagonista, luz cálida, escena oscura de interior. Cuarto superior libre para logotipo y bajada; franja inferior libre para el botón. Hoy se usa una 4:5 recortada, que descarta ~40% del ancho. |
| Bienvenida, diapositivas 2–4 | 9:19.5 vertical | Solo si se quieren los cuatro indicadores de la figura 01. Hacen falta tres fotos más y copy aprobado. |
| Banner de inicio | 16:10 apaisado | Modelo con pieza a la derecha, columna izquierda limpia para titular de tres líneas y cápsula. |
| Siluetas | 1:1 | Ya existen tres (tote, crossbody, shoulder). La figura 03 muestra cuatro: falta `satchel`. |

## 5. Diferencias respecto a la referencia

| Figura | Diferencia | Motivo |
|---|---|---|
| 01 | Sin indicadores de página (la lámina tiene cuatro puntos). | Solo existe una diapositiva: una foto adecuada y ningún copy aprobado para tres más. El encargo pide indicadores únicamente si hay varias. |
| 01 | El logotipo es el asset dorado oficial, no un "MONETTA" blanco compuesto con una fuente. | El encargo prohíbe reconstruir el logotipo con tipografía. |
| 02 | La acción secundaria dice "Omitir por ahora"; la lámina dice "Saltar". | El encargo pide una acción visible "Omitir". |
| 02 | `Continuar` siempre habilitado. | El encargo pide explícitamente poder continuar sin seleccionar nada. |
| 03 | La cabecera muestra el icono de búsqueda solo cuando el campo se ha ido con el scroll; la lámina lo muestra siempre. | El campo está justo debajo: dos buscadores a la vez son redundantes, y así se conserva el comportamiento ya probado. |
| todas | Tipografía del sistema en lugar de Playfair e Inter. | Ver §3.3. |

## 6. Verificación

**No se pudo ejecutar nada.** `flutter` y `dart` no existen en el entorno de la
sesión; la VM de la carpeta conectada tampoco los tiene; la descarga del SDK
(`storage.googleapis.com`) y `pub.dev` están bloqueadas por la política de
egress; y Terminal en el Mac solo admite clic, no escritura, así que tampoco se
pudo lanzar desde ahí.

**Queda sin verificar:** `flutter analyze`, `dart format`, la suite de pruebas y
cualquier captura renderizada. **Ninguna afirmación de fidelidad visual de este
paquete está respaldada por una captura.** Lo que sí se hizo: lectura completa
del código afectado, comprobación de balance sintáctico de todos los archivos
tocados, y comparación de la maqueta contra la lámina a nivel de estructura,
proporciones declaradas y color medido.

Para cerrar, en el Mac:

```
make format   # muy probable que haga falta: el código se escribió a mano
make analyze
flutter test
flutter test integration_test/app_smoke_test.dart   # o en dispositivo
```

Capturas pendientes: bienvenida, onboarding e inicio, en móvil pequeño (360×640)
y grande (430×932), con texto ampliado y en tema oscuro.
