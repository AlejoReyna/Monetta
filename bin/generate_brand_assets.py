#!/usr/bin/env python3
"""Regenerate every Monetta logo, favicon and app icon from the brand masters.

Masters, gold on white exactly as delivered:
  docs/design/brand/monetta-wordmark.webp  MONETTA wordmark
  docs/design/brand/monetta-monogram.webp  M with the drop

Each output keeps the pixel size of the file it replaces, so nothing that
depends on those sizes changes: the 132:38 wordmark ratio in
storefront-theme/snippets/monetta-logo.liquid and MonettaWordmark, and the
iOS/Android icon sets.

Usage: python3 bin/generate_brand_assets.py   (needs Pillow and numpy)
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
WORDMARK_MASTER = ROOT / "docs/design/brand/monetta-wordmark.webp"
MONOGRAM_MASTER = ROOT / "docs/design/brand/monetta-monogram.webp"

# The palest channel of the gold never exceeds 214 in the masters; anything
# that dark is solid metal. Between that and white the pixel is antialiasing
# or the soft fringe around the letters, so it fades out instead of being cut.
SOLID_BELOW = 215
CLEAR_FROM = 252
# A light region enclosed by gold is a counter (the inside of O or A) when it
# is mostly bare paper, and a shine on the metal otherwise. Counters measure
# 83-95 % paper in the masters; shines at most 41 %.
COUNTER_PAPER_SHARE = 0.75
PAPER = 250

# Share of the canvas width the monogram fills, measured on the icons and
# favicons it replaces, so the new mark sits at the same visual size.
ICON_GLYPH_WIDTH = 0.595
FAVICON_GLYPH_WIDTH = 0.61

WORDMARK_OUTPUTS = {
    "assets/images/logo_monetta.png": (132, 38),
    "assets/images/2.0x/logo_monetta.png": (264, 76),
    "assets/images/3.0x/logo_monetta.png": (396, 113),
    "storefront-theme/assets/monetta-logo.png": (132, 38),
    "storefront-theme/assets/monetta-logo-2x.png": (264, 76),
    "storefront-theme/assets/monetta-logo-3x.png": (396, 113),
}

MONOGRAM_OUTPUTS = {
    "assets/images/monetta_logo.png": (1080, ICON_GLYPH_WIDTH),
    "assets/images/monetta_favicon.png": (32, FAVICON_GLYPH_WIDTH),
    "assets/images/2.0x/monetta_favicon.png": (64, FAVICON_GLYPH_WIDTH),
    "assets/images/3.0x/monetta_favicon.png": (96, FAVICON_GLYPH_WIDTH),
    "storefront-theme/assets/monetta-favicon-32.png": (32, FAVICON_GLYPH_WIDTH),
    "storefront-theme/assets/monetta-favicon-96.png": (96, FAVICON_GLYPH_WIDTH),
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": (48, ICON_GLYPH_WIDTH),
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": (72, ICON_GLYPH_WIDTH),
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": (96, ICON_GLYPH_WIDTH),
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": (144, ICON_GLYPH_WIDTH),
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": (192, ICON_GLYPH_WIDTH),
}

IOS_ICON_SET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"


def load_rgb(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64)


def enclosed_shines(palest: np.ndarray) -> np.ndarray:
    """Light regions surrounded by gold that are highlights, not counters."""
    light = palest >= SOLID_BELOW
    # Frame the mask so every light region touching an edge joins one outer
    # region, then clear it; only enclosed regions stay marked. fromarray
    # images are read-only views, hence the copies.
    framed = np.pad(light, 1, constant_values=True)
    regions = Image.fromarray(np.where(framed, 255, 0).astype(np.uint8), "L").copy()
    ImageDraw.floodfill(regions, (0, 0), 0)
    shines = np.zeros_like(light)
    while True:
        remaining = np.flatnonzero(np.array(regions)[1:-1, 1:-1] == 255)
        if remaining.size == 0:
            return shines
        y, x = divmod(int(remaining[0]), light.shape[1])
        ImageDraw.floodfill(regions, (x + 1, y + 1), 128)
        region = np.array(regions)[1:-1, 1:-1] == 128
        if (palest[region] >= PAPER).mean() < COUNTER_PAPER_SHARE:
            shines |= region
        ImageDraw.floodfill(regions, (x + 1, y + 1), 0)


def gold_on_transparent(rgb: np.ndarray) -> Image.Image:
    """Lift the gold off its white background, keeping highlights opaque."""
    palest = rgb.min(axis=2)
    alpha = np.clip((CLEAR_FROM - palest) / (CLEAR_FROM - SOLID_BELOW), 0.0, 1.0)
    alpha[enclosed_shines(palest)] = 1.0
    # Remove the white mixed into partly transparent pixels so their edges
    # read as gold, not as a pale outline, on dark backgrounds.
    safe = np.where(alpha > 0, alpha, 1.0)[..., None]
    color = np.clip((rgb - 255.0 * (1.0 - alpha[..., None])) / safe, 0, 255)
    rgba = np.dstack([color, alpha * 255.0]).round().astype(np.uint8)
    image = Image.fromarray(rgba, "RGBA")
    return image.crop(image.getchannel("A").point(lambda a: 255 if a > 4 else 0).getbbox())


def fit_transparent(mark: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale the mark to fit inside size, centred on a transparent canvas."""
    scale = min(size[0] / mark.width, size[1] / mark.height)
    target = (max(1, round(mark.width * scale)), max(1, round(mark.height * scale)))
    # Resample premultiplied so transparent pixels cannot bleed colour.
    scaled = mark.convert("RGBa").resize(target, Image.LANCZOS, reducing_gap=3.0).convert("RGBA")
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(scaled, ((size[0] - target[0]) // 2, (size[1] - target[1]) // 2))
    return canvas


def glyph_on_white(mark: Image.Image, side: int, glyph_width: float) -> Image.Image:
    """The mark centred on pure white, filling glyph_width of a side-px square.

    Rebuilt on white instead of cropped from the master, whose background is
    not uniformly white around the glyph and would show as a faint box.
    """
    square = round(mark.width / glyph_width)
    canvas = Image.new("RGBA", (square, square), (255, 255, 255, 255))
    canvas.alpha_composite(mark, ((square - mark.width) // 2, (square - mark.height) // 2))
    return canvas.convert("RGB").resize((side, side), Image.LANCZOS, reducing_gap=3.0)


def ios_icon_outputs() -> dict[str, int]:
    contents = json.loads((IOS_ICON_SET / "Contents.json").read_text())
    outputs: dict[str, int] = {}
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        outputs[str((IOS_ICON_SET / entry["filename"]).relative_to(ROOT))] = round(points * scale)
    return outputs


def save(image: Image.Image, relative: str) -> None:
    path = ROOT / relative
    image.save(path, optimize=True)
    print(f"{relative} {image.size[0]}x{image.size[1]} {image.mode}")


def main() -> None:
    wordmark = gold_on_transparent(load_rgb(WORDMARK_MASTER))
    for relative, size in WORDMARK_OUTPUTS.items():
        save(fit_transparent(wordmark, size), relative)

    monogram = gold_on_transparent(load_rgb(MONOGRAM_MASTER))
    for relative, (side, glyph_width) in MONOGRAM_OUTPUTS.items():
        save(glyph_on_white(monogram, side, glyph_width), relative)
    # iOS rejects app icons with an alpha channel, so these stay plain RGB.
    for relative, side in ios_icon_outputs().items():
        save(glyph_on_white(monogram, side, ICON_GLYPH_WIDTH), relative)


if __name__ == "__main__":
    main()
