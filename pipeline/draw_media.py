# Minimap Satchel © 2026 Ghosti. All Rights Reserved.
# Images de vitrine CurseForge (1280x720 PNG) tirées des maquettes validées,
# marquées « Mockup preview » (pas de capture en jeu).
#   build/media-1-satchel.png : sac ouvert, fond sombre, icônes sorties
#   build/media-2-class.png   : fond couleur de classe, mode « par addon »
#   build/media-3-mail.png    : les 3 animations courrier
# Usage : python pipeline/draw_media.py   (après draw_icons.py)
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
W, H = 1280, 720
ICON_COLORS = [(90, 180, 255), (190, 110, 255), (255, 150, 60), (110, 220, 120), (255, 215, 90),
               (240, 90, 90), (120, 230, 220), (230, 230, 230)]
GOLD = (201, 162, 74)


def font(size, bold=False):
    for name in (["arialbd.ttf"] if bold else []) + ["arial.ttf", "segoeui.ttf"]:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def bg():
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            k = (x / W + y / H) / 2
            px[x, y] = (int(52 - 18 * k), int(68 - 22 * k), int(44 - 14 * k))
    return img.convert("RGBA")


def minimap(img, cx, cy, r):
    m = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(m)
    for i in range(r, 0, -2):
        k = i / r
        d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=(int(70 + 40 * (1 - k)), int(100 + 40 * (1 - k)), int(55 + 25 * (1 - k)), 255))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(15, 15, 15, 255), width=8)
    d.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], outline=(90, 90, 90, 255), width=3)
    return Image.alpha_composite(img, m)


def round_icon(d, cx, cy, s, col, ring=GOLD):
    d.ellipse([cx - s, cy - s, cx + s, cy + s], fill=(22, 22, 26), outline=ring, width=4)
    d.ellipse([cx - s * .45, cy - s * .45, cx + s * .45, cy + s * .45], fill=col)


def sq_icon(d, x, y, s, col):
    d.rounded_rectangle([x, y, x + s, y + s], radius=8, fill=(26, 26, 30), outline=(85, 85, 90), width=2)
    d.ellipse([x + s * .28, y + s * .28, x + s * .72, y + s * .72], fill=col)


def paste_tex(img, path, cx, cy, size):
    t = Image.open(path).convert("RGBA").resize((size, size), Image.LANCZOS)
    img.alpha_composite(t, (int(cx - size / 2), int(cy - size / 2)))


def satchel_button(img, cx, cy, fill):
    d = ImageDraw.Draw(img)
    d.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], fill=fill + (255,), outline=GOLD, width=5)
    paste_tex(img, ROOT / "build" / "satchel_preview.png", cx, cy, 50)


def grid(img, x, y, cols, n, fill, alpha=235, labels=None):
    s, gap, pad = 58, 9, 14
    rows = math.ceil(n / cols)
    extra = 26 * len(labels or [])
    w, h = pad * 2 + cols * s + (cols - 1) * gap, pad * 2 + rows * s + (rows - 1) * gap + extra
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.rounded_rectangle([x, y, x + w, y + h], radius=10, fill=fill + (alpha,), outline=(60, 60, 66, 255), width=2)
    img.alpha_composite(g)
    d = ImageDraw.Draw(img)
    yy, i = y + pad, 0
    for lab, count in (labels or [(None, n)]):
        if lab:
            d.text((x + pad, yy), lab, font=font(20, True), fill=(255, 214, 90))
            yy += 26
        col = 0
        for _ in range(count):
            if col == cols:
                col, yy = 0, yy + s + gap
            sq_icon(d, x + pad + col * (s + gap), yy, s, ICON_COLORS[i % len(ICON_COLORS)])
            col, i = col + 1, i + 1
        yy += s + gap
    return w, h


def caption(img, title, sub):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([40, 36, 840, 150], radius=14, fill=(0, 0, 0, 150))
    d.text((64, 50), title, font=font(44, True), fill=(245, 235, 210))
    d.text((66, 106), sub, font=font(24), fill=(215, 215, 215))


