# TweakSuite - Copyright (C) 2026 Malikor
# SPDX-License-Identifier: MIT
"""Regenerate TweakSuite artwork: python tools/make_art.py TweakSuite/Media/Icon.tga media/icon-256.png media/logo.png
Needs Pillow and the DejaVu fonts (development only)."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math, sys
OUT_ICON_TGA, OUT_ICON_PNG, OUT_LOGO = sys.argv[1:4]
S = 512
GOLD = (236, 190, 74); GOLD_D = (150, 108, 34); RED = (210, 52, 52); RED_D = (120, 22, 22)

def icon(size=S):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # radial dark background
    bg = Image.new("RGBA", (size, size))
    px = bg.load(); c = size / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c * 0.85) / (size * 0.75)
            t = max(0.0, min(1.0, d))
            px[x, y] = (int(58 - 40 * t), int(40 - 28 * t), int(26 - 18 * t), 255)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([8, 8, size - 9, size - 9], radius=70, fill=255)
    im.paste(bg, (0, 0), mask)
    d = ImageDraw.Draw(im)
    # gold frame
    d.rounded_rectangle([8, 8, size - 9, size - 9], radius=70, outline=GOLD_D, width=18)
    d.rounded_rectangle([20, 20, size - 21, size - 21], radius=60, outline=GOLD, width=6)
    # three slider tracks with knobs at different positions ("tweaks")
    tracks = [(150, 0.30, GOLD), (256, 0.68, RED), (362, 0.48, GOLD)]
    for y, pos, knob in tracks:
        d.rounded_rectangle([96, y - 14, size - 96, y + 14], radius=14, fill=(20, 14, 10, 255), outline=GOLD_D, width=4)
        x = 96 + pos * (size - 192)
        d.rounded_rectangle([96, y - 7, x, y + 7], radius=7, fill=(GOLD if knob == GOLD else RED_D))
        r = 40
        shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).ellipse([x - r + 6, y - r + 8, x + r + 6, y + r + 8], fill=(0, 0, 0, 140))
        im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(6)))
        d = ImageDraw.Draw(im)
        dark = GOLD_D if knob == GOLD else RED_D
        d.ellipse([x - r, y - r, x + r, y + r], fill=dark)
        d.ellipse([x - r + 7, y - r + 7, x + r - 7, y + r - 7], fill=knob)
        d.ellipse([x - r + 16, y - r + 12, x + 4, y - 4], fill=tuple(min(255, v + 45) for v in knob))
    return im

big = icon()
small = big.resize((64, 64), Image.LANCZOS)
small.save(OUT_ICON_TGA, format="TGA")           # 32-bit uncompressed for the TOC IconTexture
big.resize((256, 256), Image.LANCZOS).save(OUT_ICON_PNG)

# Logo banner
W, H = 1200, 300
logo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
bg = Image.new("RGBA", (W, H)); p = bg.load()
for y in range(H):
    for x in range(W):
        t = x / W
        p[x, y] = (int(34 + 10 * (1 - t)), int(24 + 6 * (1 - t)), int(16 + 4 * (1 - t)), 255)
m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, H - 1], radius=40, fill=255)
logo.paste(bg, (0, 0), m)
d = ImageDraw.Draw(logo)
d.rounded_rectangle([4, 4, W - 5, H - 5], radius=38, outline=GOLD_D, width=6)
logo.alpha_composite(big.resize((230, 230), Image.LANCZOS), (36, 35))
bold = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"; reg = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
f1 = ImageFont.truetype(bold, 104); f2 = ImageFont.truetype(reg, 34)
d.text((300, 66), "Tweak", font=f1, fill=GOLD)
w = d.textlength("Tweak", font=f1)
d.text((300 + w, 66), "Suite", font=f1, fill=RED)
d.text((304, 196), "Quality-of-life tweaks for World of Warcraft: Forever", font=f2, fill=(232, 220, 196))
logo.save(OUT_LOGO)
