# Investigación visual V2 de Monetta

Leer [INVESTIGACION_V2.md](INVESTIGACION_V2.md) y usar [LOGO_Y_ENTREGA.md](LOGO_Y_ENTREGA.md) para encargar el prototipo. Esta entrega sustituye las recomendaciones del informe anterior; no implementa cambios en la app.

[REFERENCIAS_COMERCIALES.md](REFERENCIAS_COMERCIALES.md) reúne las referencias comerciales verificadas en grabaciones de ocho apps (FARFETCH, Moda Operandi, Zara, HBX, Lyst, ASOS, Zalando y Shop), con 30 hojas de fotogramas. `evidence/frames.py` regenera cualquier hoja.

## Ver referencias

Desde la raíz del repositorio:

```sh
python3 -m http.server 8878 --bind 127.0.0.1 --directory docs/research/monetta-motion-evidence-2026-10-27
```

Abrir http://127.0.0.1:8878. También se puede abrir index.html directamente para consultar los fotogramas y enlaces externos. Los enlaces Markdown pueden descargarse en el navegador: leerlos en el editor.

La galería usa fotogramas locales; no reproduce ni descarga videos automáticamente. Los botones abren fuentes públicas y demos. Algunos códigos fuente de Motion requieren pago; no se necesitan para reproducir el mecanismo con APIs propias de Flutter.

## Evidencia

- `evidence/sources.json`: URLs, duración del clip descargado y resultado de inspección.
- `evidence/*.jpg`: fotogramas con tiempos del material del autor, no capturas de una implementación nueva.
- Los archivos de video completos se usaron temporalmente para análisis y no se redistribuyen en el repositorio.
- Los clips Paul Smith se obtuvieron del reproductor público; el decodificador emitió advertencias de segmentos. Se pudieron inspeccionar los fotogramas mostrados; no se usan esos archivos para certificar duración exacta o fluidez. Abrir el reproductor original para inspección continua.
- Ninguna afirmación de accesibilidad/rendimiento de los referentes se deriva de sus videos.
- Las imágenes y marcas siguen perteneciendo a sus autores. La atribución está junto a cada secuencia y en el registro; no reutilizarlas como activos de Monetta.
