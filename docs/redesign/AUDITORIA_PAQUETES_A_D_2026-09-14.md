# Auditoría de paquetes de rediseño — 14 de septiembre de 2026

## Alcance y veredicto

Revisión del árbol de trabajo local, incluidos cambios sin commit, de los paquetes A–F del rediseño. Se contrastaron implementación, conexiones entre pantallas, documentos de entrega y pruebas. No se modificó código de implementación. Esta auditoría no certifica el backend ni una versión desplegada.

E y F son los paquetes grandes pendientes de rediseño. A–D tienen implementación, pero no deben considerarse terminados: hay un bloqueo de compilación, conexiones faltantes y errores funcionales. El brief nuevo de Rewards sustituye la propuesta visual de puntos y niveles; exige además trabajo transversal fuera de F.

| Paquete | Evidencia implementada | Estado de cierre |
| --- | --- | --- |
| A: bienvenida, onboarding, Home | Welcome/gate, tokens boutique, nuevas secciones Home y onboarding | Parcial. Falta validación visual con tipografías reales y cerrar integración compartida. |
| B: búsqueda, catálogo, colección, marca | Controles, consultas/filtros, tarjeta compartida, historial y pantalla de marca | Parcial. Bloquea compilación; historial sin persistencia conectada. |
| C: producto y vista rápida | Ficha, selección de variantes, modal y pruebas/capturas | Parcial. Modal sin entrada desde pantallas reales; capturas insuficientes para aprobar fidelidad. |
| D: bolsa, checkout y confirmación | Bolsa/resumen y nueva confirmación | Parcial. Identificación de pedido, navegación y estimación de entrega necesitan corrección. |
| E: cuenta, favoritos, pedidos, seguimiento, contacto, notificaciones | Existen capacidades base de cuenta y pedidos | Pendiente de completar el rediseño del paquete; no equivale a ausencia total de funcionalidad. |
| F: mayoreo, catálogo compartible y Rewards | Existe base de partner hub; Rewards tiene plan | Pendiente. Rewards monetario requiere backend y conexión con A/C/D/E, no solo una pantalla. |

## Hallazgos que impiden cerrar A–D

### 1. P1 — El proyecto no supera análisis por una API incompatible entre A y B

`lib/features/catalog/catalog_controls.dart:319` pasa `onPhoto` al constructor por defecto de `BoutiqueButton`. Ese constructor no declara el parámetro; existe un constructor nombrado `BoutiqueButton.onPhoto` en `lib/features/boutique/boutique_tokens.dart`.

Resultado observado: `flutter analyze --no-pub` reporta `undefined_named_parameter`. La suite de pantallas falla al compilar por el mismo motivo. Corregir el contrato compartido antes de continuar con aceptación visual; asignar un responsable de integración A/B.

### 2. P1 — La confirmación puede atribuir a la compra un pedido anterior

`lib/features/checkout/checkout_screen.dart:507` toma el primer `displayNumber` no vacío de la lista de pedidos de la cuenta. No correlaciona ese pedido con el checkout recién completado. Si la sincronización aún no incluye el nuevo pedido, puede presentar el número de uno anterior.

El resultado `CheckoutCompleted` no aporta actualmente identidad de pedido. Propagar una identidad autoritativa y resolverla en el historial, o mantener la confirmación sin número mientras se sincroniza. No sustituir esa correlación por elegir el primer registro. Probar explícitamente una cuenta con pedidos anteriores y sincronización demorada.

### 3. P2 — «Ver pedido» vuelve al inicio

`lib/features/checkout/order_confirmation_screen.dart:182` usa `popUntil(isFirst)` si no recibe `onViewOrder`. La llamada real desde `checkout_screen.dart:522` no suministra ese callback. Por tanto, el botón ejecuta el mismo destino que «Seguir comprando».

Conectar al detalle del pedido identificado o a Mis pedidos, contemplando invitado y sincronización pendiente. Verificar el destino pulsando el botón; comprobar solo que existe el texto no cubre este comportamiento.

### 4. P2 — La vista rápida existe, pero no está conectada al flujo del usuario

`lib/features/product/quick_view.dart:38` define `showProductQuickView`. En `lib` no se encontró una invocación real desde una pantalla: los demás usos son documentación o propiedades opcionales reenviadas por la tarjeta. Los tests pueden abrir el modal artificialmente, pero eso no demuestra acceso desde Home o catálogo.

Conectar una acción visible y accesible en la tarjeta compartida y verificarla desde pantallas reales. Además, al pasar del modal a la ficha, `_viewFullProduct` llama `openProduct` sin conservar la variante seleccionada (`quick_view.dart:119`); cerrar ese contrato al integrar.

### 5. P2 — La fecha de entrega contradice los días hábiles anunciados

