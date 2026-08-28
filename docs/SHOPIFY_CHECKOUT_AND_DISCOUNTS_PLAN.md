# Plan de carrito, checkout, pagos y descuentos de Shopify

Estado: listo para ejecución incremental y auditoría por fase
Preparado: 2026-08-27
API objetivo: Shopify Storefront API `2026-07`
Entorno de implementación y prueba: `monetta-staging.myshopify.com`
Producción excluida sin autorización nueva: `monetta.mx` / `fakcei-n9` / `monetta-2`

Este documento es la fuente de verdad para terminar el tramo comercial de la
aplicación. Complementa, y para checkout reemplaza los detalles desactualizados
de la fase 3 de `SHOPIFY_PRODUCTION_IMPLEMENTATION_PLAN.md`.

## 1. Resultado objetivo

La app no debe implementar una pasarela propia ni recopilar números de tarjeta.
Debe:

1. mantener un carrito real en Shopify mediante Storefront Cart API;
2. dejar que Shopify valide inventario, precios, promociones y descuentos;
3. abrir el `checkoutUrl` dentro de Shopify Checkout Kit;
4. conservar la sesión del cliente de Customer Account API en checkout;
5. permitir que pagos externos regresen de forma segura a la app;
6. vaciar la bolsa local solamente después de una compra confirmada.

```text
Bolsa local (optimista/offline)
        │
        ▼
CartController + CartRepository ──► Shopify Storefront Cart (autoridad online)
        │                                      │
        │                                      ├─ inventario/precios
        │                                      ├─ descuentos/totales
        │                                      └─ buyer identity
        ▼
checkoutUrl validado ──► Checkout Kit ──► Shopify / proveedor externo
                                                │
                                                ▼
                              completed / cancelled / failed
```

Shopify continúa siendo la autoridad de pagos, impuestos, envío, promociones,
pedidos y PCI. El backend Monetta no debe recibir datos de tarjeta ni decidir si
un código comercial es válido.

## 2. Evidencia actual verificada

### Checkout real de `monetta.mx`

Una inspección de solo lectura del checkout real, sin completar una compra,
mostró:

- pago exprés: Shop Pay, PayPal y Google Pay;
- pago normal: tarjeta, PayPal, Mercado Pago y transferencia/depósito;
- campo para código de descuento.

Apple Pay no fue visible en Brave de escritorio. La tienda lo anuncia
públicamente, pero debe comprobarse en un iPhone físico elegible. Kueski Pay
también se anuncia públicamente, pero no apareció en ese checkout concreto. Los
métodos visibles dependen de configuración, mercado, dispositivo, navegador,
moneda y elegibilidad; la app no debe mantener una lista rígida ni prometer una
wallet antes de que Shopify la presente.

### Repositorio

- `lib/data/shopify/queries.dart` ya contiene `cartCreate`, operaciones de
  líneas, consulta de carrito y `checkoutUrl`.
- `lib/domain/cart.dart` y `lib/data/shopify/mappers.dart` representan solamente
  líneas, subtotal y cantidad; faltan descuentos, total, warnings y otros costos.
- No existen `cartDiscountCodesUpdate`, `cartBuyerIdentityUpdate` ni un
  repositorio/controlador de carrito operativo.
- `lib/features/checkout/checkout_screen.dart` define
  `SecureCheckoutLauncher`, pero `BagAction` llama `openBag(context)` sin
  launcher; la acción final muestra `_SecureHandoffPreview`.
- `checkout_sheet_kit_flutter: ^0.0.2` está declarado, pero no hay uso desde
  `lib/`. Es un wrapper Flutter de terceros alrededor de los SDK nativos de
  Shopify y debe auditarse antes de convertirlo en una dependencia de ingresos.
- `lib/app/motion.dart` calcula localmente envío gratis desde `$1,499` y una
  tarifa de `$149`. Puede seguir siendo una estimación claramente rotulada,
  nunca el total final ni la autoridad comercial.
- `ios/Runner/Runner.entitlements` solo declara notificaciones; no tiene
  Associated Domains.
- `android/app/src/main/AndroidManifest.xml` no tiene App Links de checkout.

