# Prompt para el agente implementador

```text
Trabaja en /Users/alexis/develop/monetta-app.

Tu objetivo es implementar incrementalmente el sistema de carrito, descuentos y
Shopify Checkout descrito en:

- docs/SHOPIFY_CHECKOUT_AND_DISCOUNTS_PLAN.md

Antes de actuar, lee ese archivo completo y también:

- docs/SHOPIFY_CHECKOUT_AUDIT_PLAN.md
- docs/SHOPIFY_PRODUCTION_IMPLEMENTATION_PLAN.md (solo para contexto compatible)
- docs/CHECKOUT_DESIGN.md
- docs/SYSTEM_IMPLEMENTATION.md (sección actual de checkout/login)

Reglas obligatorias:

1. Empieza registrando rama, HEAD, git status, staging area y diff. El worktree
   puede estar sucio. Conserva todos los cambios previos y no reviertas, borres,
   stashees ni absorbas cambios ajenos.
2. Staging autorizado: monetta-staging.myshopify.com. Producción
   monetta.mx/fakcei-n9/monetta-2 está fuera de alcance.
3. No hagas deploy, instalación Shopify, cambios de pagos, pedidos de prueba,
   commit, push, amend, reset, stash o clean sin autorización explícita del
   usuario para esa acción concreta.
4. No leas, descargues, imprimas ni registres secretos, cart IDs completos,
   checkout URLs, tokens OAuth/cookies ni datos de pago.
5. No integres SDKs individuales de PayPal, Mercado Pago, Google Pay, Shop Pay o
   Apple Pay. Shopify Cart + Checkout Kit es la arquitectura obligatoria.
6. Implementa solo una fase auditable por turno. Determina la primera fase no
   aprobada del plan; no saltes gates ni rehagas una fase ya auditada.
7. Si la documentación oficial actual contradice el plan, detente, presenta la
   evidencia y propone el cambio; no inventes una API.
8. Usa Storefront API 2026-07, separa UI/dominio/datos, preserva guest checkout y
   trata Shopify como autoridad de inventario, precios, descuentos y costos.
9. Usa apply_patch para cambios manuales. Añade pruebas negativas proporcionales
   al riesgo. No declares completado algo que solo está simulado.
10. Si una acción externa o financiera fuese necesaria, detente antes de ella y
    pide autorización puntual.

Proceso del turno:

A. Informa qué fase ejecutarás y por qué es la siguiente.
B. Inspecciona el código y las pruebas relacionadas.
C. Implementa completamente esa fase o un sub-gate coherente si la fase resulta
   demasiado grande; documenta la desviación.
D. Ejecuta tests focalizados y los gates exigidos por el plan de auditoría.
E. Revisa git diff, git diff --check, staging area y escaneo de secretos.
F. Detente para auditoría. No empieces automáticamente la fase siguiente.

Reporte final obligatorio:

1. Fase/sub-gate y resultado.
2. Cambios de comportamiento.
3. Archivos modificados con referencias concretas.
4. Pruebas/comandos y resultados exactos.
5. Evidencia observada versus inferida.
6. Estado Git y cambios previos preservados.
7. Mutaciones externas (debe decir ninguna salvo autorización explícita).
8. Secretos/datos sensibles: confirmar que no se expusieron.
9. Riesgos, bloqueos y trabajo no realizado.
10. Entrega para auditor: claims específicos que debe intentar refutar.

Comienza ahora con la primera fase no aprobada. Si no existe registro de
aprobaciones, empieza en la fase 0.
```
