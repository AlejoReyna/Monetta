# Encargo para el modelo que generará las vistas previas

Copia este encargo en otra sesión con acceso al repositorio. Su objetivo es producir una entrega que el usuario pueda abrir y que el revisor pueda modificar. No requiere activar subagentes.

---

Trabaja como diseñador de interacción y desarrollador de prototipos para Monetta, boutique mexicana de bolsas, carteras y relojes originales. Directorio del proyecto: `/Users/alexis_reyna/MyCode/Monetta`.

**Objetivo:** crear una galería interactiva de las veinte opciones de animación investigadas y dos variantes del logo, conservando la identidad real. La aplicación debe sentirse tranquila en reposo. El resultado es una vista previa local, no una modificación de producción.

## Lee primero

1. `docs/research/monetta-motion-2026-10-27/INVESTIGACION.md`: prioridades, veinte fichas y referencias R1–R5/T1–T8.
2. `docs/research/monetta-motion-2026-10-27/PLAN_LOGO.md`: activo, máscaras, tiempos y reglas de reproducción.
3. `docs/research/monetta-motion-2026-10-27/REVISION_Y_AJUSTES.md`: requisitos con los que se revisará tu entrega.
4. `design-system/monetta.tokens.json`, `lib/app/motion.dart`, `lib/app/theme.dart`, `lib/app/startup_reveal.dart`, `lib/features/welcome/welcome_screen.dart` y las pantallas de producto, catálogo, búsqueda y checkout pertinentes.
5. `artifacts/animation-research-2026-10-22-motion-lab/README.md`, `REPORT.md`, `IMPLEMENTATION_PLAN.md` y su código. Puedes adaptar lo útil, pero copia a un directorio nuevo; no sobrescribas evidencia anterior.

Inspecciona el logo y fotografía local antes de construir. Usa el wordmark auténtico, Inter, Playfair Display y los colores del manifiesto. Nada de fuentes remotas, productos inventados sin etiqueta o imágenes de terceros copiadas de los referentes.

## Salida y alcance

Crea solo `artifacts/monetta-motion-preview-2026-10-27/` y sus archivos. Si ya contiene trabajo, conserva una copia versionada antes de editar. No alteres `lib/`, el tema Shopify, el prototipo anterior, configuraciones ni cambios existentes del usuario. No publiques, conectes cuentas ni hagas operaciones comerciales. No necesitas instalar una biblioteca de animación.

Entregables:

- `index.html`, `styles.css`, `app.js` y activos locales; preferentemente sin compilación.
- `README.md` con comando de servidor en localhost, URL concreta y recorrido de prueba.
- `DECISIONES.md`: IDs 01–20, implementado/simplificado/pendiente, motivo, archivos y tokens.
- `logo-masks.json` y recorridos editables si haces B.
- `evidence/`: capturas, video o secuencia temporal, resultados reales y limitaciones. Evidencia nueva, no renombrar la antigua.

Para abrir, servir únicamente esta carpeta, por ejemplo:

```sh
python3 -m http.server 8877 --bind 127.0.0.1 --directory artifacts/monetta-motion-preview-2026-10-27
```

Si el puerto está ocupado, usa otro y entrega la URL real. No afirmes que un servidor está disponible si no lo has arrancado y comprobado.

## Qué debe poder ver y hacer el usuario

1. Veinte fichas numeradas, con nombre, beneficio, botón Probar y Restablecer. No reproducir todas al cargar ni al hacer scroll. Cada ficha contiene un componente realista, no solo una figura abstracta.
2. Selector de comparación **Estático / Propuesta** y **Sistema / Movimiento reducido**. El modo reducido suprime decoración, conserva estados y permite completar las mismas acciones. Un cambio de preferencia cancela efectos activos. Si añades forzado completo, etiquétalo como override de evaluación.
3. Control de velocidad normal y lenta solo para inspección; indica duración efectiva. Nunca presentar la versión lenta como recomendación.
4. Tres escenas con ancho móvil: bienvenida; listado/búsqueda/filtros; producto/favorito/bolsa. Permitir probar un flujo completo. Las opciones 18–19 pueden usar una escena de pedido claramente simulada, sin crear pedidos.
5. Logo A y B, junto al logo estático. Ejecutar solo la variante seleccionada. A debe conservar exactamente los píxeles de la marca; B debe usar recorridos que revelen la imagen, no contornos de otra tipografía. Si no puedes resolver B fielmente, entrega A completa y marca B pendiente sin fingir que un barrido es escritura.
6. Botón Comenzar utilizable durante la escritura. El encabezado interior usa logo estático.
7. Simuladores de red normal/lenta/error y respuesta fuera de orden para galería, búsqueda, variante y bolsa. Son estados locales etiquetados como demostración, sin llamadas a Shopify.

## Reglas de interacción

- Mantener posiciones, precios, tamaños y áreas táctiles. Microefectos de 180 ms; paneles/media de 280 ms; 480 ms solo para editorial opcional. Logo según su plan. Curva existente `(0.16,1,0.3,1)` salvo dibujo lineal de trazos.
- Cero bucles decorativos. Ningún autoplay de reseñas, productos, fondos o cabeceras. No ocultar el contenido esencial esperando una entrada.
- Una señal dominante por acción. No acumular check + rebote del badge + vuelo del producto + toast + apertura de panel.
- El éxito de bolsa y pedido solo aparece después del éxito simulado. Manejar doble toque, error, cancelación y cambio de pantalla. No contar una acción dos veces.
- Búsqueda y media: gana la última petición; la imagen anterior permanece si falla la siguiente. No mostrar selecciones y fotografías incompatibles sin indicar carga.
- Preservar orden de lectura y foco. Modal con fondo inactivo, Escape, Tab/Shift+Tab y retorno al invocador. Los estados se anuncian una vez; el logo tiene una única etiqueta «Monetta».
- Eliminar/deshacer restaura estado y foco. Los mensajes de error no desaparecen por un temporizador decorativo.
- Fallback sin animación plenamente legible; si JavaScript no funciona, al menos marca, contenido y explicación permanecen visibles.

## Comprobaciones obligatorias antes de entregar

Verifica 320, 390, 430, 768 y 1440 px, teclado y movimiento reducido del sistema. Recorrer las tres escenas; abrir/cerrar/reabrir panel rápidamente; cambiar varias veces de variante; doble toque al agregar; provocar error; deshacer; interrumpir el logo.

Después de asentarse la pantalla, esperar diez segundos y comprobar que no hay animaciones decorativas activas. Inspeccionar en video las transiciones, no solo sus frames finales. Registrar errores de consola y desbordamientos; corregir los que encuentres.

Puedes utilizar el `playwright-core` ya disponible en `design-prototype/node_modules` y un navegador instalado si existen; no asumir rutas sin comprobar. Los controles automáticos no sustituyen una revisión visual ni VoiceOver/TalkBack. Reporta por separado lo probado, lo observado y lo pendiente.

Entrega URL local comprobada, ruta de archivos, capturas representativas, video o secuencia temporal y lista de diferencias respecto a la investigación. No declares que está implementado en Flutter ni que mejoró la conversión. El siguiente modelo revisará estos artefactos y hará ajustes concretos.
