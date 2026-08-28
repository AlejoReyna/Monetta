# Fase 0 — decisión de Checkout Kit y contratos

Fecha de decisión: 2026-08-27
Storefront API fijada: `2026-07`
Entorno permitido: `monetta-staging.myshopify.com`
Producción: fuera de alcance

## Decisión

Monetta no usará `checkout_sheet_kit_flutter 0.0.2`. Se retira la dependencia y
la fase 3 implementará platform channels mínimos sobre los SDKs oficiales,
fijados inicialmente a estas versiones estables exactas:

- iOS: `ShopifyCheckoutSheetKit 3.8.1`;
- Android: `com.shopify:checkout-sheet-kit:3.6.1`.

Las versiones deben volver a verificarse contra los releases oficiales al
comenzar la fase 3. Un cambio de versión requiere repetir la revisión de código,
permisos, eventos y notas de release; no se aceptan rangos abiertos.

## Evidencia oficial de Storefront API 2026-07

La documentación oficial `2026-07` confirma los contratos que usarán las fases
1 y 2:

| Operación | Contrato confirmado |
|---|---|
| `cartCreate` | acepta `CartInput`; devuelve `cart`, `userErrors` y `warnings` |
| `cart(id:)` | devuelve el carrito o `null`; `checkoutUrl` pertenece a Shopify |
| `cartLinesAdd/Update/Remove` | reciben cart/line IDs y devuelven `cart`, `userErrors`, `warnings` |
| `cartBuyerIdentityUpdate` | recibe `CartBuyerIdentityInput`; soporta guest y `customerAccessToken` |
| `cartDiscountCodesUpdate` | `discountCodes` es obligatorio y reemplaza el conjunto completo |
| `Cart` | expone `updatedAt`, `buyerIdentity`, `cost`, `discountCodes`, `discountApplications`, líneas y cantidad |
| payloads de mutación | HTTP/GraphQL success no sustituye revisar `userErrors` y `warnings` |

Referencias:

- <https://shopify.dev/docs/api/storefront/2026-07/mutations/cartCreate>
- <https://shopify.dev/docs/api/storefront/2026-07/queries/cart>
- <https://shopify.dev/docs/api/storefront/2026-07/mutations/cartLinesAdd>
- <https://shopify.dev/docs/api/storefront/2026-07/mutations/cartLinesUpdate>
- <https://shopify.dev/docs/api/storefront/2026-07/mutations/cartLinesRemove>
- <https://shopify.dev/docs/api/storefront/2026-07/mutations/cartBuyerIdentityUpdate>
- <https://shopify.dev/docs/api/storefront/2026-07/mutations/cartDiscountCodesUpdate>
- <https://shopify.dev/docs/api/storefront/2026-07/objects/Cart>

No se añadió ni ejecutó ninguna query en esta fase.

## Auditoría del wrapper retirado

Artefacto resuelto localmente:

- paquete: `checkout_sheet_kit_flutter 0.0.2`;
- lockfile SHA-256:
  `9a8893b5d41bd9d7d66b57e5c1dc239ac222dbad036f6e00d02b328d0a11593e`;
- publisher de pub.dev: `masterfabric.co`, no Shopify;
- repositorio declarado: `github.com/Shopify/checkout-sheet-kit-flutter`, que
  devuelve 404 al momento de la revisión;
- Android transitivo: `com.shopify:checkout-sheet-kit:3.0.5`;
- iOS transitivo: rango CocoaPods `ShopifyCheckoutSheetKit ~> 3.0`, no una
  versión exacta; el podspec además declara versión `0.0.1` para un paquete
  Dart `0.0.2`.

Hallazgos que impiden usarlo en la ruta de ingresos:

1. iOS imprime el `checkoutUrl` completo mediante `print` durante `present`.
2. Android concede todos los recursos pedidos por el WebView en
   `onPermissionRequest`, incluyendo cámara/micrófono, sin una política mínima.
3. El channel entrega a Dart email, teléfono, dirección de facturación,
   métodos/detalles de pago, cart token, líneas, píxeles y links arbitrarios.
4. Android devuelve mensajes, causas y stack traces nativos por el channel.
5. Un único `pendingResult` global puede ser reemplazado por presentaciones
   concurrentes; el wrapper no impide doble presentación.
6. Su superficie excede lo necesario y sus SDKs nativos quedan varias versiones
   detrás de los releases oficiales revisados.

La documentación oficial de Checkout Kit enumera soporte directo para Swift,
Kotlin/Android y React Native, no Flutter:
<https://shopify.dev/docs/storefronts/mobile/checkout-kit>.

## Límite del platform channel para fase 3

El bridge nativo tendrá únicamente:

- `preload(checkoutUrl)`;
- `present(checkoutUrl)`;
- `invalidate()`;
- resultado terminal `completed`, `cancelled` o `failed`;
- para `failed`, solo un código cerrado y un mensaje seguro localizado.

No cruzarán a Dart:

- order/customer/payment details;
- email, teléfono o direcciones observadas dentro de checkout;
- cart token o cart ID;
- web pixels;
- URLs de links pulsados;
- stack traces, errores subyacentes o el checkout URL en logs.

En Android, permisos WebView se deniegan por defecto. Cualquier excepción futura
requiere UX, permiso de sistema, host/recurso restringido y auditoría separada.
Links externos se resolverán nativamente con política explícita. El bridge
aceptará una sola presentación en vuelo y el primer resultado terminal ganará.

## Contratos fijados en fase 0

- `CartApi`: create/get/add/update/remove, buyer identity y reemplazo completo
  de descuentos, con `userErrors` y `warnings` tipados.
- `CartSessionStore`: cart ID sensible en almacenamiento seguro, particionado
  por tienda/entorno y guest/cuenta local.
- `CartWriteCoordinator`: una escritura por sesión y recuperación por lectura
  tras un resultado ambiguo, sin repetir la mutación a ciegas.
- `CheckoutLauncher`: preload/present/invalidate y los tres resultados, sin
  importar ningún SDK desde UI.

Los wrappers de cart ID, token y checkout URL redactan `toString`. Los fakes de
prueba no abren checkout ni contienen identificadores o URLs reales.

## Riesgo residual y trabajo diferido

- Los SDKs nativos aún no están instalados ni ejecutados; eso pertenece a fase
  3 después de aprobar las fases 0–2.
- Compatibilidad real de Gradle/CocoaPods, lifecycle, permisos y dispositivos
  se demuestra en fase 3/6, no en este documento.
- El constructor de `ValidatedCheckoutUrl` presupone que la política de allowlist
  ya fue aplicada. La política concreta y sus pruebas adversariales pertenecen
  a fase 3.
- La implementación segura de Keychain/Keystore y la serialización real del
  coordinador pertenecen a fase 1.
- Checkout autenticado debe volver a contrastarse con la receta vigente de
  Customer Account API al iniciar fase 4.
