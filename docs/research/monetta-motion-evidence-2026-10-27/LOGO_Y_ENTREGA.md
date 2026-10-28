# Plan revisado del logo y encargo para generar las vistas

La [investigación V2](INVESTIGACION_V2.md) sustituye la selección anterior. Esta fase prepara prototipos; la integración de producción viene después de observarlos y corregirlos.

## Logo: identidad con un coste de atención limitado

El usuario pidió escritura letra por letra. La justificación es expresión de marca y bienvenida; no hay evidencia para afirmar que la escritura mejorará ventas o hará más fácil comprar.

**Referencia A:** [Split text, Motion](https://motion.dev/examples/vue-split-text). Observado: aparición escalonada de palabras. Adaptación explícita: máscaras individuales de las siete letras del logo original. No se afirma que la referencia ya contenga el efecto exacto de Monetta.

**Referencia B:** [Path drawing, Motion](https://motion.dev/examples/react-path-drawing). Observado: contornos que se completan. Adaptación: un recorrido central usado como máscara para revelar cada letra, conservando el relleno/serifas. Un contorno animado no equivale automáticamente a escritura caligráfica.

**A es la primera candidata.** B se conserva como alternativa si los trazos pueden hacerse fieles, sin importar otra fuente ni deformar la M. El control estático C es obligatorio.

### Especificación

- Activo: `assets/images/3.0x/logo_monetta.png`; conservar proporción, remates, color y transparencia. El SVG de cuentas Shopify existente incrusta un PNG y no aporta recorridos de escritura.
- Siete máscaras de límites ajustados manualmente: M, O, N, E, T, T, A. No siete franjas iguales. La gota ornamental pertenece a la M.
- Caja con tamaño final desde el inicio. Letras en posición definitiva; no centrar el texto parcial ni hacer crecer el contenedor.
- A: M 0–220 ms; O 220–350; N 350–480; E 480–610; T 610–740; T 740–870; A 870–1000. Son parámetros de prueba propios, no tiempos prescritos por una fuente.
- B: máximo inicial de 1200 ms; rutas editables y máscara sobre el activo. Sin bucle, cursor, destello, rebote, sonido ni animación de salida.
- Una reproducción en primera bienvenida. Encabezados interiores estáticos. Cambiar de pestaña, volver del checkout o reconstruir no reinicia el logo.
- Comenzar funciona desde el primer frame y cancela la animación. No se sumará la escritura al bloqueo de 1100 ms de `StartupReveal`; hay que retirar/sustituir la espera decorativa cuando se integre.
- Reducir movimiento: logo completo inmediatamente; una sola etiqueta accesible «Monetta». Cambio de preferencia en caliente termina la decoración. Segundo plano/desmontaje cancela y libera recursos.

### Comparación que debe decidir la variante

Presentar A/B/C al tamaño real de bienvenida, con la misma foto, botón, textos y tiempos de carga. Preguntar qué marca se leyó, observar si la persona espera por error antes de tocar y comprobar que el frame final sea indistinguible del original.

Elegir A si aporta identidad sin espera percibida; C si la animación parece carga o dificulta reconocer la marca. Elegir B solo si supera A visualmente sin deformaciones ni costes innecesarios. No alterar la fuente para que B sea más fácil de producir.

## Prompt listo para el modelo generador

```text
Actúa como diseñador de interacción y desarrollador de prototipos de Monetta.
Repositorio: /Users/alexis_reyna/MyCode/Monetta.

Lee:
- docs/research/monetta-motion-evidence-2026-10-27/INVESTIGACION_V2.md
- docs/research/monetta-motion-evidence-2026-10-27/LOGO_Y_ENTREGA.md
- docs/research/monetta-motion-evidence-2026-10-27/evidence/sources.json
- Abre el visor index.html y las fuentes visuales pertinentes.
- design-system/monetta.tokens.json, lib/app/motion.dart, lib/app/theme.dart,
  bienvenida, startup, producto, catálogo y mini_cart.

La investigación V2 reemplaza la orden anterior de generar veinte efectos
indiscriminadamente. Construye la primera selección 01–06 y 09; 07 solo donde
falte feedback nativo. Incluye los demás candidatos como fichas de decisión,
no los actives por defecto. No implementes 18–20.

Trabaja exclusivamente en artifacts/monetta-motion-preview-v2/. Conserva
archivos existentes, no edites lib/, Shopify ni los laboratorios previos.
No publiques, conectes cuentas, hagas compras ni instales una librería de
animación solo porque una referencia la usa. No copies código premium ni
fotografía de terceros: las referencias explican mecanismos, no ceden activos.

Haz un prototipo HTML/CSS/JS local con fuentes y activos auténticos de Monetta,
sin build si es viable. Tres escenas: bienvenida; listado/filtros; producto/bolsa.
Datos locales claramente simulados. Sin peticiones comerciales ni analítica.

Cada efecto debe tener una ficha con:
ID, problema, fuente y tiempo observado, qué se adapta, alternativa estática,
regla de minimalismo, éxito/error/cancelación, movimiento reducido, duración,
prueba de aceptación y motivo para retirarlo. Diferencia observación de inferencia.

Controles globales: Estático/Propuesta; Sistema/Reducido; reiniciar escena.
Solo reproducir la escena seleccionada. Mostrar A/B/C del logo sin reproducir
las tres a la vez. Comenzar siempre activo. Sin ciclos decorativos en reposo.

Comparar dos soluciones de agregado, nunca apilarlas:
A) confirmación inline con acceso voluntario a bolsa;
B) panel de confirmación existente refinado, con contador estático.
La red simulada tendrá normal/lenta/error/doble toque/respuestas desordenadas.
Éxito únicamente después del éxito de la operación. Selección y foto deben coincidir.

Preserva logo original, tamaños táctiles, precios, foco y etiquetas. Usa
180/280 ms como inicio y la curva local; 1000 ms para logo A. Nada de ocultar
datos esenciales esperando que termine una entrada. Sin blur, vuelo al carrito,
parallax, rebotes, menús escalonados ni animaciones de dinero.

Entrega README con servidor y URL comprobados, código, decisiones por ID,
fuentes/tiempos, capturas 320/390/430/768/1440, video temporal, resultados y
limitaciones. Prueba teclado, foco modal, interrupción, errores y movimiento
reducido. Verifica que a los diez segundos en reposo no siga decoración activa.
No afirmar rendimiento móvil ni mejora de conversión por ver el prototipo web.

No marques producción implementada: el siguiente paso será revisar y corregir
esta vista previa antes de decidir qué portar a Flutter.
```

## Encargo de revisión posterior para retomar conmigo

> Revisa `artifacts/monetta-motion-preview-v2/` contra la investigación V2. Abre el prototipo, compara estático/propuesto y las dos soluciones de agregado. Corrige código y diseño dentro de esa carpeta, conservando evidencia antes/después. Retira cualquier efecto sin beneficio claro, cualquier duplicación de feedback y cualquier demora decorativa. Comprueba logo original, interrupciones, movimiento reducido, foco, variantes, doble toque y errores. Entrega selección final y resultados reales, sin integrar ni publicar todavía.

## Integración después de revisar

| Superficie | Trabajo previsto | Verificación necesaria |
|---|---|---|
| Bienvenida | Componente de logo aislado; sustituir entrada duplicada. | Cancelar antes de terminar, una reproducción, píxeles finales fieles. |
| Inicio técnico | Separar espera real de decoración de `StartupReveal`. | App lista accesible sin esperar la marca; conservar gestión de carga/error. |
| Producto/mini_cart | Elegir una confirmación y reutilizar contrato de carrito. | Doble toque, error sin falso éxito, foco al cerrar panel. |
| Galería/variante | Continuidad controlada y estado coherente. | Cambios rápidos, carga fallida, imagen decodificada y selección vigente. |
| Filtros | Reutilizar panel y selección. | Aplicar/cancelar, foco, datos persistentes y cero cascada de tarjetas. |
| Reseñas | Evaluar retirar avance automático existente. | Lectura sin interrupciones; anterior/siguiente accesibles. |

Usar APIs disponibles en Flutter 3.44.8 del proyecto. Verificar Reduce Motion de iOS y Remove animations de Android en dispositivos; no asumir cobertura solo por leer el helper. Los widget tests actualmente fuerzan movimiento reducido mediante `inWidgetTest`, así que también se necesita una comprobación que ejercite la ruta animada. Un navegador no sustituye el perfilado Flutter.

No se recomienda instalar Motion, GSAP, Lottie o Rive en la app por estas referencias. Los clips demuestran mecanismos; Flutter ya dispone de controladores, curvas, pintura y transiciones para una selección pequeña.
