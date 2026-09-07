# Evidencia de sondas locales — 2026-09-07

Estas sondas **afirman el comportamiento defectuoso actual**. No añadirlas tal cual a CI: después de la corrección deben invertirse en pruebas de regresión con expectativas correctas.

## Backend

`backend_probes.mts.txt` guarda las tres sondas de seguridad/reintento. Se ejecutaron con tsx, repositorios en memoria y datos sintéticos. La lógica PostgreSQL de reemplazo por deviceId y recordIfNew se inspeccionó aparte; no se levantó una DB real.

Para reproducir desde la raíz del repo, copiar el contenido a un archivo temporal `audit_probes.mts` **en la raíz** y ejecutar:

```sh
services/accounts_orders/node_modules/.bin/tsx audit_probes.mts
```

Eliminar ese archivo temporal al terminar. Los imports de la copia se normalizaron a relativos al repo; la ejecución original usó paths absolutos equivalentes.

Salida observada:

```text
CONFIRMED: unverified allowlisted email receives owner role. Local fake repositories only.
CONFIRMED: retry after failed order upsert is skipped; processing not retried.
CONFIRMED: register with known deviceId replaces existing account credentials without prior credential. SQL path separately inspected.
```

## Flutter

`flutter_probes.dart.txt` se ejecutó temporalmente en `test/audit_flow_probe_test.dart` y luego se retiró de test/. Importa los fixtures existentes de test/shopify/catalog_sync_test.dart.

Para reproducir, copiar a esa ruta y ejecutar `flutter test test/audit_flow_probe_test.dart --no-pub --reporter expanded`; eliminar sólo esa copia temporal al terminar.

La primera ejecución de la sonda falló por import ambiguo de SyncCursor; se corrigió con `hide SyncCursor`. La copia entregada es la corregida, cuya ejecución final dio:

```text
00:00 +0: AUDIT full sync does not remove absent products
00:00 +1: AUDIT truncated pagination is labelled successful full sync
00:00 +2: AUDIT bag and wishlist readers include another account rows
00:00 +3: All tests passed!
```

## Límites

- No se enviaron webhooks a un servidor desplegado.
- No se registraron usuarios ni administradores en servicios reales.
- No hubo llamadas de carrito, pagos ni consultas de pedidos de clientes reales.
- Las sondas demuestran seis comportamientos; el resto de hallazgos distingue evidencia estática/configuración y validaciones operativas pendientes.
