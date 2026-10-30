# M2 — Bienvenida (guía, página 1)

Antes de implementar: el mockup usa fotografía luminosa a sangre, identidad arriba, “Un paraíso de marcas por descubrir”, separador dorado, “BOUTIQUE ONLINE DE PRODUCTOS ORIGINALES” y acción marrón redondeada “COMENZAR” con flecha. La app tenía una foto terracota con velo oscuro y el texto “Tu boutique de marcas originales importadas de EE.UU.”.

Implementado: jerarquía y textos de la guía, tratamiento superior luminoso, botón con flecha, tamaños responsivos y desplazamiento para texto ampliado/horizontal. Colores, tamaños, tipografía, radios y espacios provienen de `MonettaTokens`; los componentes nuevos adaptan los tokens generados. Se ejecutó `node design-system/build.mjs --only=dart` y `--check`; no requirió cambios de manifiesto ni del archivo generado.

Pendiente de fidelidad: fotografía original con cortinas y bolso Coach, y logo metálico de alta resolución. Se conservan fotografía y logo empaquetados; no se usa una captura del mockup como interfaz.

Flujo conservado: `WelcomeGate`, primera visita, onboarding opcional, persistencia y salida a inicio. Sin cambios en lógica o preferencias.

Validación: 13 pruebas de bienvenida correctas, incluidos primera visita, persistencia y acción en 390×844, 320×568 con texto 200 %, 834×1194 y horizontal 844×390. Captura con fuentes reales y recursos locales, sin servicios externos: [390 px](screenshots/welcome-390.png). No se modificaron goldens de referencia.
