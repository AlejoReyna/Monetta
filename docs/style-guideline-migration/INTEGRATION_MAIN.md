# M1 sobre main — 21 de octubre de 2026

Esta entrega sustituye al PR #22, que permanece abierto. Base: `origin/main` en
`ce0c9d2`. Rama: `feat/client-guide-m1`. Se aplicaron con `git cherry-pick
--no-commit`, en orden, los cuatro commits de la guía; cada índice se revisó y
escaneó antes de confirmar. No se incorporó la historia de rf-17.

| Commit original | Alcance |
| --- | --- |
| `d6e647e` | Manifiesto, generador y tokens Flutter |
| `abd1d98` | Presentación de la app y pruebas de la guía |
| `8fa1130` | Prototipo y fuentes del tema |
| `6833c20` | Documentación, herramientas y ajustes de integración con main |

## Conflictos y dependencias mínimas

El commit de la app produjo conflictos en 24 rutas (incluidos diez PNG).
Los otros tres cherry-picks no produjeron conflictos textuales.

- `theme.dart`: se conservaron `intl`, `Money`, formato de precios y APIs de
  main; se añadieron los roles de la guía. Los helpers tipográficos compartidos
  usan Inter y Playfair, sin importar el módulo ni las refactorizaciones de rf-17.
- Cuenta: se mantuvieron identidad, proveedor, pedidos, borrado de cuenta,
  privacidad y enlaces de main. Se portaron avatar y título sobre esa estructura.
  No se restauraron `profile_components.dart` ni `profile_rewards_card.dart`.
  La presentación compacta de Rewards se aplicó al componente existente,
  conservando saldo, pendientes, vencimiento y movimientos del contrato MXN.
- Inicio: se conservó la sección y sus enlaces actuales de main. No se trajo la
  composición de rf-17. La paleta y las fuentes compartidas aplican la guía.
- Navegación: se conservaron la barra plana, iconos, geometría, áreas seguras,
  accesibilidad y callbacks de main. No se restauró el wrapper flotante de rf-17
  ni su prueba; no se añadió la dependencia ausente `MonettaNavigationBar`.
- Pruebas: solo se actualizaron expectativas de paleta/tipografía ligadas a la
  guía. Se conservaron las de geometría y comportamiento de main.
- Dependencias mínimas de rf-17: siete fuentes TTF Inter/Playfair con dos
  licencias OFL y su registro en `pubspec.yaml`; el harness UI04 y dos helpers
  de carga de fuentes/comparación golden. Los diez goldens se regeneraron
  sobre los componentes de main. UI04 se compara en macOS y se omite en Linux
  por diferencias de rasterización; el CI actual no compara estos goldens.
- `port-css.mjs` se trasladó a `tools/style-guideline-theme/` y se ajustaron su
  raíz y referencias: `docs/web-redesign/` queda fuera de esta entrega.
- El archivo Dart de tokens no tuvo conflicto. Se regeneró con
  `node design-system/build.mjs`; el generador produce el formato canónico.
- Se excluyeron del analizador solo los dos directorios nuevos de fragmentos
  Dart que el auditor de contenido consume como texto, no código ejecutable.

## Validación contra la base

Entorno: Flutter 3.44.8, Dart 3.12.2, macOS. Misma instalación y comandos en
worktrees separados para main y M1. Los resultados siguientes corresponden a
esta base; la evidencia del 20 de octubre se conserva como registro histórico.

| Comprobación | main `ce0c9d2` | M1 |
| --- | --- | --- |
| `flutter analyze` | Sin incidencias | Sin incidencias |
| `flutter test --reporter json` | 1220 aprobadas, 5 omitidas, 0 fallos | 1237 aprobadas, 5 omitidas, 0 fallos |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Sin cambios requeridos | Sin cambios requeridos |

**Fallos nuevos frente a main: 0.**

**¿11 o 15?** Ninguno de esos conteos corresponde a main actual: la base tiene
**0 fallos**. El estado histórico del PR #22 documentaba **15 sobre `c828d68`**
(6 packshot, 4 escala de Colección, 4 goldens de Ficha y 1 animación). Ese
conteo no se reproduce ni se atribuye a `ce0c9d2`. Tampoco se reproduce en main
el antiguo gate de formato de cuatro archivos de checkout.

Adicionalmente: 22 pares de contraste y salidas vigentes con
`node design-system/build.mjs --check`; 54/54 pruebas unitarias del prototipo;
81/81 del auditor de contenido; gate local `bin/check_no_secrets.sh` aprobado.
Las capturas y auditorías web incluidas del 20 de octubre son históricas; no
representan nuevas verificaciones de navegador o validación de tienda.

## Diez goldens pendientes de aprobación de Alexis (D-15)

Todos están en `test/goldens/ui04/`, regenerados en macOS, con fuentes reales.

| Pantalla | 375×812 | 440×956 |
| --- | --- | --- |
| Bolsa | `bolsa_375x812.png` | `bolsa_440x956.png` |
| Colección | `coleccion_375x812.png` | `coleccion_440x956.png` |
| Cuenta | `cuenta_375x812.png` | `cuenta_440x956.png` |
| Ficha | `ficha_375x812.png` | `ficha_440x956.png` |
| Inicio | `inicio_375x812.png` | `inicio_440x956.png` |

No se actualizaron goldens ajenos a la guía ni pruebas de checkout, backend o
configuración. La aprobación visual sigue pendiente aunque las comparaciones
locales pasen.

## Seguridad y alcance operativo

Se revisó `git diff --cached` antes de cada commit y se escanearon rutas,
tokens privados, claves AWS, bloques de llave privada, secuencias de CLABE y
correos en los textos incorporados. Las coincidencias eran fixtures sintéticos,
dominios reservados, una URL de prueba y nombres de assets; se normalizó el
correo de demostración del prototipo a un dominio reservado. No se publican
valores de coincidencias. Se excluyeron los archivos y directorios prohibidos;
los fixtures públicos de CI ya presentes en main no se modificaron.

El checkout original, incluidos sus cambios locales, se preservó. No se hizo
merge, deploy, publicación de tema ni operación sobre producción.
