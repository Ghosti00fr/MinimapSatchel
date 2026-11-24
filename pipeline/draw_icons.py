# Minimap Satchel © 2026 Ghosti. All Rights Reserved.
# Textures du bouton-sac (64x64 TGA) et logo CurseForge 400x400 (PNG).
#   MinimapSatchel/textures/satchel.tga : sacoche en cuir, rabat, boucle dorée
#   MinimapSatchel/textures/disc.tga    : disque blanc (fond teinté en jeu)
#   MinimapSatchel/textures/envelope.tga : enveloppe au sceau rouge (alerte courrier)
#   build/logo.png                      : sacoche sur fond sombre, icônes qui en sortent
# Usage : python pipeline/draw_icons.py   (depuis la racine du projet)
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
TEX = ROOT / "MinimapSatchel" / "textures"
BUILD = ROOT / "build"
K = 4

LEATHER = (122, 74, 38)
LEATHER_DARK = (78, 45, 22)
LEATHER_LIGHT = (168, 108, 58)
GOLD = (232, 190, 90)
GOLD_DARK = (140, 100, 30)
STITCH = (226, 196, 140)


def satchel(size):
    """Sacoche vue de face, dessinée à size*K puis réduite."""
    n = size * K
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = n / 64
    # anse
    d.arc([18 * u, 4 * u, 46 * u, 30 * u], 180, 360, fill=LEATHER_DARK, width=int(5 * u))
    # corps
    d.rounded_rectangle([8 * u, 18 * u, 56 * u, 58 * u], radius=9 * u, fill=LEATHER, outline=LEATHER_DARK,
                        width=int(2.5 * u))
    # reflet haut du corps
    d.rounded_rectangle([12 * u, 21 * u, 52 * u, 27 * u], radius=3 * u, fill=LEATHER_LIGHT)
    # rabat
    d.polygon([(8 * u, 20 * u), (56 * u, 20 * u), (52 * u, 40 * u), (32 * u, 46 * u), (12 * u, 40 * u)],
              fill=LEATHER_DARK)
    d.line([(12 * u, 23 * u), (52 * u, 23 * u), (49 * u, 38 * u), (32 * u, 43 * u), (15 * u, 38 * u),
            (12 * u, 23 * u)], fill=STITCH, width=int(1.2 * u))
    # boucle
    d.rounded_rectangle([26 * u, 38 * u, 38 * u, 50 * u], radius=2 * u, fill=GOLD, outline=GOLD_DARK,
                        width=int(2 * u))
    d.rectangle([30.5 * u, 41 * u, 33.5 * u, 47 * u], fill=GOLD_DARK)
    return img.resize((size, size), Image.LANCZOS)


def envelope(size):
    """Enveloppe crème au sceau de cire rouge (proche de l'icône courrier du jeu)."""
    n = size * K
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = n / 64
    paper, edge = (240, 226, 190), (120, 90, 50)
    d.rounded_rectangle([4 * u, 14 * u, 60 * u, 52 * u], radius=4 * u, fill=paper, outline=edge, width=int(2.5 * u))
    d.line([(5 * u, 50 * u), (26 * u, 32 * u)], fill=edge, width=int(1.6 * u))
    d.line([(59 * u, 50 * u), (38 * u, 32 * u)], fill=edge, width=int(1.6 * u))
    d.polygon([(5 * u, 15 * u), (59 * u, 15 * u), (32 * u, 38 * u)], fill=(228, 210, 168), outline=edge)
    d.ellipse([23 * u, 27 * u, 41 * u, 45 * u], fill=(176, 28, 30), outline=(110, 12, 14), width=int(2 * u))
    d.ellipse([28 * u, 31 * u, 34 * u, 36 * u], fill=(214, 70, 64))
    return img.resize((size, size), Image.LANCZOS)


def disc(size):
    n = size * K
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    ImageDraw.Draw(img).ellipse([0, 0, n - 1, n - 1], fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def logo():
    S = 400
    bg = Image.new("RGB", (S, S))
    px = bg.load()
    for y in range(S):
        for x in range(S):
            k = max(0.0, 1 - math.hypot(x - S / 2, y - S / 2) / (S * .72))
            px[x, y] = (int(10 + 26 * k), int(9 + 20 * k), int(12 + 18 * k))
    img = bg.convert("RGBA")
    # anneau de minimap
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([40, 40, 360, 360], outline=(70, 90, 60, 255), width=10)
    img = Image.alpha_composite(img, ring)
    # petites icônes rondes qui s'envolent du sac
    cols = [(90, 180, 255), (190, 110, 255), (255, 150, 60), (110, 220, 120), (255, 215, 90)]
    for i, c in enumerate(cols):
        a = math.radians(-160 + i * 35)
        cx, cy = 200 + math.cos(a) * 150, 215 + math.sin(a) * 150
        glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=c + (150,))
        img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(10)))
        d = ImageDraw.Draw(img)
        d.ellipse([cx - 17, cy - 17, cx + 17, cy + 17], fill=(18, 18, 22), outline=GOLD, width=4)
        d.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=c)
    # ombre + sacoche
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([110, 300, 290, 340], fill=(0, 0, 0, 160))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(12)))
    bag = satchel(210)
    img.alpha_composite(bag, (95, 125))
    return img.convert("RGB")


if __name__ == "__main__":
    TEX.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    satchel(64).save(TEX / "satchel.tga")
    disc(64).save(TEX / "disc.tga")
    envelope(64).save(TEX / "envelope.tga")
    envelope(256).save(BUILD / "envelope_preview.png")
    logo().save(BUILD / "logo.png")
    satchel(256).save(BUILD / "satchel_preview.png")
    print("ok", TEX, BUILD)
