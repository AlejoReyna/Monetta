# Capturas de evidencia visual (catálogo, ficha y compra)

`ficha_compra_captures_test.dart` dibuja las pantallas reales con fuentes reales
del sistema y fotos reales de producto, y escribe PNG y un `metrics.json` con
las medidas que cita la auditoría. **No es una prueba de regresión** y no forma
parte de `flutter test` (vive fuera de `test/`).

## Preparación (una vez; `scratch/` está ignorado por git)

```sh
mkdir -p scratch/capture-fonts scratch/capture-images scratch/capture-cache
S=/System/Library/Fonts/Supplemental
cp "$S/Georgia.ttf" "$S/Georgia Bold.ttf" "$S/Arial.ttf" "$S/Arial Bold.ttf" scratch/capture-fonts/
M=~/fvm/versions/3.44.8/bin/cache/artifacts/material_fonts
cp $M/Roboto-Regular.ttf $M/Roboto-Medium.ttf $M/Roboto-Bold.ttf $M/MaterialIcons-Regular.otf scratch/capture-fonts/
```

Fotos: descarga con `curl` las tres primeras imágenes de cada producto de
`assets/catalog/catalog.json` (agrega `&width=640&format=jpg` a la URL del CDN)
a `scratch/capture-images/`, con el nombre del último segmento de la URL.
El `flutter_tester` no lee fuera del proyecto, de ahí las copias.

## Ejecución

```sh
# después del cambio (esta rama)
flutter test --no-pub --dart-define=CAPTURE_PHASE=despues \
  tool/captures/ficha_compra_captures_test.dart

# antes del cambio: un checkout limpio del commit base (b66e5c4) con el mismo archivo
flutter test --no-pub --dart-define=CAPTURE_PHASE=antes \
  tool/captures/ficha_compra_captures_test.dart
```

Salida: `scratch/captures/<fase>/*.png` y `metrics.json`. `--name "^30-"` ejecuta
un solo escenario (cuidado: reescribe `metrics.json` con ese subconjunto).

## Qué muestran y qué no

- Las fotos van al `ImageCache` con las claves exactas que pide la app
  (`CachedNetworkImage` necesita sqflite, que no existe en pruebas).
- `Inter` y `Playfair Display` no están empaquetadas. Un dispositivo dibuja la
  primera familia de respaldo que tenga (Helvetica Neue en iOS, Roboto en
  Android). Las capturas registran Arial y Georgia bajo esos nombres primarios
  como sustitutas: muestran el diseño y la jerarquía, no `Inter`.
- Las capturas no sustituyen la verificación en dispositivo.
