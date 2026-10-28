# Plan: Monetta se escribe letra por letra

**Elegir inicialmente A: revelado individual del logo original, durante 1 segundo.** Comparar con B: escritura por trazos, aproximadamente 1.2 segundos. Ambas terminan en exactamente la misma imagen de marca, sin cursor, sonido, brillo itinerante ni repetición. El nombre correcto del activo es **MONETTA**, siete letras y dos T.

## Diferencia entre las dos variantes

| | A — letra por letra | B — trazos dentro de cada letra |
|---|---|---|
| Apariencia | Cada letra aparece con un pequeño revelado local, en orden. | La tinta parece recorrer cada letra antes de pasar a la siguiente. |
| Base | PNG original recortado mediante máscaras individuales. | PNG original + máscaras de recorrido o vector fiel + recorridos de escritura. |
| Fidelidad | Alta si las máscaras están bien separadas. | Requiere trabajo manual: los contornos exteriores de una letra no son su recorrido caligráfico. |
| Coste | Medio; no requiere rediseñar el logo. | Alto; inspeccionar M, gota izquierda, serifas y unión visual de las dos T. |
| Decisión | Primera candidata de producción. | Alternativa visual para comparar; nunca simplificar la tipografía para facilitar el efecto. |

El SVG existente en `docs/web-redesign/shopify-staging/branding-signin-2026-10-22/` incrusta un PNG. No se puede conseguir escritura correcta poniéndole `stroke-dasharray` a ese archivo. Tampoco funciona dividir el ancho en siete partes iguales: las letras tienen anchos diferentes y remates próximos.

## Activo y construcción

1. Usar `assets/images/3.0x/logo_monetta.png`, con proporciones y transparencia intactas. Inspeccionar también sus variantes 1x/2x antes de exportar. No reescribir MONETTA con Playfair, Times o una fuente parecida.
2. Crear siete regiones de máscara con coordenadas normalizadas, registradas en `logo-masks.json`. Ajustar manualmente límites y contornos: una M incluye su ornamento izquierdo; cada T debe revelarse independientemente sin cortar remates de la otra.
3. Mantener una caja fija del tamaño final, centrada desde el primer frame. Las letras se revelan en su posición definitiva; no centrar el texto parcial ni hacer crecer el ancho del contenedor.
4. Variante A: revelar dentro de cada región de arriba abajo con borde suavizado mínimo; las regiones se activan secuencialmente. Si esa dirección se ve artificial, probar una aparición por opacidad dentro de cada letra. No usar un barrido horizontal único como sustituto.
5. Variante B: dibujar recorridos centrales de escritura para cada letra y usarlos como máscara sobre el PNG. El trazo debe cubrir astas, curvas y serifas; al concluir cada letra, completar su máscara sin salto perceptible. No animar solo el contorno exterior. Entregar los recorridos editables.
6. Comparar el frame final contra el PNG estático a igual escala: ninguna letra redibujada, desplazada, deformada, recoloreada o recortada. Para A se puede verificar diferencia de píxeles; para B revisar también el fotograma anterior al reemplazo final para detectar saltos.

## Guion temporal A

| Intervalo | Acción |
|---|---|
| 0–220 ms | Revelar M y su ornamento como una sola letra. |
| 220–350 ms | O. |
| 350–480 ms | N. |
| 480–610 ms | E. |
| 610–740 ms | Primera T. |
| 740–870 ms | Segunda T. |
| 870–1000 ms | A. |
| Desde 1000 ms | Logo estático, sin pausa obligatoria ni salida automática. |

Probar a tamaño aproximado de 240 px de ancho en la escena de bienvenida y al tamaño real de `MonettaWordmark(height: 42)`. No reproducir la escritura en los encabezados pequeños: ahí permanece estático.

## Cuándo se reproduce

- Primera bienvenida editorial de una instalación/perfil local, mediante la regla existente de `WelcomeGate`; no añadir un segundo almacenamiento que contradiga esa regla.
- Comenzar funciona durante toda la animación: al tocar, cancelar controlador y continuar inmediatamente.
- Reabrir la app, regresar desde checkout, cambiar de pestaña o reconstruir un widget no vuelve a reproducirla. El laboratorio tendrá un botón explícito Repetir.
- Con movimiento reducido, cargar desde el primer frame el logo completo. Una sola etiqueta accesible «Monetta», nunca siete anuncios sucesivos.
- Si se cambia la preferencia mientras se reproduce, mostrar el final y cancelar. Al ir a segundo plano, suspender; al regresar, terminar estáticamente en vez de reiniciar.
- La pantalla de lanzamiento nativa permanece estática. Si se decide usar el efecto en el arranque técnico, sustituir el efecto anterior y no bloquear una app ya lista para completar la marca. No encadenar splash, escritura y bienvenida.

## Integración prevista, después de validar las vistas

**Flutter:** crear un componente específico `MonettaAnimatedWordmark` junto a los componentes de marca. Un controlador, siete intervalos y máscaras sobre el mismo activo; `ClipPath`/pintura personalizada según complejidad. Encapsular repintado y preservar semántica única. Liberar el controlador y atender cambios de accesibilidad/ciclo de vida. `MonettaWordmark` sigue siendo la versión estática reutilizable. Evitar que cada reconstrucción reinicie la animación.

**Bienvenida:** sustituir únicamente la presentación del logo en `lib/features/welcome/welcome_screen.dart`; evitar sumar el `_Entrance` existente al nuevo efecto. Revisar por separado `lib/app/startup_reveal.dart` para eliminar la espera decorativa tras `ready`, manteniendo el tratamiento real de carga.

**Vista previa web:** SVG con máscaras sobre `<image>` o capas recortadas; CSS/WAAPI y JavaScript pequeño para reproducción y cancelación. Un PNG estático como fallback sin JavaScript. No se requiere GSAP, Lottie o Rive para esta complejidad.

**Shopify cuentas/checkout:** no trasladar automáticamente esta implementación al GIF existente. Son superficies gestionadas y requieren otro análisis de capacidades. Un GIF no proporciona el mismo control de preferencia/cancelación; no es la entrega principal de esta propuesta.

## Criterios de aceptación

- Se distinguen M → O → N → E → T → T → A; no es un efecto de máquina de escribir con otra fuente.
- El frame final coincide con la marca y el contenedor no cambia de tamaño ni de centro.
- La versión A dura 1000 ms; B parte de 1200 ms y debe justificar cualquier aumento. Ninguna espera artificial impide navegar.
- Capturar al menos 0, 220, 480, 740 y 1000 ms de A, más video continuo y comparación con marca estática.
- Probar pulsar Comenzar a los 100 ms, desmontar, volver, cambiar movimiento reducido y mandar a segundo plano.
- Probar a 320/390/430 px de viewport y con texto ampliado. No declarar rendimiento móvil a partir del navegador: se requiere posteriormente perfilado Flutter en dispositivo físico.
