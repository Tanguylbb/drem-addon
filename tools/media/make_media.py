#!/usr/bin/env python3
"""Fabrique les images de l'add-on : le blason du site (logo.tga, minimap.tga) et les
icônes des onglets. Écrit des TGA 32 bits dans DernierRempart/Media (le jeu lit les TGA).

Le blason n'est pas redessiné : il vient du SVG du site (tools/media/logo-site.svg,
copie de https://dernier-rempart.eu/favicon.svg), rendu par Chromium
(tools/media/render_logo.js).

Usage : python3 tools/media/make_media.py   (depuis la racine du dépôt)
Nécessite Pillow, Node et Playwright. Les TGA produits sont gardés dans le dépôt :
ce script n'est utile que pour les retoucher.
"""
import math
import os
import subprocess
import tempfile
from PIL import Image, ImageDraw, ImageChops

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "DernierRempart", "Media")
SS = 4  # suréchantillonnage


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def vgrad(w, h, top, bottom):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    t, b = rgb(top), rgb(bottom)
    for y in range(h):
        k = y / max(1, h - 1)
        c = tuple(int(t[i] + (b[i] - t[i]) * k) for i in range(3)) + (255,)
        for x in range(w):
            px[x, y] = c
    return img


def fill(base, fillimg, draw_mask):
    """Peint fillimg sur base, là où draw_mask(ImageDraw) a dessiné en blanc."""
    mask = Image.new("L", base.size, 0)
    draw_mask(ImageDraw.Draw(mask))
    base.paste(fillimg, (0, 0), mask)


def outline(base, color, draw_shape, width):
    d = ImageDraw.Draw(base)
    draw_shape(d, color, width)


def canvas(n):
    return Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))


def finish(img, n):
    return img.resize((n, n), Image.LANCZOS)


def save(img, name):
    path = os.path.join(OUT, name + ".tga")
    img.save(path, "TGA")
    print("écrit", os.path.normpath(path))


def s(v):
    return int(round(v * SS))


GOLD = ("FBE9A0", "B98A25")


# Le blason du site : 48 x 56, donc 6:7. La texture est un carré de 256 : le blason
# occupe toute la hauteur et est centré ; le code recadre avec Theme.LogoCoords.
def logo_render(height=1024):
    """Le blason du site en grand (image RGBA, fond transparent), rendu par Chromium."""
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(tempfile.mkdtemp(), "logo.png")
    env = dict(os.environ)
    if "NODE_PATH" not in env:
        env["NODE_PATH"] = subprocess.check_output(["npm", "root", "-g"], text=True).strip()
    subprocess.check_call(["node", os.path.join(here, "render_logo.js"), out, str(height)], env=env)
    return Image.open(out).convert("RGBA")


