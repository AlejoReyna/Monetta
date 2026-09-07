# Encargo para Grok — corrección de flujos Monetta

Leer primero [docs/AUDITORIA_FLUJOS_2026-09-07.md](/Users/alexis/develop/monetta-app/docs/AUDITORIA_FLUJOS_2026-09-07.md). Es la referencia de estado actual, con F01–F30, evidencia y aceptación. Los planes anteriores contienen afirmaciones obsoletas; comprobar código antes de repetir trabajo.

## Objetivo

Dejar la app preparada para vender productos propios de monetta.mx usando APIs oficiales de Shopify. Retirar catálogo extraído de terceros y su servidor/monitor como dependencia del producto. Completar y probar flujos de compra, identidad, catálogo, administración y posventa. Mantener apariencia actual; permitir sólo cambios funcionales necesarios en controles, validación, errores y navegación.

No prometer que una noche alcanza para certificar producción. Entregar código, pruebas, migraciones y verificaciones pendientes con evidencia.

## Reglas de ejecución

1. Inventariar `git status` antes de editar. Hay cambios locales grandes y `dashboard/` sin rastrear en el estado auditado. Preservarlos; no reset, clean, stash ni sobreescritura masiva. Crear checkpoint/branch de trabajo que conserve cambios autorizados.
2. No iniciar crawlers, ampliar fuentes, usar proxies de extracción ni construir un scraper alternativo. No integrar el dashboard externo como nuevo admin comercial.
3. No rediseñar home, tarjetas, tipografía, animaciones ni branding durante este encargo.
4. Catálogo comprable, IDs de variantes, OAuth y carrito pertenecen al mismo shop. No «arreglar» staging agregando su token encima del espejo de productos reales.
5. Los usuarios heredados pueden ser reales. Corregir vulnerabilidades sin borrar cuentas, pedidos ni tablas. No enlazar identidades por email no verificado. Preparar migraciones y rollback.
6. No poner secretos en código, docs, logs o chat. Usar plantillas con nombres de variables; valores privados en gestores del entorno.
7. Trabajar local/staging y preparar cambios production revisables. No realizar cobros/reembolsos reales, cambiar modo de pago, instalar apps, modificar catálogo real, desplegar producción o eliminar infraestructura/datos reales sin autorización explícita de esas acciones.
8. Un bloqueo de credenciales no bloquea pruebas con fakes, corrección de código, migraciones, contratos, validadores ni documentación. Continuar esos trabajos y registrar la dependencia exacta.
9. No convertir una sonda que demuestra un defecto en una prueba permanente que bendice el defecto. Añadir regresiones con comportamiento correcto.
10. Cada paquete debe terminar en resultado verificable: archivos, pruebas, limitaciones y rollback. No marcar completo por recibir HTTP 200/202 ni por compilar.

## Orden de trabajo

### WP-01 — Cerrar acceso indebido a cuentas/admin (F01, F02, F19)

- Eliminar bootstrap owner por correo Monetta no verificado.
- Provisionar principales por identidad estable comprobada; conservar owner legítimo y respetar revocación.
- `/accounts/register` nunca actualiza credenciales de una cuenta existente usando sólo deviceId. Separar registro de cambio autenticado.
- Revisar persistencia real PostgreSQL y fakes: ambos contienen actualmente patrón de reemplazo por deviceId.
- Endurecer input/rate limit de login/registro. Decidir si creación heredada queda deshabilitada mediante flag, sin borrar cuentas existentes.
- Preparar migración de principales sospechosos revisable, sin revocar usuarios reales a ciegas.

Pruebas obligatorias: email allowlisted no verificado no obtiene owner; deviceId conocido no cambia otra cuenta; owner real sí; usuario normal 403; revocación no se revierte; tokens/contraseñas no se registran.

### WP-02 — Retirar catálogo externo del producto (F03, F22, F25)

