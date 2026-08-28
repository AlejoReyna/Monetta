# Plan de auditoría — carrito, pagos y descuentos

Estado: protocolo para una sesión limpia
Plan auditado: `docs/SHOPIFY_CHECKOUT_AND_DISCOUNTS_PLAN.md`

## 1. Rol

El auditor es independiente del implementador. Su trabajo es comprobar
afirmaciones contra código, tests y estado externo permitido; no completar el
trabajo por el agente ni aceptar un reporte por su redacción.

Por defecto la auditoría es de solo lectura. Puede ejecutar análisis y tests
locales no mutantes. No debe editar archivos, desplegar, instalar apps Shopify,
crear pedidos, cambiar pagos, usar producción, hacer commit o push salvo que el
usuario lo solicite explícitamente después de presentar hallazgos.

## 2. Contexto mínimo persistente

- Workspace: `/Users/alexis/develop/monetta-app`.
- Rama histórica de trabajo: `agent/shopify-production`; verificar, no asumir.
- Staging autorizado: `monetta-staging.myshopify.com`.
- Producción excluida: `monetta.mx`, `fakcei-n9`, `monetta-2`.
- El catálogo staging y su backend/Firestore ya existían antes de este plan; no
  confundir esos avances con checkout completo.
- El login usa Shopify Customer Account API con OAuth/PKCE y almacenamiento
  seguro; checkout debe reutilizarlo, no crear otro login.
- Estado inicial conocido: queries parciales de Cart y dominio básico existen;
  no había repositorio remoto, descuentos, launcher inyectado ni App/Universal
  Links de checkout.
- Checkout real observado: Shop Pay, PayPal y Google Pay exprés; tarjeta,
  PayPal, Mercado Pago y transferencia normales; descuento presente. Apple Pay
  y Kueski no quedaron demostrados en esa sesión.
- `checkout_sheet_kit_flutter` estaba declarado pero sin uso en `lib/` y es un
  wrapper de terceros que requiere decisión explícita.
- Al crear este plan había modificaciones locales ajenas en
  `lib/app/motion.dart`, `lib/features/home/home_screen.dart` y
  `test/features/home/home_editorial_sections_test.dart`; cada auditoría debe
  tomar un baseline nuevo y no atribuir automáticamente esos cambios al agente.

## 3. Inicio obligatorio de cada auditoría

1. Leer completamente:
   - `docs/SHOPIFY_CHECKOUT_AND_DISCOUNTS_PLAN.md`;
   - este archivo;
   - el reporte más reciente del implementador.
2. Ejecutar baseline:

   ```bash
   pwd
   git branch --show-current
   git rev-parse HEAD
   git status --short
   git diff --cached --name-only
   git diff --stat
   ```

3. Identificar qué fase afirma haber completado. Si mezcla fases, auditar cada
   claim pero marcar incumplido el gate incremental.
4. Confirmar que no se borraron, revirtieron o absorbieron cambios ajenos.
5. Inspeccionar el diff real y abrir todos los archivos de producción y tests
   que sustentan la fase. No limitarse a `git diff --stat`.

## 4. Método de verificación

Para cada claim clasificar evidencia como:

- **observada:** reproducida por el auditor o visible directamente en código;
- **corroborada:** artefacto confiable verificable, pero no reproducido;
- **inferida:** conclusión razonable sin observación directa;
- **no demostrada:** falta evidencia o la prueba no cubre el claim;
- **contradicha:** código/estado demuestra lo contrario.

Revisar en este orden:

1. seguridad y alcance;
2. arquitectura y fuente de verdad;
3. manejo de errores/concurrencia/lifecycle;
4. pruebas negativas y no solo happy path;
5. UI/accesibilidad;
6. calidad del diff y documentación;
7. estado externo, únicamente si la fase lo requiere y puede verificarse sin
   mutación.

No exponer secretos al auditar. No imprimir archivos completos de configuración
real, cart IDs, checkout URLs, OAuth tokens, cookies o datos de pago.

## 5. Gates por fase

### Fase 0

- bridge de Checkout Kit elegido y justificado;
- dependencia versionada/auditada o platform channel delimitado;
- interfaces testables para API, sesión, coordinador y lifecycle;
- no import de SDK en UI;
- fixtures y logs sanitizados.

