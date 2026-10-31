# Revisión para guardar y subir al repositorio — 30/10/2026

Revisión local de la rama `feat/client-guide-oct20`. Se preparan en el índice de Git los
cambios de código, recursos y documentación que no están excluidos. El commit
y el push quedan pendientes; esta revisión no modifica el repositorio remoto.

Estado del índice al terminar: **1,761 archivos preparados** (49 modificados
y 1,712 nuevos), sin archivos candidatos pendientes fuera del índice.

## Archivos conservados

- Código y recursos nuevos del tema, cuenta, pedidos, editor de foto/nombre y
  configuración / checkout de Flutter.
- Documentación, scripts y evidencias nuevas dentro del proyecto.
- Los cinco archivos de integración del tema activo que se habían generado en
  `/tmp` se copiaron a
  `docs/web-redesign/shopify-staging/account-design-2026-10-30/active-theme-integration/deployed/`,
  junto con su manifiesto. Los archivos locales de otras tareas se conservan.
- Las fuentes exactas de las verificaciones de cuenta se conservaron como
  referencias en la carpeta `qa/` de esa entrega.
- La app iOS firmada, su paquete con perfil de aprovisionamiento, los fallos
  visuales generados, las dependencias, cachés y configuraciones privadas
  permanecen en disco y están excluidos del índice.

## Comprobaciones

| Comprobación | Resultado |
|---|---|
| Formato Dart | 359 archivos; cero cambios pendientes de formato |
| `flutter analyze` | Sin incidencias |
| Configuración y checkout | 37 pruebas correctas |
| Sintaxis JavaScript | 54 archivos correctos |
| Detector de secretos del proyecto | Correcto |
| Archivos comprimidos nuevos | 7 revisados; sin patrones privados detectados |
| Tamaño de archivos nuevos | Ninguno supera 100 MiB |
| Cuenta / perfil web | Resultados y pruebas de la entrega guardados en su carpeta |

El análisis excluye experimentos de `scratch/`, ejemplos archivados en `docs/`
y el fixture de fragmentos de `tools/style-guideline-content/test/fixtures/`.
El código Flutter y sus pruebas permanecen incluidos. Se corrigieron detalles
de formato y la referencia a la API de caché del scroll del SDK instalado.

## Pruebas de interfaz pendientes

La ejecución completa sin goldens terminó con **1,257 correctas, 46 fallidas y
5 omitidas**. No se declara un pase completo de CI.

| Archivo | Fallos de la ejecución completa |
|---|---:|
| `test/app/media/packshot_fit_test.dart` | 6 |
| `test/features/home/home_account_invitation_test.dart` | 1 |
| `test/features/catalog/catalog_layout_responsive_test.dart` | 24 |
| `test/features/navigation/monetta_floating_bottom_navigation_test.dart` | 3 |
| `test/features/navigation/monetta_bottom_navigation_compact_test.dart` | 2 |
| `test/features/text_scale/text_scale_catalog_screens_test.dart` | 4 |
| `test/features/boutique/boutique_chrome_test.dart` | 6 |

La carga de `home_account_invitation_test.dart` se corrigió después de la
ejecución completa. La comprobación posterior compiló y ejecutó ese archivo
y `authenticated_checkout_phase4_test.dart`: 12 pruebas correctas y una prueba
de animación / visibilidad fallida. Los otros fallos están relacionados con
medidas de tarjetas, navegación y adaptación visual. Deben revisarse antes de
dar la integración por aprobada; no se alteraron expectativas para ocultarlos.

## Estado de ramas

La rama local coincide con su rama remota antes del nuevo commit (0 delante,
0 detrás). Su historia está divergida respecto a `origin/main` (81 commits
propios y 134 de main); la subida de esta rama no equivale a integrarla en main.

## Espacios en evidencias históricas

La revisión de espacios del índice conserva avisos dentro de informes Markdown,
logs y parches de auditorías históricas. Los logs y parches se guardan íntegros
para conservar su valor como evidencia. La comprobación de espacios en código
y recursos fuera de `docs/` no presenta incidencias.