## 3. Decisiones obligatorias

1. **Un solo carrito comercial:** Shopify Cart es la autoridad online. La bolsa
   local puede ser optimista y funcionar offline, pero debe reconciliarse antes
   de mostrar totales definitivos o abrir checkout.
2. **Guest-first:** comprar como invitado siempre funciona. El login mejora la
   precarga y el historial, pero nunca bloquea la compra.
3. **Sin SDKs de pago individuales:** no integrar PayPal, Mercado Pago, Shop
   Pay, Google Pay o Apple Pay directamente en esta fase. Shopify Checkout los
   presenta cuando corresponda.
4. **Apple Pay directo queda diferido:** un botón acelerado nativo antes de
   checkout es otro producto, con scopes/certificados/requisitos propios. No es
   requisito para Apple Pay dentro del checkout estándar.
5. **Descuentos validados por Shopify:** la app envía códigos y representa la
   respuesta; no duplica reglas de fechas, mínimos, productos o combinabilidad.
6. **Gift cards no son descuentos:** quedan fuera de este alcance salvo que el
   dueño las solicite explícitamente.
7. **Cart ID sensible:** el ID completo puede contener una clave. No imprimirlo,
   enviarlo a telemetría ni persistirlo en texto plano. Guardarlo en almacenamiento
   seguro, separado por tienda y sesión de comprador.
8. **Sin reintentos ciegos de mutaciones:** serializar escrituras por carrito.
   Ante respuesta ambigua, consultar el carrito antes de decidir repetir.
9. **No vaciar al presentar checkout:** solo ante evento `completed` confiable o
   pedido verificado. `cancelled` conserva la bolsa y `failed` ofrece reintento.
10. **Producción requiere una autorización independiente:** ninguna fase de
    código autoriza instalar, configurar pagos, crear pedidos o modificar
    `monetta.mx`.

## 4. Arquitectura propuesta

### Dominio

Ampliar o reemplazar `domain/cart.dart` con tipos inmutables y sin dependencia
de Flutter:

- `ShopifyCart`: ID, URL, timestamps, líneas, cantidad, identidad resumida,
  códigos, aplicaciones de descuento, costos y estado.
- `CartCost`: subtotal, total, impuestos si están disponibles, currency code y
  bandera de estimación.
- `CartDiscountCode`: código normalizado para presentación y `applicable`.
- `CartDiscountApplication`: tipo, título/descripción y valor aplicado cuando el
  schema lo permita.
- `CartMutationIssue`: `userError` o `warning`, campo/código seguro y mensaje
  presentable separado del detalle diagnóstico sanitizado.
- `CheckoutResult`: `completed`, `cancelled` o `failed`.

No guardar información de tarjeta, cookies del checkout ni URLs completas en
los modelos persistentes.

### Datos

Crear una capa dedicada, por ejemplo:

```text
lib/data/shopify/cart/
  cart_api.dart
  storefront_cart_api.dart
  cart_mapper.dart
  cart_repository.dart
  cart_session_store.dart
  cart_write_coordinator.dart
  checkout_url_policy.dart
```

Los nombres exactos pueden adaptarse al estilo del repositorio. Las
responsabilidades no deben mezclarse:

- `CartApi`: operaciones remotas tipadas.
- `CartRepository`: ciclo de vida, expiración, recuperación y reconciliación.
- `CartSessionStore`: cart ID en Keychain/Keystore y limpieza por cuenta/tienda.
- `CartWriteCoordinator`: una mutación a la vez y recuperación tras resultados
  ambiguos.
- `CheckoutUrlPolicy`: solo `https`, hosts Shopify/dominio configurado y sin
  esquemas arbitrarios.

### Aplicación/UI

Un `CartController` o extensión cohesionada de `CatalogStore` debe exponer:

- estado `idle/syncing/ready/stale/error`;
- carrito remoto más reciente;
- operación activa y errores presentables;
- `reconcileLocalBag()`;
- aplicar/quitar código;
- `prepareCheckout()`.

La UI no debe llamar GraphQL ni Checkout Kit directamente. El launcher concreto
se inyecta en el seam existente de `SecureCheckoutLauncher`.

