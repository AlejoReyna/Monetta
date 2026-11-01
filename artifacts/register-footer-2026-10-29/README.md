# Registro y footer — 29 de octubre de 2026

Actualización del borrador **192576585762**, “Monetta buscador predictivo borrador sin public...”, en `monetta-staging.myshopify.com`. No se publicó ni se modificó producción. Se conservan los cambios anteriores de XL.

[Preview de staging](https://monetta-staging.myshopify.com/?preview_theme_id=192576585762&pb=0) · [Proxy local](http://127.0.0.1:9292/)

- `assets/monetta-guia.css`: elimina el margen del footer únicamente cuando Regístrate es la última sección del inicio. Separación medida: **96px → 0px** a 1440×900; también **0px** a 375×812. Otros tipos de página y el inicio con secciones reordenadas conservan su margen.
- `assets/monetta-guia.js`: IntersectionObserver inicia una sola entrada de título, texto, botón y nota. Web Animations: opacidad 0→1, desplazamiento vertical 20→0px, duración 600ms y desfase 80ms. Sin ocultamiento por defecto; contenido visible si JS está desactivado, falta soporte o se prefiere movimiento reducido. Enfoque por teclado y cambio a movimiento reducido cancelan la animación inmediatamente.
- `docs/web-redesign/DESIGN_SPEC.md`: documenta el seguimiento.

**Validación:** 26/26 comprobaciones en [results.json](results.json), incluyendo escritorio/móvil, separación cero, activación al llegar, reproducción única, botón y título visibles al terminar, foco inmediato, destino de cuenta, movimiento reducido inicial y durante la animación, funcionamiento sin JS y apertura del quick view existente. Sin errores JavaScript de la aplicación. `node --check`, `git diff --check` y `port-css.mjs --check` pasan. Theme Check conserva los mismos 187 errores y 64 avisos heredados, sin hallazgos nuevos (comparación por archivo/regla/gravedad/mensaje; el orden de las entradas puede variar).

[Antes, escritorio](before-1440x900.png) · [Después, escritorio](after-1440x900.png) · [Después, móvil](after-375x812.png) · [Entrada, escritorio](entrance-1440x900.png) · [Entrada, móvil](entrance-375x812.png)

Ambos assets se subieron al borrador tras verificar nombre y rol `unpublished`; una descarga posterior coincide byte por byte con los archivos locales. Se reinició el proxy de desarrollo con `monetta-guia.js` incluido en su lista de archivos permitidos; el proxy anterior conservaba una versión vieja de ese JS. El primer intento de prueba queda registrado aparte. Pruebas finales con Brave/Chromium y DPR1; no se activó el enlace de registro ni se crearon cuentas.
