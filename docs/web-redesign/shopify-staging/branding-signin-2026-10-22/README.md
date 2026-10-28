# Acceso de clientes — identidad Monetta

Aplicado y guardado el 22/10/2026 desde Shopify Admin en Brave.

- Tienda: `monetta-staging.myshopify.com`, cuenta Shopify `90228850722`.
- Configuración de checkout/cuentas: `7993425954`.
- Superficie modificada: **Inicio de sesión → Principal** (ajustes propios de esa página).
- Fondo: `#FBF8F2`; acento: `#745237`.
- Logo: `monetta-signin-logo-entrada.gif`; ancho máximo guardado: **240 px**.
- Espacio superior dentro del recurso: 24 unidades sobre 396 de ancho; aproximadamente **14.5 px adicionales** al mostrarse a 240 px.
- Fotografía de escritorio: `storefront-theme/assets/monetta-home-banner.jpg`, cargada como `monetta-home-banner`.

## Animación

El logo aumenta suavemente desde aproximadamente 76 % de presencia hasta su color completo en **0.62 s**. Se reproduce una sola vez; después permanece visible. El GIF contiene 22 cuadros y no incluye extensión de repetición. Su duración total de 1.84 s incluye la pausa final de un segundo.

El archivo se compone a partir del logotipo original `storefront-theme/assets/monetta-logo-3x.png`. El SVG intermedio conserva ese PNG incrustado sin redibujarlo. La exportación GIF usa el fondo crema y una paleta indexada.

## Comprobación

- Shopify confirmó **«Cambios guardados»** con el ancho final de 240 px.
- Se revisaron la vista móvil del editor y la página real de acceso en Brave.
- El recurso que entrega la página real tiene los mismos bytes que el GIF local: 396 × 137, 22 cuadros, 125 964 bytes, sin repetición.
- Los SVG se pueden cargar y previsualizar, pero Shopify los rechazó al guardar esta pantalla con «La imagen multimedia no puede estar en formato SVG». Por eso el archivo aplicado es GIF.

## Regenerar

Con Node, `rsvg-convert` y FFmpeg instalados:

```sh
node docs/web-redesign/shopify-staging/branding-signin-2026-10-22/build-logo.mjs
```

El SVG es un intermedio; el PNG es una alternativa estática. El recurso aplicado en Shopify es el GIF. Al cambiar el color de fondo de esta pantalla, hay que regenerar también el fondo del GIF.