## 5. Fases de implementación

Cada fase es una unidad de entrega y auditoría. No comenzar la siguiente hasta
que el auditor marque la actual como `APROBADA`.

### Fase 0 — preflight y decisión sobre Checkout Kit

Objetivo: fijar contratos y eliminar incertidumbres antes de tocar el flujo.

Tareas:

1. Registrar HEAD, archivos staged y cambios locales preexistentes; preservar
   especialmente cualquier cambio ajeno en `home_screen.dart`, sus tests y
   `motion.dart`.
2. Confirmar mediante documentación oficial el API `2026-07` usado por cada
   query nueva.
3. Auditar el código fuente, permisos y superficie del wrapper
   `checkout_sheet_kit_flutter`.
4. Elegir y documentar una de estas opciones:
   - fijar/auditar/forkear el wrapper; o
   - crear platform channels mínimos sobre los SDK oficiales de Shopify.
5. Definir interfaces de `CartApi`, sesión segura, coordinador y launcher antes
   de las implementaciones concretas.
6. Añadir tests de contrato inicialmente fallidos o fakes que permitan probar
   fases posteriores sin abrir checkout real.

Criterios de aceptación:

- decisión del bridge documentada con versión exacta y riesgo residual;
- ningún secreto, URL de checkout o cart ID en logs/tests/fixtures;
- interfaces permiten guest, comprador autenticado y los tres resultados de
  checkout;
- `flutter analyze`, tests afectados y escaneo de secretos pasan.

### Fase 1 — carrito remoto y reconciliación de bolsa

Objetivo: toda bolsa online tiene un Shopify Cart recuperable y consistente.

Tareas:

1. Completar fragmentos de carrito con `updatedAt`, `buyerIdentity`, `cost`,
   `discountCodes`, `discountApplications`, líneas y warnings requeridos.
2. Implementar y mapear `cartCreate`, query, add/update/remove y
   `cartBuyerIdentityUpdate` con `userErrors` y `warnings`.
3. Persistir el cart ID completo en almacenamiento seguro, particionado como
   mínimo por dominio/entorno y cuenta o invitado.
4. Detectar carrito inexistente/expirado y crear uno nuevo sin perder la bolsa.
5. Reconciliar por GID de variante y cantidad:
   - Shopify gana en disponibilidad y líneas aceptadas;
   - la app conserva localmente una intención no confirmada solo con estado
     explícito, nunca como si ya estuviera en Shopify;
   - evitar duplicados al recuperar tras timeout.
6. Serializar mutaciones y publicar un único snapshot coherente por operación.
7. Añadir los atributos no-PII definidos por `cart_attribution.dart`.

Criterios de aceptación:

- create/recover/expired/add/update/remove probados;
- concurrencia y timeout ambiguo probados sin duplicar cantidades;
- variantes agotadas o inválidas producen un estado seguro en español;
- reiniciar la app recupera el carrito sin imprimir su ID;
- el checkout aún no se presenta en esta fase.

### Fase 2 — descuentos y costos autoritativos

Objetivo: mostrar lo que Shopify calcula, no reglas duplicadas en Flutter.

Tareas:

1. Implementar `cartDiscountCodesUpdate` como reemplazo del conjunto completo.
2. Representar códigos aplicables y no aplicables sin afirmar que un código fue
   aceptado solo porque la mutación devolvió HTTP 200.
3. Renderizar descuento por código y descuentos automáticos desde
   `discountApplications`/costos devueltos.
4. Mostrar subtotal y total estimado de Shopify. Envío local `$149`/gratis debe
   rotularse como estimación o retirarse del resumen autoritativo hasta que
   Shopify tenga suficiente identidad/dirección para calcularlo.
5. Mantener los códigos ligados al cart ID; al crear un carrito sustituto,
   reaplicar solo códigos que el usuario todavía espera conservar y validar de
   nuevo.
6. Añadir UI accesible para aplicar, quitar, loading, inválido/no aplicable y
   error de red. El checkout de Shopify seguirá permitiendo editar códigos.

Criterios de aceptación:

