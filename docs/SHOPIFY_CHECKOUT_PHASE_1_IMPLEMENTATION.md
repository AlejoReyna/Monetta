# Fase 1 — carrito remoto y reconciliación

Fecha: 2026-08-27
Storefront API: `2026-07`
Estado: implementación local lista para auditoría; sin validación contra staging

## Invariantes implementados

- Shopify Cart es la autoridad online. La bolsa local aporta intención por GID
  canónico de `ProductVariant` y cantidad; cualquier diferencia aceptada por
  Shopify queda marcada como intención no confirmada.
- El cart ID completo se conserva únicamente mediante
  `flutter_secure_storage`, particionado por dominio y por invitado/cuenta
  local. No se persisten checkout URLs, tokens ni PII en esta capa.
- Las escrituras se serializan por sesión. El transporte de mutaciones realiza
  un solo intento; si el resultado es ambiguo, el repositorio consulta
  `CartApi.get` y no repite automáticamente la mutación.
- Un cart inexistente o expirado se sustituye usando la intención local
  completa. Recuperar un cart existente reconcilia add/update/remove sin
  incrementar una línea que ya coincide.
- `userErrors` y `warnings` se transforman en códigos y mensajes seguros en
  español. Se descartan mensajes y targets remotos antes de cruzar la frontera
  de datos porque podrían contener identificadores sensibles.
- Los importes del carrito permanecen como cadenas decimales de Shopify; no se
  usan `double` para totales comerciales.
- `CartController` liga cada snapshot a su `CartSessionScope`. Cambiar de
  comprador borra el snapshot anterior y una generación de solicitud impide que
  resultados atrasados o fallos restauren datos de otra cuenta.
- `ShopifyCartComposition.production` ensambla el stack sin efectos laterales:
  `HttpStorefrontTransport` aporta consultas con retry acotado y una capacidad
  de mutación inseparable que siempre usa `sendOnce`. Construirlo no inicia red.

## Límite de esta fase

La factory de producción quedó disponible, pero no se conectó el controlador a
ninguna pantalla ni se inicia reconciliación automáticamente. No se presenta
Checkout Kit y `replaceDiscountCodes` permanece explícitamente no soportado
hasta la Fase 2. No hubo llamadas a staging ni cambios de configuración Shopify.

## Residuo CocoaPods conocido

`ios/Podfile.lock` todavía contiene entradas históricas para
`checkout_sheet_kit_flutter` y `ShopifyCheckoutSheetKit`, aunque el paquete Dart
fue retirado en la Fase 0. El lockfile no se regeneró ni modificó en esta fase,
como exige el gate incremental. La Fase 3 deberá resolver y auditar ese residuo
al instalar los SDKs nativos fijados y ejecutar CocoaPods de forma autorizada.
