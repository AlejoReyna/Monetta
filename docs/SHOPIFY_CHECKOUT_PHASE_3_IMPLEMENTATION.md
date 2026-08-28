# Shopify Checkout Kit — Fase 3

Estado: implementación lista para auditoría independiente. Esta entrega no
inicia autenticación de checkout ni hace llamadas a Shopify.

Fecha de verificación local: 2026-08-28.

## Decisión y versiones fijadas

La aplicación usa los SDK oficiales nativos detrás de un `MethodChannel`
mínimo. No hay un wrapper Flutter de Checkout Kit en `pubspec.yaml` ni en
`pubspec.lock`.

Las versiones quedan fijadas sin rangos abiertos:

- iOS: `ShopifyCheckoutSheetKit 3.8.1`, dependencia directa y exacta en
  `ios/Podfile` y `ios/Podfile.lock`.
- Android: `com.shopify:checkout-sheet-kit:3.6.1`, dependencia directa y exacta
  en `android/app/build.gradle.kts`.

La versión Android `3.6.1` está publicada en el repositorio oficial y es la
versión aprobada en la decisión de Fase 0. El repositorio también muestra
versiones posteriores; no se cambia el pin aprobado sin una revisión de
compatibilidad separada.

Requisitos aplicados en el proyecto:

- iOS 13.0 o posterior y compilador Swift 5.7 o posterior.
- Android `minSdk 24` (Checkout Kit requiere 23 o posterior), `compileSdk 36`
  (Checkout Kit requiere 35 o posterior), JDK 17 y Chrome 80 o posterior en el
  dispositivo/emulador.

Distribución nativa aplicada:

- iOS: CocoaPods directo y exacto en `ios/Podfile`; Checkout Sheet Kit también
  documenta Swift Package Manager como alternativa oficial, pero este target no
  mezcla ambos gestores.
- Android: dependencia Maven declarada directamente con Gradle en
  `android/app/build.gradle.kts`; no se usa un plugin Flutter de Checkout Kit.

Evidencia oficial:

- [Shopify Checkout Kit para móvil](https://shopify.dev/docs/storefronts/mobile/checkout-kit)
- [Checkout Sheet Kit Swift](https://github.com/Shopify/checkout-sheet-kit-swift)
- [Release iOS 3.8.1](https://github.com/Shopify/checkout-sheet-kit-swift/releases/tag/3.8.1)
- [Checkout Sheet Kit Android](https://github.com/Shopify/checkout-sheet-kit-android)
- [Release Android 3.6.1](https://github.com/Shopify/checkout-sheet-kit-android/releases/tag/3.6.1)
- [Preloading oficial](https://shopify.dev/docs/storefronts/mobile/checkout-kit/preloading)

## Contrato y flujo

`CheckoutLauncher` expone únicamente `preload`, `present` e `invalidate`.
`MethodChannelCheckoutLauncher` traduce solo los estados terminales
`completed`, `cancelled` y `failed`; mensajes, errores nativos, datos de orden,
datos de cliente, datos de pago, cookies, tokens y Web Pixels no cruzan el
canal.

`ShopifyCheckoutCoordinator` es el único dueño del flujo:

1. La composición crea objetos y no invoca red, `preload` ni `present`.
2. La bolsa puede hacer `preload` solo con una reconciliación autoritativa.
3. `present` vuelve a reconciliar inmediatamente antes de abrir la hoja.
4. Solo el `checkoutUrl` de ese carrito autoritativo se valida y se entrega al
   launcher.
5. La política exige HTTPS, host exacto de `StorefrontConfig`, ruta no vacía,
   sin puerto explícito, fragmento, espacios, credenciales ni barras
   invertidas, ni valores de query que sean URLs absolutas o destinos de
   redirección. Los errores son redacted y nunca contienen la entrada.
6. Hay un solo `present` en vuelo en Dart y otro guard en cada puente nativo.
   El primer evento terminal gana; un cierre posterior de la hoja no se
   convierte en una segunda finalización.
7. `cancelled` y `failed` no alteran la bolsa. `completed` borra la sesión
   remota y la bolsa local una sola vez después del evento confiable del SDK;
   luego invalida la caché nativa.

El fallback de navegador es explícito, usa la misma URL ya validada, no implica
completion y también se serializa. No se agregan Universal Links/App Links
en esta fase.

## Puentes nativos

- `ios/Runner/ShopifyCheckoutBridge.swift` configura el SDK con logging
  desactivado, rechaza URLs estructuralmente inseguras, presenta desde el
  controlador visible y no abre enlaces externos ni concede permisos web.
  `ios/Runner.xcodeproj/project.pbxproj` incluye el archivo en el target.
- `android/.../ShopifyCheckoutBridge.kt` usa `FlutterFragmentActivity`, el
  processor oficial de eventos, logging en `ERROR`, recuperación automática
  desactivada, permisos WebView denegados y enlaces externos sin acción.
  Destruir la actividad termina un checkout pendiente como fallo seguro.

El checkout alojado de Shopify conserva shipping, descuentos y todos los
métodos de pago habilitados por Shopify. Monetta no implementa ni almacena
formularios de pago.

## Dependencias históricas

Se retiró el wrapper `checkout_sheet_kit_flutter` de `pubspec.yaml`,
`pubspec.lock` y `ios/Podfile.lock`. CocoaPods ahora resuelve directamente
`ShopifyCheckoutSheetKit (= 3.8.1)`; el `Manifest.lock` generado local coincide
con el lockfile rastreado. Se eliminó únicamente el podspec local generado del
wrapper retirado; no se tocaron archivos de home/Loox ni cambios de Fases 1–2.

## Evidencia observada e inferida

Observado localmente: los archivos de composición, canal, bridges, pins de
dependencias y pruebas focalizadas están presentes; el artefacto local de iOS
expone la API 3.8.1 usada por el bridge y el artefacto local Android 3.6.1 está
cacheado. `flutter analyze` terminó sin issues; las focalizadas terminaron con
35 pruebas y la suite completa con 416 pruebas, todas verdes. `xcodebuild` del
workspace iOS terminó `BUILD SUCCEEDED`. `./gradlew :app:assembleDebug
--offline` terminó `BUILD SUCCESSFUL` con el JDK embebido de Android Studio.
La verificación usó OpenJDK 25.0.2, que satisface el mínimo oficial JDK 17+.
Los warnings observados fueron de deprecaciones Gradle/AGP y targets de Pods o
plugins existentes.

Inferido de la documentación/API oficial: Shopify emite los callbacks
terminales y procesa el pedido/pago dentro del checkout alojado. La prueba
real en dispositivo, con una URL de checkout, queda fuera de esta fase por
política y no se ejecutó.