- código válido, inválido, expirado/no aplicable, removido y combinaciones;
- descuento automático sin código;
- cambios de líneas vuelven a evaluar aplicabilidad y total;
- moneda y redondeo se presentan desde MoneyV2, sin cálculo binario local;
- ninguna gift card pasa por esta API.

### Fase 3 — Checkout Kit y ciclo de vida

Objetivo: reemplazar el preview por el checkout real de Shopify.

Tareas:

1. Implementar el bridge elegido en fase 0 con `preload`, `present` y eventos
   `completed/cancelled/failed` cuando estén disponibles.
2. Reconciliar bolsa, actualizar identidad y volver a consultar un
   `checkoutUrl` fresco inmediatamente antes de presentarlo.
3. Validar la URL con allowlist y sanitizar todos los errores/logs.
4. Inyectar el launcher desde el composition root; no importar el SDK desde la
   pantalla.
5. Impedir doble presentación por taps repetidos o reentrada de lifecycle.
6. En `completed`, limpiar bolsa/cart session de forma atómica y refrescar
   historial. En `cancelled`, conservar. En `failed`, conservar y permitir
   reintento.
7. Mantener fallback HTTPS externo controlado si Checkout Kit no puede abrir,
   sin degradar silenciosamente a una simulación.

Criterios de aceptación:

- configured build nunca muestra `_SecureHandoffPreview`;
- doble tap abre una sola hoja;
- cancel/error/reinicio conservan bolsa;
- completed limpia exactamente una vez;
- no se recopila ni observa información de tarjeta desde Flutter.

### Fase 4 — checkout autenticado

Objetivo: que el login real de Shopify continúe dentro del checkout sin romper
guest checkout.

Tareas:

1. Usar el `CustomerSessionRepository` existente como proveedor de sesión, sin
   crear un segundo login.
2. Implementar el flujo oficial vigente de Customer Account API + Checkout Kit.
   No asumir que cualquier token OAuth puede pegarse a una query o URL; seguir
   la receta `2026-07` y cubrir renovación/expiración.
3. Crear/actualizar buyer identity con email, teléfono, país y sesión de cliente
   según el flujo oficial; usar `sso=silent` cuando corresponda.
4. Asegurar que cambiar cuenta o cerrar sesión no reutiliza el carrito
   autenticado de otra persona. Definir migración segura de la bolsa guest.
5. No exponer access/refresh/id tokens a logs, Drift, errores o URLs.

Criterios de aceptación:

- invitado compra sin login;
- cliente autenticado ve checkout precargado con su identidad;
- token vencido degrada a recuperación/login o guest sin perder bolsa;
- logout/cambio de cuenta separa los carritos;
- pruebas no confunden Customer Account API token con credenciales legacy.

### Fase 5 — retorno de pagos externos

Objetivo: PayPal/Mercado Pago y cualquier redirect externo pueden volver a la
app sin enlaces abiertos de más.

Tareas:

1. Elegir el dominio HTTPS autorizado para retorno. Staging y producción deben
   tener asociaciones separadas.
2. iOS: añadir Associated Domains mínimos y publicar/verificar
   `apple-app-site-association` con bundle/team correctos.
3. Android: añadir intent filter HTTPS restringido y publicar/verificar
   `/.well-known/assetlinks.json` con package y fingerprints correctos.
4. Integrar el mecanismo de retorno recomendado por Checkout Kit; no tratar un
   simple deep link como prueba de pago completado.
5. Validar hosts, paths y estado del checkout. Rechazar esquemas/hosts no
   permitidos.

Criterios de aceptación:

- enlaces ajenos no abren flujo privilegiado;
- retorno válido reanuda la misma sesión de checkout;
- cancelación en proveedor conserva bolsa;
- iOS y Android prueban retorno en dispositivo/emulador apropiado;
- archivos públicos de asociación se verifican por HTTPS.

### Fase 6 — aceptación comercial en staging

Objetivo: demostrar el flujo completo sin tocar producción.

Requiere autorización puntual del dueño antes de crear cualquier pedido de
prueba, aunque el entorno sea staging.

Matriz mínima:

