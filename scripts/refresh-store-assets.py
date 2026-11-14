#!/usr/bin/env python3
"""Regenerate the Play Store image assets from the committed brand files.

The icon must be a 512x512 32-bit PNG and the feature graphic 1024x500 PNG
with no transparency and no device frames, per Play Console requirements.
Run from the repository root: python3 scripts/refresh-store-assets.py
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
STORE = ROOT / "store"
BRAND = ROOT / "app-flutter" / "assets" / "brand"
GRAD = [(0x3D, 0x7B, 0xFF), (0x1E, 0x4F, 0xD8)]
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def gradient(size, top_left=(0, 0), bottom_right=None):
    w, h = size
    bottom_right = bottom_right or size
    base = Image.new("RGB", size)
    px = base.load()
    x0, y0 = top_left
    x1, y1 = bottom_right
    for y in range(h):
        for x in range(w):
            tx = min(max((x - x0) / max(x1 - x0 - 1, 1), 0), 1)
            ty = min(max((y - y0) / max(y1 - y0 - 1, 1), 0), 1)
            t = (tx + ty) / 2
            px[x, y] = tuple(
                round(GRAD[0][i] + (GRAD[1][i] - GRAD[0][i]) * t) for i in range(3)
            )
    return base


def build_icon():
    icon = gradient((512, 512)).convert("RGBA")
    mark = Image.open(BRAND / "nexus-mark-reversed.png").convert("RGBA")
    mark.thumbnail((300, 300), Image.LANCZOS)
    icon.alpha_composite(
        mark, ((512 - mark.width) // 2, (512 - mark.height) // 2 - 14)
    )
    draw = ImageDraw.Draw(icon)
    word = ImageFont.truetype(FONT_BOLD, 46)
    text = "NEXUS"
    width = draw.textlength(text, font=word)
    draw.text(((512 - width) / 2, 372), text, font=word, fill=(255, 255, 255, 255))
    icon.convert("RGB").save(STORE / "icon-512.png", optimize=True)
    return STORE / "icon-512.png"


def build_feature_graphic():
    canvas = gradient((1024, 500)).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    mark = Image.open(BRAND / "nexus-mark-reversed.png").convert("RGBA")
    mark.thumbnail((190, 190), Image.LANCZOS)
    canvas.alpha_composite(mark, (90, (500 - mark.height) // 2 - 20))

    title = ImageFont.truetype(FONT_BOLD, 92)
    tagline = ImageFont.truetype(FONT_REG, 34)
    draw.text((330, 150), "NEXUS", font=title, fill=(255, 255, 255, 255))
    draw.text(
        (334, 262), "Business & Community", font=tagline, fill=(235, 240, 255, 255)
    )
    draw.rectangle([334, 320, 334 + 430, 326], fill=(255, 255, 255, 110))
    small = ImageFont.truetype(FONT_REG, 24)
    draw.text(
        (334, 348),
        "Local feed · Groups · Shops · Chat",
        font=small,
        fill=(226, 234, 255, 255),
    )
    canvas.convert("RGB").save(STORE / "feature-graphic-1024x500.png", optimize=True)
    return STORE / "feature-graphic-1024x500.png"


if __name__ == "__main__":
    STORE.mkdir(exist_ok=True)
    for path in (build_icon(), build_feature_graphic()):
        im = Image.open(path)
        print(f"{path.relative_to(ROOT)}  {im.size}  {im.mode}  {path.stat().st_size} bytes")