### Fase 1

- Shopify Cart es autoridad online;
- cart ID en almacenamiento seguro y particionado por entorno/cuenta;
- create/recover/expired y líneas funcionan;
- una sola mutación en vuelo por carrito;
- timeout ambiguo consulta antes de repetir;
- userErrors y warnings no se ignoran;
- tests prueban no duplicación y agotados.

### Fase 2

- `cartDiscountCodesUpdate` reemplaza conjunto completo;
- se comprueba `applicable`, no solo HTTP/GraphQL success;
- descuentos automáticos y por código se representan por separado;
- MoneyV2 no se convierte prematuramente a `double` para cálculos comerciales;
- envío `$149`/gratis no se presenta como total definitivo;
- gift cards no se mezclan.

### Fase 3

- launcher inyectado desde composition root;
- URL fresca, `https` y allowlist;
- doble tap/reentrada bloqueados;
- cancel y failed preservan bolsa;
- completed limpia una vez;
- no se infiere compra por apertura/cierre de hoja;
- fallback externo es explícito y seguro.

### Fase 4

- guest sigue funcionando;
- se reutiliza Customer Account API/PKCE existente;
- flujo de autenticación coincide con documentación Shopify vigente;
- tokens no van a URL, Drift, logs ni errores;
- expiración, logout y cambio de cuenta separan carritos;
- checkout autenticado se demuestra, no solo se afirma por buyer email.

### Fase 5

- Associated Domains/App Links mínimos por entorno;
- AASA y assetlinks coinciden con IDs/fingerprints reales;
- hosts/paths restringidos;
- deep link no equivale a pago completado;
- retorno reanuda la misma sesión y rechazo adversarial está probado.

### Fase 6

- autorización puntual antes de pedido de prueba;
- staging exclusivamente;
- matriz guest/auth/discount/error/lifecycle completada;
- wallets solo se marcan verificadas si fueron visibles/ejecutables en contexto
  elegible;
- evidencia visual y logs están sanitizados;
- suite final y escaneo de secretos pasan.

## 6. Comandos y proporcionalidad

Ejecutar primero tests focalizados. Después, para aprobar una fase con cambios
Flutter, normalmente se requieren:

```bash
flutter analyze
flutter test --reporter compact
./bin/check_no_secrets.sh
git diff --check
```

Si cambió backend/API/web:

```bash
npm run typecheck:api
npm run test:api
npm run build:web
```

Si una prueba no puede ejecutarse por entorno, no sustituirla con una afirmación
del implementador: marcarla `NO DEMOSTRADA` o `BLOQUEADA` y explicar qué evidencia
falta.

## 7. Formato de salida obligatorio

El auditor debe responder con:

1. **Veredicto:** `APROBADA`, `CAMBIOS REQUERIDOS`, `BLOQUEADA` o
   `NO AUDITABLE` para la fase.
2. **Hallazgos**, primero, ordenados por severidad y con archivo/línea.
3. **Claims verificados**, indicando observada/corroborada/inferida.
4. **Pruebas ejecutadas** y resultado real.
5. **Integridad y alcance:** HEAD, staged, cambios ajenos, secretos y mutaciones
   externas.
6. **Riesgos residuales** que no bloquean esta fase.
7. **Siguiente prompt listo para copiar**:
   - si aprobada: prompt para la siguiente fase;
   - si requiere cambios: prompt limitado a corregir los hallazgos;
   - si bloqueada: una sola acción o evidencia necesaria.

No comenzar a implementar la siguiente fase como parte de la auditoría.

## 8. Severidad

- **Crítica:** exposición de secretos/datos de pago, producción tocada sin
  autorización, posibilidad de cobrar/limpiar bolsa falsamente o takeover por
  deep link.
- **Alta:** cantidades duplicadas, descuento/total incorrecto, mezcla de
  cuentas, compra marcada completed sin confirmación, retry no seguro.
- **Media:** recuperación incompleta, UX engañosa, cobertura negativa faltante,
  dependencia sin pin/auditoría.
- **Baja:** mantenibilidad, nombres, documentación o cobertura no esencial.
