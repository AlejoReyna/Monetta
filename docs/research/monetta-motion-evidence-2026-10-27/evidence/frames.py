#!/usr/bin/env python3
"""Hoja de fotogramas con tiempos a partir de un video, para verificar una referencia.

Uso, desde la raíz del repositorio:

    python3 docs/research/monetta-motion-evidence-2026-10-27/evidence/frames.py \
        --source URL_O_ARCHIVO --id farfetch-add-to-bag --start 223 --end 233

--source acepta un archivo local o una URL directa (.mp4, .m3u8, .mov, .webm).
Para una página (YouTube, Vimeo) se resuelve con yt-dlp si está instalado.
Requiere ffmpeg y Pillow. Escribe evidence/<id>.jpg e imprime un registro con el
esquema de sources.json; no descarga el video completo.
"""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

EVIDENCE = Path(__file__).resolve().parent
MEDIA_SUFFIXES = (".mp4", ".m3u8", ".mov", ".webm", ".m4v")


def resolve(source):
    if Path(source).exists() or source.split("?")[0].lower().endswith(MEDIA_SUFFIXES):
        return source
    if not shutil.which("yt-dlp"):
        sys.exit("La fuente no es un archivo ni una URL de video directa; instala yt-dlp o pasa la URL del medio.")
    out = subprocess.run(["yt-dlp", "-g", "-f", "best[height<=1080]/best", source],
                         check=True, capture_output=True, text=True).stdout.split()
    return out[0]


def extract(media, start, end, fps, width, crop, workdir):
    vf = f"fps={fps},{'crop=' + crop + ',' if crop else ''}scale={width}:-2"
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-ss", str(start), "-to", str(end), "-i", media,
                    "-vf", vf, str(workdir / "%04d.png")], check=True)
    return sorted(workdir.glob("*.png"))


def sheet(frames, start, fps, columns):
    first = Image.open(frames[0])
    w, h = first.size
    label = 28
    rows = -(-len(frames) // columns)
    canvas = Image.new("RGB", (columns * w, rows * (h + label)), "white")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default(size=18)
    for i, path in enumerate(frames):
        x, y = (i % columns) * w, (i // columns) * (h + label)
        canvas.paste(Image.open(path).convert("RGB"), (x, y + label))
        draw.text((x + 8, y + 4), f"{start + i / fps:.2f} s", fill="black", font=font)
    return canvas


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--source", required=True)
    p.add_argument("--page", help="página pública donde aparece el video")
    p.add_argument("--type", default="grabación de app comercial")
    p.add_argument("--id", required=True, help="nombre del archivo de salida, p. ej. farfetch-add-to-bag")
    p.add_argument("--start", type=float, required=True, help="segundo inicial")
    p.add_argument("--end", type=float, required=True, help="segundo final")
    p.add_argument("--fps", type=float, default=4, help="fotogramas por segundo muestreados")
    p.add_argument("--width", type=int, default=240, help="ancho de cada fotograma")
    p.add_argument("--columns", type=int, default=8)
    p.add_argument("--crop", help="recorte previo con la sintaxis de ffmpeg, ancho:alto:x:y")
    a = p.parse_args()
    if a.end <= a.start:
        sys.exit("--end debe ser mayor que --start")

    media = resolve(a.source)
    with tempfile.TemporaryDirectory() as tmp:
        frames = extract(media, a.start, a.end, a.fps, a.width, a.crop, Path(tmp))
        if not frames:
            sys.exit("ffmpeg no devolvió fotogramas en esa ventana")
        out = EVIDENCE / f"{a.id}.jpg"
        sheet(frames, a.start, a.fps, a.columns).save(out, quality=85)

    print(json.dumps({"id": a.id, "page": a.page, "type": a.type, "video": a.source,
                      "window": [a.start, a.end], "consulted": date.today().isoformat(),
                      "verification": f"Hoja {len(frames)} fotogramas a {a.fps:g} fps; pendiente de inspección visual."},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