def mockup_tag(img):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([W - 260, H - 64, W - 24, H - 22], radius=10, fill=(0, 0, 0, 180))
    d.text((W - 244, H - 58), "Mockup preview", font=font(26, True), fill=(255, 210, 90))


def media_satchel():
    img = minimap(bg(), 960, 330, 190)
    d = ImageDraw.Draw(img)
    round_icon(d, 760, 210, 30, ICON_COLORS[0])           # icônes sorties à la main
    round_icon(d, 1150, 470, 30, ICON_COLORS[3])
    satchel_button(img, 800, 470, (10, 10, 12))
    grid(img, 430, 500, 6, 10, (10, 10, 12))
    caption(img, "One satchel for every minimap icon",
            "Auto-collected. Drag out the ones you want to keep.")
    d = ImageDraw.Draw(img)
    d.text((250, 640), "drag out  →  stays around the minimap", font=font(22), fill=(230, 230, 230))
    mockup_tag(img)
    return img.convert("RGB")


def media_class():
    img = minimap(bg(), 960, 330, 190)
    d = ImageDraw.Draw(img)
    round_icon(d, 760, 210, 30, ICON_COLORS[4])
    mage = (63, 199, 235)
    satchel_button(img, 800, 470, mage)
    grid(img, 400, 380, 5, 8, mage, 215, labels=[("TradeSkillMaster", 3), ("Other addons", 5)])
    caption(img, "Dark or class-colored", "Group icons by addon to spot duplicates.")
    mockup_tag(img)
    return img.convert("RGB")


def media_mail():
    img = bg()
    d = ImageDraw.Draw(img)
    caption(img, "Animated mail alert + sound", "Plays once when new mail arrives. 3 styles.")
    names = ["Bounce + glow", "Flying letter", "Shake + sparks"]
    env = ROOT / "build" / "envelope_preview.png"
    for i, name in enumerate(names):
        cx, cy = 230 + i * 410, 420
        panel = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(panel).rounded_rectangle([cx - 180, cy - 170, cx + 180, cy + 190], radius=16, fill=(0, 0, 0, 120))
        img.alpha_composite(panel)
        img = minimap(img, cx, cy + 20, 110)
        ex, ey = cx + 95, cy - 80
        if i == 0:
            halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ImageDraw.Draw(halo).ellipse([ex - 55, ey - 75, ex + 55, ey + 35], fill=(255, 215, 106, 200))
            img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(14)))
            paste_tex(img, env, ex, ey - 20, 70)
        elif i == 1:
            paste_tex(img, env, ex, ey, 70)
            for k, (fx, fy) in enumerate([(cx - 150, cy + 150), (cx - 90, cy + 70), (cx - 30, cy)]):
                t = Image.open(env).convert("RGBA").resize((40 + k * 8, 40 + k * 8))
                t = t.rotate(-20 + k * 12, expand=True)
                a = t.split()[3].point(lambda v, k=k: int(v * (0.35 + 0.25 * k)))
                t.putalpha(a)
                img.alpha_composite(t, (int(fx), int(fy)))
        else:
            t = Image.open(env).convert("RGBA").resize((70, 70)).rotate(16, expand=True)
            img.alpha_composite(t, (int(ex - t.width / 2), int(ey - t.height / 2)))
            d2 = ImageDraw.Draw(img)
            for sx, sy in [(-50, -40), (48, -46), (54, 34), (-48, 40), (0, -62)]:
                d2.ellipse([ex + sx - 5, ey + sy - 5, ex + sx + 5, ey + sy + 5], fill=(255, 233, 160))
        d = ImageDraw.Draw(img)
        tw = d.textlength(name, font=font(28, True))
        d.text((cx - tw / 2, cy + 145), name, font=font(28, True), fill=(245, 235, 210))
    mockup_tag(img)
    return img.convert("RGB")


if __name__ == "__main__":
    BUILD.mkdir(exist_ok=True)
    media_satchel().save(BUILD / "media-1-satchel.png")
    media_class().save(BUILD / "media-2-class.png")
    media_mail().save(BUILD / "media-3-mail.png")
    print("ok", BUILD)
