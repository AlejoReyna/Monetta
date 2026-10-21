# Muestras de color del PDF (2026-10-20)

Fuente: `/Users/alexis_reyna/Desktop/guideline.pdf` (SHA-256 `7e7414de…97db`). Páginas renderizadas con `pdftoppm -r 96` (800 × 2000 px) y muestreadas con el promedio de una ventana de 5 × 5 px. Son **valores de imágenes rasterizadas** (con degradados y compresión), no declaraciones de tokens. Sirven para comprobar que las propuestas del plan caen dentro de lo que el PDF muestra; los valores finales esperan los originales.

| Rol | Página y punto (x, y) | Muestra | Valor del manifiesto |
| --- | --- | --- | --- |
| Barra de encabezado | 3 (300, 325) | `#F7F3EC` | `bar` `#F7F3EC` |
| Lienzo | 6 (75, 950) · 8 (80, 1400) · 13 (60, 700) | `#F7F2EE` · `#F8F5EE` · `#FDFBF6` | `canvas` `#FBF8F2` (dentro del rango) |
| Mosaico de categoría / tarjeta | 3 (110, 835) · 6 (130, 1000) | `#F2ECE4` · `#F2EBE3` | `surfaceTile` `#F4EEE5` |
| Panel de campaña / servicios | 4 (95, 1200) · 4 (200, 1500) | `#F2E8DE` · `#F0E8E1` | `surfaceWarm` `#F3EADF` |
| Botón principal (marrón) | 7 (180, 1475) · 8 (150, 1306) · 6 (135, 1205) | `#735136` · `#765134` · `#7A502A` | `actionPrimary` `#745237` |
| Píldora oscura "Compartir catálogo" | 13 (130, 1413) | `#2D1E14` | `actionDark` `#2D1E14` |
| Etiqueta de oferta | 7 (250, 1392) · 8 (440, 1098) | `#E5BCB6` · `#E6BCB7` | `saleSurface` `#F6DEDA` (más claro a propósito: el texto rojo debe alcanzar 4.5:1, ver abajo) |
| Icono activo de navegación | 3 (155, 1585) | `#A16B2B` | `navigationActive` `#8C6436` (oscurecido para 4.5:1 sobre la barra) |

## Dónde el manifiesto se aparta de la muestra, y por qué

- **Etiqueta de oferta y navegación activa.** Los valores muestreados no alcanzan el contraste de texto exigido (WCAG AA 4.5:1). El manifiesto usa un tono más claro para el fondo de la etiqueta (`#F6DEDA`, rojo sobre él 5.31:1) y uno más oscuro para el color activo (`#8C6436`, 4.76:1 sobre la barra y 3.24:1 contra el estado inactivo).
- **Borde de controles.** El PDF dibuja contornos dorados muy finos (aprox. 2:1). Los controles con contorno usan `borderControl` `#8A7766` (4.03:1 sobre el lienzo) para cumplir el contraste de componentes no textuales (1.4.11). Los chips de solo texto usan el divisor decorativo.
- **Dorado `#C5A052`.** Se conserva como marca y línea (2.32:1 sobre el lienzo); nunca como texto.

`design-system/build.mjs` verifica 22 pares de contraste en cada ejecución y no genera salidas si alguno falla.