- guest y cliente autenticado;
- carrito nuevo, recuperado y expirado;
- inventario cambia antes de pagar;
- código válido, inválido, no aplicable, removido y descuento automático;
- cancelación y reapertura;
- pago de prueba soportado por la dev store;
- retorno offsite simulado/permitido;
- evento `completed`, bolsa limpia e historial/pedido coherente;
- iOS físico para Apple Pay estándar si el entorno/configuración lo permiten;
- Android compatible para Google Pay si el checkout lo presenta.

Shop Pay, PayPal, Mercado Pago, Google Pay, Apple Pay o Kueski solo se marcan
como verificados cuando el checkout realmente los presenta en un contexto
elegible. La ausencia en staging no se corrige creando SDKs paralelos.

Criterios de salida:

- pruebas locales completas y `git diff --check` pasan;
- escaneo de secretos incluye tracked y untracked candidatos a commit;
- evidencia visual sanitizada de bolsa, descuentos y checkout;
- ningún dato de pago, token, cart ID o checkout URL queda en artefactos;
- reporte distingue evidencia observada de inferencias;
- auditor aprueba la fase y lista riesgos residuales antes de producción.

## 6. Estrategia de pruebas

### Unitarias

- mappers MoneyV2, códigos, aplicaciones, warnings y errores;
- transición del controlador y exclusión de escritores;
- reconciliación por GID y recuperación tras timeout;
- URL policy y redacción de cart IDs/checkout URLs;
- separación guest/cuentas y expiración;
- lifecycle completed/cancelled/failed.

### Widget

- estados de bolsa y descuento, accesibilidad y doble tap;
- total Shopify versus estimación de envío;
- invalidación de código al cambiar líneas;
- preview solo en builds explícitamente no configurados.

### Integración local con fake transport/bridge

- secuencia create → mutate → discount → refresh URL → present;
- carrito expirado y recreado;
- cancelación/reanudación;
- cliente autenticado y guest.

### Staging

- Storefront API real contra `monetta-staging.myshopify.com`;
- Checkout Kit real sin registrar secretos en comandos;
- pruebas de pedido únicamente con autorización puntual;
- nunca usar productos, clientes o pagos de producción para aceptación inicial.

Comandos base, ajustados a los archivos afectados:

```bash
flutter analyze
flutter test --reporter compact
npm run typecheck:api
npm run test:api
npm run build:web
./bin/check_no_secrets.sh
git diff --check
```

No ejecutar herramientas Node/API si una fase no las afecta salvo como gate
final. Toda excepción debe justificarse en el reporte.

## 7. Definition of Done total

El sistema queda terminado cuando:

- la bolsa local se reconcilia con un Shopify Cart persistente;
- Shopify es la fuente de precios, inventario, descuentos y total estimado;
- descuento válido/no válido y promociones automáticas se reflejan correctamente;
- Checkout Kit abre una URL fresca y validada;
- guest y cliente autenticado llegan al checkout correcto;
- pagos externos pueden volver de forma segura;
- cancel/error preservan la bolsa y completed la limpia una vez;
- existe aceptación en iOS y Android staging;
- no hay secretos ni datos de pago en código, logs o artefactos;
- no se realizaron mutaciones en producción sin una autorización nueva.

## 8. Fuentes oficiales

- Mobile commerce y Checkout Kit: <https://shopify.dev/docs/storefronts/mobile>
- Carrito Storefront: <https://shopify.dev/docs/storefronts/headless/building-with-the-storefront-api/cart/manage>
- Objeto Cart `2026-07`: <https://shopify.dev/docs/api/storefront/latest/objects/Cart>
- Descuentos: <https://shopify.dev/docs/api/storefront/latest/mutations/cartDiscountCodesUpdate>
- Checkout autenticado: <https://shopify.dev/docs/storefronts/mobile/checkout-kit/authenticate-checkouts>
- Pagos offsite: <https://shopify.dev/docs/storefronts/mobile/checkout-kit/offsite-payments>
- Checkout acelerado: <https://shopify.dev/docs/storefronts/mobile/checkout-kit/accelerated-checkouts-overview>
