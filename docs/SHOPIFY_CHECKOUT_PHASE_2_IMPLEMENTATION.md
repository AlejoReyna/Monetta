# Shopify checkout — Fase 2: descuentos y costos autoritativos

Fecha: 2026-08-27
Estado: implementada; pendiente de auditoría independiente.

## Alcance

Esta fase conecta la bolsa con el carrito remoto ya construido en Fase 1 y
añade `cartDiscountCodesUpdate` de Storefront API `2026-07`. No presenta
Checkout Kit, no abre `checkoutUrl`, no instala SDKs nativos y no implementa
gift cards ni medios de pago.

## Autoridad y representación

- Shopify Cart es la autoridad online para líneas, cantidades,
  disponibilidad, moneda, subtotal y total.
- `MoneyV2.amount` y porcentajes permanecen como cadenas exactas; la ruta de
  carrito no convierte dinero a `double`.
- Se conservan por separado los códigos solicitados por la persona, los
  códigos devueltos por Shopify y `applicable`.
- Las aplicaciones automáticas, por código y personalizadas incluyen su valor
  nominal y `totalAllocatedAmount`; las líneas preservan además sus
  `discountAllocations.discountedAmount`.
- La bolsa muestra subtotal y total remotos cuando hay snapshot autoritativo.
  Antes de obtenerlo, los importes locales y la tarifa de envío histórica se
  etiquetan explícitamente como estimaciones. Nunca se presenta `$149` o
  “gratis” como costo confirmado por Shopify.

## Semántica de códigos y recuperación

Cada actualización envía el conjunto completo. Aplicar agrega al conjunto
deseado, retirar lo elimina y reemplazar sustituye todo; la lista vacía retira
todos los códigos. Se normalizan espacios, mayúsculas, duplicados y el máximo
de 250 valores antes del límite remoto.

Una mutación usa exclusivamente el transporte HTTP de un intento. Si su
resultado es ambiguo, el coordinador consulta `CartApi.get`; no repite la
escritura. Todas las escrituras se serializan por dominio y comprador.

Política para carrito expirado:

1. Si la interacción vigente conserva un conjunto deseado explícito, el
   repositorio recrea primero el carrito desde la intención local y reaplica
   ese conjunto una vez.
2. Si se recupera un carrito existente, los códigos devueltos por Shopify
   inicializan el conjunto visible.
3. Los códigos deseados no se persisten separadamente del cart ID. Tras un
   reinicio en el que el carrito ya expiró y no existe intención explícita
   vigente, no se adivinan ni reaplican códigos antiguos.

Esta política evita transferir promociones silenciosamente entre carritos o
compradores. El controlador borra snapshot, costos y códigos al cambiar de
scope, y una generación monotónica descarta resultados atrasados.

La intención de descuentos tiene tres estados semánticos: desconocida al
restaurar una sesión, conjunto explícito no vacío y conjunto explícito vacío.
Una reconciliación normal solo envía códigos cuando existe intención explícita;
de otro modo descubre el conjunto autoritativo sin reemplazarlo. Si el carrito
expira mientras existe intención explícita, la recreación reaplica ese conjunto
una sola vez. Cambiar de comprador vuelve la intención a desconocida.

Una eliminación solo se anuncia como confirmada cuando no hay `userErrors` y
el carrito autoritativo contiene `discountCodes` vacío. Un `cart: null`, una
lectura ambigua que todavía contiene códigos o un rechazo conserva el último
snapshot autoritativo y produce un estado de error seguro.

## Composición de navegación y asignaciones

`AccountScope` y el único `CartScope` de producción envuelven el `Navigator`,
por lo que la ruta hermana de bolsa recibe el comprador, dominio y controlador
vigentes sin construir otro transporte ni iniciar red durante la composición.

El fragmento `CartFields` solicita
`discountAllocations(lineLevelOnly: false)` para incluir en cada línea tanto
asignaciones de producto como asignaciones de descuentos de orden. Sus importes
siguen representados por el `MoneyV2` exacto devuelto por Shopify.

## Errores y privacidad

Los mensajes remotos se descartan. Solo se conservan códigos y paths con
allowlist sintáctica y se muestran mensajes cerrados en español. Los errores y
representaciones no interpolan cart IDs, checkout URLs, tokens, targets,
payloads ni PII.

## Residuo CocoaPods conocido

`ios/Podfile.lock` conserva la referencia histórica al wrapper retirado. No se
modificó ni regeneró CocoaPods en esta fase; su limpieza sigue reservada para
la Fase 3 junto con la instalación nativa autorizada.

## Evidencia pendiente

Esta fase usa dobles de transporte y no llama Shopify. La validación del schema
contra staging, Keychain/Keystore físico, moneda/mercado reales y promociones
configuradas por la tienda permanece pendiente de una fase autorizada.