- Deshabilitar/remover wiring en main, home, browse, search/recomendaciones, detalle, notificaciones y administración.
- Quitar necesidad de ExternalCatalogController al abrir AdminScreen.
- Retirar `external-status` de syncAll y fuentes externas de portada/panel.
- Ajustar config/validadores/CI; staging debe poder usar Storefront directamente sin Firestore obligatorio.
- Separar backend útil de cuentas/admin/notificaciones del monitor que se descarta.
- Documentar inventario de deploys, cron, dominios y secretos que habrá que retirar; no apagar ni borrar recursos reales sólo porque existan archivos de deploy en repo.
- Elegir Storefront oficial directo como autoridad comprable; no reemplazar el monitor externo por otro servidor extractor.

Pruebas: flujos principales funcionan sin monitor; cero requests a fuentes externas; admin sync pasa sin external backend; production no admite external flag por bypass del Makefile.

### WP-03 — Corregir datos comerciales (F04, F08, F09, F10, F11, F26)

Orden interno: detectar incompletitud → identidad/scope de caché → reemplazo atómico → variantes/cuentas → refresco.

- Paginación no puede avanzar cursor al truncarse. Cubrir cursor repetido/ausente y límites de conexiones internas.
- Full sync reemplaza conjunto completo, incluye vacío válido y elimina retirados; transacción con cursor/metadata.
- Catalog namespace por shop/fuente; no reutilizar cursor de staging al cambiar tienda.
- Bolsa guarda variantId elegido y permite variantes distintas del mismo producto. No inferir otra variante al renderizar/hidratar.
- Guardar bolsa/favoritos con scope efectivo de cuenta o invitado. Migración segura del esquema existente y refresco del estado en memoria.
- Refresco de catálogo general al foreground/manual con single-flight. Contexto efectivo MX/ES y moneda explícita.

Pruebas: A+B→B; full vacío; fallo de segunda página conserva cache; 251 productos; 21 variantes; cambio de tienda; variante B sobrevive reinicio; A agotada no se sustituye; cuenta A no se ve desde B.

### WP-04 — Completar checkout (F05, F06, F07, F16, F17)

- Config incompleta bloquea antes de pedir dirección.
- Invitado sigue comprando sin login. Usuario Shopify pasa access token vigente como buyerIdentity.
- Evitar captura duplicada de dirección: delegarla a Shopify o integrarla realmente con Cart API soportada.
- Reconstruir intención actual al presentar; no usar snapshot obsoleto de líneas; mostrar costos Shopify y estimados honestos.
- Mantener validación estricta de checkoutUrl, no usar host wildcard. Verificar dominio real devuelto por shop.
- Logout/cambio de cuenta invalida preload y checkout del anterior.
- Reconciliar completion/retorno y refrescar pedidos; nunca tratar retorno de navegador como pago aprobado.
- Revisar integración nativa de pagos externos por documentación oficial y método realmente habilitado.

Pruebas: invitado/auth; descuento válido/no aplicable; precio/stock cambiados; dirección sin cobertura; cancelación; rechazo; timeout ambiguo sin duplicados; doble tap; app background; carrito expirado; completion conservando líneas nuevas; regreso desde navegador; ambos sistemas físicos cuando estén disponibles.

### WP-05 — Recuperar pedidos y posventa (F12–F15, F18)

- Inbox/transacción durable de webhooks con reintentos de pendientes, deduplicación concurrente y reinicio seguro.
- Verificar shop de entrada y aislar tenants/entornos; proteger borrado single-tenant ante mezcla de tiendas.
- Controlar eventos fuera de orden. No sobrescribir refunded con paid antiguo.
- Conectar historial Customer Account API como fuente primaria o implementar backfill/reconciliación verificable del espejo. Documentar elección y permisos.
- Estado explícito de error/no configurado/vacío/cache; refresh manual y post-checkout.
- Evitar respuesta tardía de A después de logout/login B.
- Mostrar detalle/estado/tracking o acceso seguro al portal alojado. No inventar acciones de cancelar/refund que no se implementaron.
- Completar logout alojado y proceso de cuenta/direcciones/baja según la ruta elegida.

Pruebas: primer intento falla y retry procesa; duplicado completo no duplica; restart recupera; evento viejo no retrocede estado; historial previo a instalación; usuario sólo ve sus pedidos; respuesta tardía descartada.

### WP-06 — Hacer operable el admin (F20–F24)

