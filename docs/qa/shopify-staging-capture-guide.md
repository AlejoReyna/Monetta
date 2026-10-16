# Guía de capturas: Shopify staging (para las 5 pm)

Tienda: `monetta-staging.myshopify.com/admin`. Tiempo estimado: 15 min.
Los nombres de menú marcados con (?) no los pude verificar; pueden variar según el idioma del admin o la versión de Shopify. Si no coinciden, busca algo parecido y anótalo.

## 1. Pagos (capturas de página completa)
1. Abajo a la izquierda: **Configuración** (Settings) → **Pagos** (Payments).
2. Captura la página entera (usa la captura de página completa del navegador o varias capturas seguidas, sin saltarte nada).
3. Por cada proveedor activo (Shopify Payments, PayPal, Mercado Pago u otro): entra a su detalle (**Administrar** / Manage (?)) y captura la página completa.
4. **Métodos de pago manuales** (Manual payment methods (?)): abre cada uno (p. ej. "Depósito bancario" / Bank Deposit o uno personalizado) y captura:
   - el **nombre exacto** del método, tal como lo verá el cliente (esto define cómo lo guarda la app);
   - el campo de **instrucciones de pago** / información adicional (?).
5. Anota aquí: ¿las instrucciones incluyen banco, titular y **CLABE**? Sí / No. (Si no, la app solo puede mandar al cliente a WhatsApp.)
   - No mandes la CLABE por el grupo; basta con decir si existe.

## 2. Confirmar modo de prueba
- **Shopify Payments:** en su página de administración debe haber una opción de **modo de prueba** / test mode (?). Captura que esté activada.
- **Si no hay Shopify Payments:** revisa si está el **Bogus Gateway** / "(para pruebas)" (?) como proveedor; captura que esté activo.
- PayPal y Mercado Pago: captura si están en modo sandbox/prueba (la etiqueta exacta depende de cada app (?)).
- Si nada de esto aparece, dilo: así sabemos que staging **no** está en modo de prueba y no hacemos pedidos.

## 3. Dar acceso al equipo
1. **Configuración** → **Usuarios y permisos** (Users and permissions (?)) → **Agregar personal** / Add staff (?).
2. Agrega al Engineer y a Pagos con su correo. Permisos mínimos: Pedidos, Productos (lectura), Configuración de pagos (lectura) (?).
3. Si tu plan no permite más personal, usa **colaborador** (collaborator request) (?) y avísanos para mandarte el código de solicitud.
4. No compartas tu contraseña ni el Admin token en el grupo; el token va por privado.

## Checklist para mandar
- [ ] Captura(s) de Configuración → Pagos completa
- [ ] Una por proveedor + cada método manual (nombre e instrucciones)
- [ ] ¿Hay CLABE en las instrucciones? Sí/No
- [ ] Captura de modo de prueba activo
- [ ] Engineer y Pagos invitados
