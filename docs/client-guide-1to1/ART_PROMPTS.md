# Arte de la guía 1:1

Este archivo es el brief del PM (`PROMPTS.md`). Los PNG ya venían recortados. Esta rama no genera arte nuevo.

## Qué se publicó

| Asset del brief | Archivo en la app | Uso |
|---|---|---|
| bienvenida_fondo | `assets/images/guide/bienvenida_fondo.jpg` | Bienvenida, fondo a sangre. El wordmark es `assets/images/logo_monetta.png`. No se compone una bolsa: las fotos de Shopify de este catálogo son packshots opacos (PNG RGBA con alfa 255), no recortes. |
| home_hero_fondo | `assets/images/guide/home_hero_fondo.jpg` | Hero «Nueva colección» de Inicio. |
| studio_banner_fondo | `assets/images/guide/studio_banner_fondo.jpg` | Contacto, Mayoreo, banner de mayoreo en Inicio, colección sin foto propia, «Bolsas y carteras» y Perfumes. |
| seguimiento_hero_fondo | `assets/images/guide/seguimiento_hero_fondo.jpg` | Hero «Tus modelos favoritos». |
| rewards_phone_mockup | `assets/images/guide/rewards_phone_mockup.jpg` | «Comparte y gana». Sobre el vidrio va `rewards_app_screen.jpg`, una captura real de Inicio (no una bolsa generada). El rectángulo se midió en el PNG de 1024×620: bisel en x=648, interior aprox. x=668–800, y=12–540. |
| comparte_banner_fondo | `assets/images/guide/comparte_banner_fondo.jpg` | Tarjeta de compartir en Cuenta y Menú, y el aviso «¿Tienes dudas?» de Mayoreo. |
| compra_check | no se publica el PNG | Palomita dorada en `GuideSuccessMark` (`CustomPaint`, trazo `#A8763E`). |
| producto_fondo | no se publica | Las fotos de Shopify muestreadas son opacas (alfa mínimo 255). La galería sigue mostrando la foto del catálogo tal cual. |

Los JPG quedan por debajo de 400 KB. Flutter no incluye subcarpetas de assets, así que `pubspec.yaml` declara `assets/images/guide/` aparte de `assets/images/`.

Logos de marca y el logo Monetta: solo archivos oficiales ya existentes (`assets/images/logo_monetta.png`, `assets/images/brands/`). Mi cuenta muestra la inicial del cliente en un círculo.

---

# Monetta: arte generado para la guía (19 pantallas)
Todo se generó con Grok Imagine. No tiene productos, logos, texto ni personas. Los textos, botones y bolsas van encima en la app.
`<nombre>.png` = recortado a la proporción de la guía · `<nombre>_original.png` = imagen completa · `comparacion_<nombre>.png` = guía vs generado · `ref/` = recortes de la guía.

| Asset | Pantalla(s) | Archivo | Prompt (resumen) | Notas |
|---|---|---|---|---|
| Fondo de bienvenida | Bienvenida (pantalla completa) | bienvenida_fondo.png (9:16) | Cielo de atardecer dorado, cortinas de seda crema a los lados, pedestal de travertino al centro, tercio superior vacío para el logo | La bolsa Coach se pone encima con la foto real |
| Hero "Nueva colección" | Página principal (carrusel) | home_hero_fondo.png (~1.63:1) | Atardecer, cortina de seda a la izquierda, pedestal bajo a la derecha, mitad izquierda despejada para el texto | La bolsa (Tory Burch) es foto real |
| Banner de estudio | Contacto (hero), Mayoreo (hero y "Precios de mayoreo"), Colección COACH, Bolsas y carteras | studio_banner_fondo.png (~1.87:1) | Pared crema con luz de ventana en diagonal, plinto de piedra a la derecha, izquierda vacía | Se reusa en varios banners. Productos encima |
| Hero "Tus modelos favoritos" | Página principal (seguimiento) | seguimiento_hero_fondo.png (~2:1) | Degradado de crema a espresso, piel y gamuza café drapeadas a la derecha | La bolsa es foto real |
| Fondo de producto | Preview y Página del producto (galería) | producto_fondo.png (~1.75:1) | Fondo de papel crema, pedestal redondo de travertino, sombra de ventana | Solo sirve si recortamos las fotos de Shopify. Si no, se usan las fotos tal cual |
| Mockup de teléfono | Rewards continuidad, "Comparte y gana" | rewards_phone_mockup.png (~1.65:1) | Teléfono con marco champagne y pantalla crema vacía, sobre pedestal, sombra de arco | En la pantalla va una captura real del catálogo |
| Check de éxito | Pantalla de compra | compra_check.png (1:1) | Círculo y palomita en trazo #A8763E sobre crema #FBF6EE | Conviene hacerlo como ícono vectorial/SVG en Flutter. El PNG queda solo como referencia |
| Banner "Comparte el catálogo" | Mi cuenta, Menú, WhatsApp "¿Tienes dudas?" | comparte_banner_fondo.png (~3.4:1) | Degradado crema, pliegue de satín a la derecha, sombra de arco | La bolsa blanca es foto real |