`lib/features/checkout/order_confirmation_screen.dart:22` suma 3 y 5 días naturales desde el reloj local. La pantalla anuncia «3 a 5 días hábiles». Tampoco utiliza una estimación específica del envío del pedido.

Usar la estimación logística real cuando exista. Si solo hay una política de entrega, mostrarla sin fabricar fechas; cualquier cálculo de días hábiles requiere calendario y regla operativa definidos. Las pruebas actuales de la función verifican la suma de días naturales, no la promesa comercial.

### 6. P2 — El historial de búsqueda no sobrevive al reinicio

`lib/features/catalog/search_history.dart:50` crea la instancia compartida sin `SearchHistoryPersistence`. Existe el puerto opcional, pero no se encontró un adaptador conectado. El historial opera en memoria; no debe marcarse la persistencia como entregada.

Conectar almacenamiento y probar reinicio, limpieza y separación entre cuentas. La separación en memoria ya existe; este hallazgo no implica una filtración entre usuarios.

## Pendientes de diseño y aceptación

- `pubspec.yaml` no registra Playfair Display ni Inter como fuentes. Declarar sus nombres en estilos no asegura que se rendericen. Registrar la fuente elegida y comprobar en dispositivo antes de aprobar tipografía.
- `lib/features/navigation/monetta_bottom_navigation.dart:9` conserva cuatro destinos: Home, catálogo, bolsa y cuenta. Sigue pendiente resolver la navegación objetivo del plan y la referencia, junto con E.
- Las capturas guardadas `test/features/product/goldens/c-ficha-clara.png` y `c-quick-view.png` muestran texto de prueba como bloques, iconos faltantes y áreas de producto vacías. Sirven como comprobación limitada de estructura, no como evidencia de parecido visual con la lámina.
- El handoff de A reconoce imágenes provisionales y el de B reconoce contratos de tamaño de tarjetas por resolver con Home y la ficha. Validar imágenes finales, rejillas, carruseles, textos largos y escalado de texto una vez restaurada la compilación. No se afirma un desbordamiento reproducido en esta auditoría.
- La pantalla de marca existe; Home aún entra a colección por marca y desde colección se puede llegar a marca. Revisar ese recorrido y conectar contenido editorial real antes de considerarlo el flujo final.

Referencia persistente: `docs/design-reference/monetta-client-layout.png`. Documentos de entrega examinados: `docs/REDISENO_PAQUETE_A.md` y `docs/redesign/paquete-b-catalogo.md`.

## Verificación ejecutada

Toolchain local: `/Users/alexis/develop/flutter/bin/flutter`, Flutter 3.44.8 / Dart 3.12.2.

1. `flutter analyze --no-pub`: falló. Un error por `onPhoto`; dos advertencias adicionales por import sin uso en Home y parámetro opcional sin uso en onboarding.
2. `flutter test --no-pub test/features/welcome test/features/onboarding test/features/home test/features/catalog test/features/product test/features/checkout --reporter expanded`: bloqueada en compilación por el mismo error. Se detuvo después de fallos repetidos; no se presenta como suite completada.
3. `flutter test --no-pub test/features/catalog/search_history_test.dart test/features/checkout/order_confirmation_test.dart --reporter expanded`: 12 pruebas pasaron. No prueban el checkout completo, persistencia tras reinicio ni conexión real del modal.
4. `dart format --output=none --set-exit-if-changed` sobre las carpetas revisadas: 47 archivos revisados, 8 requieren formato. Solo comprobación; no escribió formato.
5. Inspección visual de las dos capturas C mencionadas. No se generó una captura de la app actual funcionando debido al bloqueo de compilación.

## Orden de cierre recomendado

1. Resolver contrato A/B de `BoutiqueButton` y conseguir análisis sin errores.
2. Corregir correlación del pedido, «Ver pedido» y entrega estimada en D.
3. Conectar quick view B/C, conservar variante y conectar persistencia de búsqueda B.
4. Registrar fuentes, resolver navegación compartida y ejecutar pruebas de A–D más capturas con contenido real. Revisar flujo completo, teléfonos estrechos y texto ampliado.
5. Completar E y F usando contratos compartidos estables. Pueden avanzar en paralelo en superficies independientes, pero no declarar A–D cerrados ni iniciar aceptación final con el bloqueo actual.
6. Tratar Rewards monetario como iniciativa transversal conforme a `docs/MONETTA_REWARDS_V1_PLAN.md`. No implementar la antigua figura de puntos/niveles. Mínimos de compra para incentivos y uso de saldo en mayoreo siguen sin definición del cliente.

Criterio de cierre: compila, pruebas de flujo relevantes pasan, las acciones llevan al destino correcto con datos correlacionados, hay capturas legibles con fuentes/imágenes reales y se documentan las decisiones comerciales todavía pendientes.
