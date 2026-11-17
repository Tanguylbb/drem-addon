#!/usr/bin/env python3
"""Dessine les images du style « fidèle au jeu » : médaillon à la tour et icônes
des onglets. Écrit des TGA 32 bits dans DernierRempart/Media (le jeu lit les TGA).

Usage : python3 tools/media/make_media.py   (depuis la racine du dépôt)
Nécessite Pillow. Les TGA produits sont gardés dans le dépôt : ce script n'est
utile que pour les retoucher.
"""
import math
import os
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


def dgrad(w, h, c1, c2):
    """Dégradé en diagonale (haut gauche -> bas droite)."""
    img = Image.new("RGBA", (w, h))
    px = img.load()
    a, b = rgb(c1), rgb(c2)
    for y in range(h):
        for x in range(w):
            k = (x + y) / (w + h - 2)
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)) + (255,)
    return img


def rgrad(w, h, inner, outer, cx=0.4, cy=0.3):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    a, b = rgb(inner), rgb(outer)
    mx = math.hypot(max(cx, 1 - cx) * w, max(cy, 1 - cy) * h)
    for y in range(h):
        for x in range(w):
            k = min(1, math.hypot(x - cx * w, y - cy * h) / mx)
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)) + (255,)
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


def tower(base, ox, oy, k, navy="0E1D40"):
    """La tour du blason, dans une boîte de 34 x 38 posée en (ox, oy), à l'échelle k."""
    g = vgrad(base.width, base.height, *GOLD)
    dark = (0x5A, 0x3A, 0x0C, 255)

    def box(x, y, w, h):
        return [s(ox + x * k), s(oy + y * k), s(ox + (x + w) * k) - 1, s(oy + (y + h) * k) - 1]

    def shapes(d):
        for r in ((7, 4, 5, 7), (14.5, 4, 5, 7), (22, 4, 5, 7), (7, 11, 20, 21), (3, 31, 28, 5)):
            d.rectangle(box(*r), fill=255)
    fill(base, g, shapes)
    d = ImageDraw.Draw(base)
    for r in ((7, 4, 5, 7), (14.5, 4, 5, 7), (22, 4, 5, 7), (7, 11, 20, 21), (3, 31, 28, 5)):
        d.rectangle(box(*r), outline=dark, width=max(1, s(0.9 * k)))
    nv = rgb(navy) + (255,)
    d.rectangle(box(14, 26, 6, 5), fill=nv)
    d.pieslice([s(ox + 14 * k), s(oy + 20 * k), s(ox + 20 * k), s(oy + 26 * k)], 180, 360, fill=nv)
    d.rectangle(box(10, 15, 3, 6), fill=nv)
    d.rectangle(box(21, 15, 3, 6), fill=nv)


def medallion(n=128):
    img = canvas(n)
    W = img.width
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, W - 1, W - 1], fill=(0, 0, 0, 255))
    ring = dgrad(W, W, "F6DC9A", "5A3C14")
    fill(img, ring, lambda m: m.ellipse([s(1.5), s(1.5), W - s(1.5) - 1, W - s(1.5) - 1], fill=255))
    # filets du bronze
    d = ImageDraw.Draw(img)
    d.ellipse([s(5), s(5), W - s(5) - 1, W - s(5) - 1], outline=(0x4B, 0x32, 0x13, 255), width=s(1.2))
    d.ellipse([s(9), s(9), W - s(9) - 1, W - s(9) - 1], fill=(0, 0, 0, 255))
    disc = rgrad(W, W, "2D4F90", "0A1430", 0.4, 0.3)
    fill(img, disc, lambda m: m.ellipse([s(10.5), s(10.5), W - s(10.5) - 1, W - s(10.5) - 1], fill=255))
    # ombre intérieure
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.ellipse([s(10.5), s(10.5), W - s(10.5) - 1, W - s(10.5) - 1], outline=(0, 0, 0, 120), width=s(3))
    img = Image.alpha_composite(img, shade)
    k = 2.1
    tower(img, (n - 34 * k) / 2, (n - 38 * k) / 2 + 1, k)
    save(finish(img, n), "medaillon")


def tower_icon(n=64):
    img = canvas(n)
    tower(img, (n - 34 * 1.5) / 2, (n - 38 * 1.5) / 2, 1.5)
    save(finish(img, n), "tour")


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
    names = ["medaillon", "tour", "tab_sorties", "tab_artisans", "tab_presents", "tab_effort", "tab_officiers", "croix", "coche"]
    sheet = Image.new("RGBA", (len(names) * 140, 140), (30, 24, 18, 255))
    for i, nme in enumerate(names):
        im = Image.open(os.path.join(OUT, nme + ".tga")).convert("RGBA")
        sheet.alpha_composite(im, (i * 140 + 6, 6))
    return sheet


if __name__ == "__main__":
    medallion(128)
    tower_icon(64)
    icon_calendar()
    icon_anvil()
    icon_people()
    icon_coins()
    icon_shield()
    croix(32)
    coche(32)
    sheet = contact_sheet()
    sheet.save(os.environ.get("CONTACT", "/tmp/contact.png"))