Prompts completos (en inglés, tal como se mandaron):
- bienvenida_fondo: "Luxury boutique welcome-screen background, vertical. Dreamy golden-hour sunset sky with soft peach, apricot and warm gold clouds, flowing cream ivory silk drapery curtains billowing on both sides, a smooth beige travertine marble pedestal block in the lower center, empty top on which a handbag will later be composited, soft satin fabric pooled at the base. Warm cream, beige, champagne gold palette, elegant editorial product photography lighting, shallow depth of field. Empty upper third for logo overlay. No products, no bags, no text, no logos, no people."
- home_hero_fondo: "Wide luxury e-commerce hero banner background: golden sunset sky with warm peach clouds, cream ivory silk curtains draped on the left, a low beige travertine pedestal on the right side with empty top for compositing a handbag later. Warm cream, beige and champagne gold palette, soft editorial lighting. Left half calm and uncluttered for text overlay. No products, no text, no logos, no people."
- studio_banner_fondo: "Wide minimalist luxury studio banner background: warm cream and beige plaster wall with soft diagonal window light and shadow streaks, a low beige stone plinth on the right side with empty top, subtle warm caramel brown tones at the right edge. Soft, elegant, editorial boutique photography. Left 55 percent empty soft cream gradient for headline text. No products, no bags, no text, no logos, no people."
- seguimiento_hero_fondo: "Wide luxury banner background with a dark moody warm tone: deep espresso brown and soft cream gradient, draped chocolate brown leather and suede fabric folds on the right side, warm soft light from the left, left side light cream and empty for headline text. Elegant fashion editorial mood. No products, no bags, no text, no logos, no people."
- producto_fondo: "Minimal product page studio backdrop: seamless warm cream and soft beige paper sweep, a round low beige travertine pedestal centered, soft diffused light with a gentle diagonal shadow from a window on the wall, calm luxury boutique photography. Empty pedestal top for compositing a product. No products, no text, no logos, no people."
- rewards_phone_mockup: "Elegant smartphone mockup illustration for a referral banner: a modern frameless phone with thin gold-champagne frame standing upright on a small beige stone pedestal, the phone screen is a plain blank warm cream color (empty, to place an app screenshot later), soft cream background with gentle arch shadow and warm window light. Luxury minimal style, cream beige and gold palette. No text, no logos, no brand marks, no people."
- compra_check: "Simple flat icon: a thin hand-drawn style circle outline with a check mark inside, stroke in warm caramel gold brown (#A8763E), centered on a plain soft cream (#FBF6EE) background, minimal elegant line art, generous padding. No text."
- comparte_banner_fondo: "Wide soft card banner background: very light warm cream to pale beige gradient, a faint soft cream satin fabric fold and gentle warm light glow on the right side, subtle rounded arch shadow, calm luxury minimal mood. Left two thirds plain and empty for text and a button. No products, no text, no logos, no people."

## NO se generan: fotos reales que deben salir de Shopify
- Bienvenida: bolsa Coach Tabby en lona signature
- Página principal: bolsa Tory Burch negra acolchada (hero), miniaturas de "Compra por estilo", "Nueva colección", "Lo más buscado" (Coach, Michael Kors, etc.)
- Seguimiento: tote Coach café (hero "Tus modelos favoritos"), bolsas del banner "Precios de mayoreo"
- Búsqueda, Colección/Categoría x2, Preview y Página del producto, Relacionados, Mis pedidos, Pantalla de compra: todas las fotos de productos (Coach Tabby 26, Coach Tote, Brooklyn, reloj Michael Kors, cartera Coach, etc.)
- Mayoreo: bolsa Coach café (hero), bolsa negra (banner Bolsas y carteras), frascos de perfume (banner Perfumes)
- Mi cuenta, Menú, Rewards continuidad: bolsa blanca de "Comparte el catálogo", bolsa y perfume de las tarjetas "Copiar enlace"
- Categorías: miniaturas por categoría (Crossbody, Tote, Shoulder, Handbags, Carteras, Perfumes, Accesorios, Relojes)
- Contacto: bolsa Coach café del hero
- Logos de marcas (Coach, Michael Kors, GUESS, Steve Madden, Tommy Hilfiger, Tory Burch, Kate Spade, Marc Jacobs, CH): son marcas registradas. Usar los archivos oficiales o el texto; no se generan.
- Avatar de "Ana" en Mi cuenta: es una persona. Usar la inicial (como en el Menú) o la foto real de la clienta.
- Logo "Monetta": usar el archivo original de la marca.
- Íconos de UI (WhatsApp, Facebook, TikTok, Instagram, barra inferior, Rewards): usar paquetes de íconos o SVG, no imágenes generadas.