- Consumir `/admin/me` para entry point/capacidades; backend sigue autorizando cada acción.
- Paginación de productos; búsqueda no limitada a primeros 50.
- Portada guardada refresca HomeContent; validar namespace/permisos de metaobjects bajo credenciales reales.
- Reordenamiento destacado sigue job hasta completado o error y refresca resultado canónico.
- Sync jobs no se declaran completos por lectura parcial; recuperación durable tras restart.
- Separar lo que se administra en app de lo que se opera en Shopify Admin: stock, media, pedidos, pagos y logística pueden quedarse ahí.
- Preparar TOML/permisos producción como artefacto revisable; no desplegarlo automáticamente.

Pruebas: producto 51/101; conflicto de versión; escritura parcial; idempotency; error de permisos; contenido visto por otro cliente; owner sin allowlist compilada pero autorizado por servidor; no dependencia del monitor.

### WP-07 — Operación, privacidad y observabilidad (F27–F30)

- Documentar SOP apartado/mayoreo sin prometer reserva/cobro por abrir WhatsApp.
- Push: permisos, opt-out, Firebase por app id, App Check, API/worker, deep links correctos y sin eventos externos.
- Data request/redact con seguimiento real; readiness DB, backup, restore, lag/fallos de webhook y rollback.
- Conectar eventos útiles de compra y fallos sin PII ni secretos; no confundir callback checkout con cobro confirmado.
- Arreglar formato/lints y referencia integration_test; crear pruebas de integración útiles.
- Exceptuar de forma estrecha el fixture CI público del escáner manteniendo inspección de su contenido y detección de secretos.
- Actualizar documentación vieja sin reescribir historial ni usarla como evidencia actual.

## Baseline de auditoría

610 pruebas existentes pasaron: Flutter 482; cuentas/pedidos 68; API 19; Functions 13; dashboard externo 28. Typechecks y builds web/dashboard pasaron. Analyze reportó 20 infos; formato falló en main.dart/onboarding_controller.dart; falta integration_test; escáner falla por fixture CI público. Seis sondas adicionales demostraron defectos, no readiness.

Comandos base después de ajustes de alcance:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
npm --prefix services/accounts_orders run typecheck
npm --prefix services/accounts_orders test
npm --prefix services/accounts_orders run build
npm run typecheck:api
npm run test:api
npm --prefix functions run typecheck
npm --prefix functions test
npm run build:web
./bin/check_no_secrets.sh
```

Si se retira una capa de catálogo propia, actualizar comandos y CI con justificación. No ejecutar tests del crawler como sustituto de pruebas de compra. No ejecutar `make test-all` sin revisar que incluye `format` capaz de escribir archivos y suites del monitor retirado.

## Lo que puede necesitar al propietario

Preparar una tabla concreta, no pedir «todos los accesos»:

- App/canal Headless del shop real y token Storefront público en config segura.
- Customer Account Mobile client y callback `shop.72391655575.oauth://callback`.
- Identidad owner provisionada y permisos de Admin mínimos para capacidades retenidas.
- Host/DB/secrets reales de backend y Firebase si se usan.
- Métodos de pago y cobertura/logística a probar; cuentas de prueba.
- Autorización concreta de canary real, cobro, cancelación/refund o cambios production cuando toque ejecutarlos.

Mientras falta cualquiera, finalizar las correcciones independientes y dejar el comando/pantalla de validación siguiente. No introducir valores ficticios que hagan pasar validadores production.

## Entrega de fin de noche

1. Tabla F01–F30 con resuelto / parcial / pendiente / requiere operación, evidencia y commit.
2. Pruebas ejecutadas y resultado exacto; incluir prueba que falla antes y pasa después en defectos críticos.
3. Migraciones y rollback, especialmente cuentas/roles/bolsa/catálogos/webhooks.
4. Config requerida por entorno, sin secretos.
5. Flujos completos realmente ejercitados y plataforma usada; distinguir fakes de Shopify real.
6. Lista de decisiones/credenciales pendientes y siguiente acción concreta por responsable.
7. No declarar listo para producción hasta satisfacer la sección 9 de la auditoría, incluyendo canary real autorizado.