def logo_fit(big, box, height):
    """Le blason à la hauteur voulue, centré dans un carré transparent de côté box."""
    w = round(height * big.width / big.height)
    small = big.resize((w, height), Image.LANCZOS)
    img = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    img.alpha_composite(small, ((box - w) // 2, (box - height) // 2))
    return img


def logo_files(big):
    save(logo_fit(big, 256, 256), "logo")
    # Bouton de la minicarte : un disque sombre (le bleu nuit du site) et le blason.
    n = 128
    disc = Image.new("RGBA", (n * 4, n * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(disc)
    d.ellipse([0, 0, n * 4 - 1, n * 4 - 1], fill=rgb("0A1220") + (255,))
    d.ellipse([n * 0.05 * 4, n * 0.05 * 4, n * 4 - n * 0.05 * 4 - 1, n * 4 - n * 0.05 * 4 - 1],
              outline=rgb("E6C47C") + (150,), width=int(n * 0.03 * 4))
    shield = logo_fit(big, n * 4, int(n * 4 * 0.70))
    disc.alpha_composite(shield)
    save(disc.resize((64, 64), Image.LANCZOS), "minimap")


def poly(pts, k=1.0):
    return [(s(x * k), s(y * k)) for x, y in pts]


def icon_calendar(n=64):
    img = canvas(n)
    k = n / 32
    fill(img, vgrad(img.width, img.height, "FFF4D6", "D9C79A"), lambda m: m.rounded_rectangle([s(4 * k), s(6 * k), s(28 * k), s(28 * k)], radius=s(2.5 * k), fill=255))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([s(4 * k), s(6 * k), s(28 * k), s(13 * k)], radius=s(2.5 * k), fill=rgb("B02A14"))
    d.rounded_rectangle([s(4 * k), s(6 * k), s(28 * k), s(28 * k)], radius=s(2.5 * k), outline=rgb("3A2610"), width=s(1.5 * k))
    d.line([s(4 * k), s(13 * k), s(28 * k), s(13 * k)], fill=rgb("3A2610"), width=s(1.2 * k))
    for x in (9, 20):
        d.rounded_rectangle([s(x * k), s(3 * k), s((x + 3) * k), s(9 * k)], radius=s(1 * k), fill=rgb("8A6A30"), outline=rgb("3A2610"), width=s(.8 * k))
    for (x, y, red) in ((8, 16, 0), (14, 16, 0), (20, 16, 0), (8, 21, 0), (14, 21, 1), (20, 21, 0)):
        d.rectangle([s(x * k), s(y * k), s((x + 4) * k), s((y + 3) * k)], fill=rgb("B02A14" if red else "5A3A14"))
    save(finish(img, n), "tab_sorties")


def icon_anvil(n=64):
    img = canvas(n)
    k = n / 32
    body = [(3, 11), (24, 11), (23.5, 14), (21, 16), (17.5, 17.2), (17.5, 20), (22.5, 20), (22.5, 25), (9.5, 25), (9.5, 20), (14.5, 20), (14.5, 17.2), (9, 16), (5.5, 14)]
    fill(img, vgrad(img.width, img.height, "C4CCD8", "59616F"), lambda m: m.polygon(poly(body, k), fill=255))
    d = ImageDraw.Draw(img)
    d.line(poly(body + [body[0]], k), fill=rgb("1B1F27"), width=s(1.4 * k), joint="curve")
    # marteau
    d.line([s(17 * k), s(9.5 * k), s(25 * k), s(5.5 * k)], fill=rgb("2A1608"), width=s(3.4 * k))
    d.line([s(17 * k), s(9.5 * k), s(25 * k), s(5.5 * k)], fill=rgb("7A4A1C"), width=s(2.4 * k))
    d.polygon(poly([(23, 2.5), (29.5, 5.5), (27.5, 8.5), (21, 5.5)], k), fill=rgb("9AA3B0"), outline=rgb("1B1F27"))
    save(finish(img, n), "tab_artisans")


def icon_people(n=64):
    """Deux silhouettes : « Qui est là » (l'onglet qui montrait une carte)."""
    img = canvas(n)
    k = n / 32

    def person(cx, top, scale, c1, c2):
        head = [s((cx - 4.2 * scale) * k), s(top * k), s((cx + 4.2 * scale) * k), s((top + 8.4 * scale) * k)]
        body = [s((cx - 8.2 * scale) * k), s((top + 10 * scale) * k), s((cx + 8.2 * scale) * k), s((top + 10 * scale + 2 * 9.5 * scale) * k)]
        fill(img, vgrad(img.width, img.height, c1, c2), lambda m: (m.ellipse(head, fill=255), m.pieslice(body, 180, 360, fill=255)))
        d = ImageDraw.Draw(img)
        d.ellipse(head, outline=rgb("1B1F27"), width=s(1.1 * k))
        d.arc(body, 180, 360, fill=rgb("1B1F27"), width=s(1.1 * k))

    person(21.5, 5.5, 0.82, "9FB6DF", "3D5688")   # derrière, plus petit
    person(12.5, 6, 1.0, "F6D55A", "B58A22")       # devant, doré
    save(finish(img, n), "tab_presents")


def icon_coins(n=64):
    img = canvas(n)
    k = n / 32
    d = ImageDraw.Draw(img)
    d.rectangle([s(5 * k), s(14 * k), s(27 * k), s(23 * k)], fill=rgb("C28F28"))
    for cy in (23, 18, 12):
        box = [s(5 * k), s((cy - 4.5) * k), s(27 * k), s((cy + 4.5) * k)]
        fill(img, vgrad(img.width, img.height, *GOLD), lambda m, b=box: m.ellipse(b, fill=255))
        d = ImageDraw.Draw(img)
        d.ellipse(box, outline=rgb("5A3A0C"), width=s(1.2 * k))
    d.ellipse([s(11 * k), s(7.2 * k), s(21 * k), s(10.8 * k)], outline=rgb("7A5A14"), width=s(1 * k))
    save(finish(img, n), "tab_effort")


def icon_shield(n=64):
    img = canvas(n)
    k = n / 32
    shield = [(16, 3), (27, 7), (27, 16), (24, 23), (16, 29), (8, 23), (5, 16), (5, 7)]
    fill(img, vgrad(img.width, img.height, "6C86B8", "1B2D55"), lambda m: m.polygon(poly(shield, k), fill=255))
    d = ImageDraw.Draw(img)
    d.line(poly(shield + [shield[0]], k), fill=rgb("E6C47C"), width=s(2 * k), joint="curve")
    star = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = 6.2 if i % 2 == 0 else 2.7
        star.append((16 + rr * math.cos(a), 15 + rr * math.sin(a)))
    d.polygon(poly(star, k), fill=rgb("F6D55A"), outline=rgb("7A5A14"))
    save(finish(img, n), "tab_officiers")


def croix(n=32):
    """Croix dorée du bouton fermer (teintée en code)."""
    img = canvas(n)
    d = ImageDraw.Draw(img)
    w = s(n * 0.14)
    a, b = s(n * 0.24), s(n * 0.76)
    d.line([a, a, b, b], fill=(255, 255, 255, 255), width=w)
    d.line([a, b, b, a], fill=(255, 255, 255, 255), width=w)
    save(finish(img, n), "croix")


def coche(n=32):
    """Coche blanche (teintée en code : dorée, verte...)."""
    img = canvas(n)
    d = ImageDraw.Draw(img)
    w = s(n * 0.13)
    pts = [(s(n * 0.2), s(n * 0.54)), (s(n * 0.42), s(n * 0.76)), (s(n * 0.8), s(n * 0.26))]
    d.line(pts, fill=(255, 255, 255, 255), width=w, joint="curve")
    for x, y in (pts[0], pts[2]):
        d.ellipse([x - w // 2, y - w // 2, x + w // 2, y + w // 2], fill=(255, 255, 255, 255))
    save(finish(img, n), "coche")


def contact_sheet():
    names = ["logo", "minimap", "tab_sorties", "tab_artisans", "tab_presents", "tab_effort", "tab_officiers", "croix", "coche"]
    sheet = Image.new("RGBA", (len(names) * 140, 140), (30, 24, 18, 255))
    for i, nme in enumerate(names):
        im = Image.open(os.path.join(OUT, nme + ".tga")).convert("RGBA")
        im = im.resize((128, 128), Image.LANCZOS)
        sheet.alpha_composite(im, (i * 140 + 6, 6))
    return sheet


if __name__ == "__main__":
    logo_files(logo_render())
    icon_calendar()
    icon_anvil()
    icon_people()
    icon_coins()
    icon_shield()
    croix(32)
    coche(32)
    sheet = contact_sheet()
    sheet.save(os.environ.get("CONTACT", "/tmp/contact.png"))
