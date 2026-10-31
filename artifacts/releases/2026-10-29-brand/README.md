# Monetta Staging para el iPhone de Alexis

Build **Release**, 0.1.0 (1), `mx.monetta.monettaApp.staging`, con el wordmark y el ícono nuevos del PR #40. Código compilado: `9775d45374c7b333a50f8ee134aeb74e1dcb6896`; PR #40 fusionado en main como `11b4f5fe6cf418b05609810ce7d55ad125c30022`.

- `Monetta-Staging.ipa`: paquete firmado de 26MB.
- `package/Payload/Runner.app`: aplicación firmada lista para instalar desde esta Mac.
- `INSTALAR.command`: cuando regreses, conecta y desbloquea tu iPhone y abre este archivo. Instala y abre Monetta Staging; no hace una compilación nueva ni publica en App Store.

Se verificó la firma con `codesign --verify --deep --strict`, y el perfil incluye tu iPhone. Firma de desarrollo vigente hasta el **1 de noviembre de 2026 a las 02:38 UTC**. Si se instala después de ese vencimiento, habrá que volver a firmarla. Las tres variantes del logo van incluidas en el bundle; el wordmark base coincide con el asset nuevo del PR.

Compilación: `flutter build ios --release --flavor staging --dart-define-from-file=config/dart_defines.staging.json`, Flutter 3.44.8. Prueba de arranque: 2/2 pasan. La app usa la configuración local existente de staging; el archivo de configuración no se subió al repo. No se instaló ni se abrió en el teléfono mientras estabas fuera.

Shopify: publicado el tema **192672989218**, “Monetta logos y XL 2026-10-29”, en https://monetta-staging.myshopify.com/. Incluye los logos/favicons nuevos, los ajustes XL, la sección de registro unida al footer y su entrada animada. El tema anterior 192558366754 se conserva y se descargó una copia local completa de 777 archivos antes de publicar.

Repo: PR #40 fusionado; las mejoras adicionales del storefront están subidas en PR #41 (`ship/storefront-xl-register`) para revisión independiente. No se declara esa revisión aprobada.

Backend: desplegado el panel a `monetta-accounts-staging`; migración 016 aplicada mediante release command, `/readyz` reporta base de datos disponible y `/shopify/app` responde 200 con el CSP esperado. App Shopify staging publicada como `monetta-staging-7`. Se actualizó únicamente la máquina web: los workers de recompensas conservaron su imagen y estado. No se activaron notificaciones, Firebase ni máquinas adicionales persistentes. Falta autorizar tu ID de staff para usar el panel; nunca se amplió la lista sin tu identificador.

CI: el primer job Flutter del PR #40 pasó análisis y tests pero falló al descargar el NDK de Android (archivo inválido). Se lanzó un reintento; la compilación iOS de GitHub sí pasó, además de esta build física firmada. Consultar el estado actual en GitHub antes de afirmar que todos los checks están verdes.
