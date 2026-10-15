#!/usr/bin/env python3
"""App-Icon und Kategorie-Kacheln im Harmattan-Stil.

Silhouette: Superellipse |x|^2.8 + |y|^2.8 = 1 mit Radius 0.4875 der Kante,
angepasst an den Alphakanal von blanco/icon-l-calculator.png (größte
Abweichung 0,17 Pixel bei 80 px). So bleibt die Form in jeder Größe scharf,
statt eine 80-px-Maske hochzuziehen.

Füllung wie bei den Stock-Icons: senkrechter Verlauf (oben heller), weißes
Symbol mit leichtem Verlauf und weichem Schatten.

Aufruf: make_icons.py <projektwurzel>
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

N, R = 2.8, 0.4875
SS = 4  # Überabtastung der Kante


def squircle_mask(size):
    s = size * SS
    c = (s - 1) / 2.0
    yy, xx = np.mgrid[0:s, 0:s]
    r = R * s
    m = ((np.abs(xx - c) / r) ** N + (np.abs(yy - c) / r) ** N <= 1).astype(np.float32)
    m = m.reshape(size, SS, size, SS).mean(axis=(1, 3))
    return Image.fromarray((m * 255).astype(np.uint8), 'L')


def hex_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(rgb, f):
    """f > 0 heller (Richtung Weiß), f < 0 dunkler."""
    if f >= 0:
        return tuple(int(c + (255 - c) * f) for c in rgb)
    return tuple(int(c * (1 + f)) for c in rgb)


def gradient(size, top, bottom):
    t = np.linspace(0, 1, size, dtype=np.float32)[:, None, None]
    a = np.array(top, np.float32)[None, None, :]
    b = np.array(bottom, np.float32)[None, None, :]
    g = a + (b - a) * t
    return Image.fromarray(np.repeat(g, size, axis=1).astype(np.uint8), 'RGB')


def svg_alpha(svg, px):
    """Material-Symbol als Alphamaske in px x px."""
    with tempfile.NamedTemporaryFile(suffix='.png') as tmp:
        subprocess.run(['rsvg-convert', '-w', str(px), '-h', str(px), '-o', tmp.name, svg], check=True)
        im = Image.open(tmp.name).convert('RGBA')
        im.load()
    return im.getchannel('A')


def glyph_layer(size, alpha, scale=0.58, dy=0.0):
    """Weißes Symbol mit Schatten, mittig auf size x size."""
    g = int(size * scale)
    alpha = alpha.resize((g, g), Image.LANCZOS)
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ox = (size - g) // 2
    oy = int((size - g) / 2 + dy * size)
    sh = Image.new('L', (size, size), 0)
    sh.paste(alpha, (ox, oy + max(1, size // 60)))
    sh = sh.filter(ImageFilter.GaussianBlur(max(1, size / 90)))
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow.putalpha(sh.point(lambda v: int(v * 0.40)))
    layer = Image.alpha_composite(layer, shadow)
    fill = gradient(size, (255, 255, 255), (226, 228, 230)).convert('RGBA')
    m = Image.new('L', (size, size), 0)
    m.paste(alpha, (ox, oy))
    fill.putalpha(m)
    return Image.alpha_composite(layer, fill)


def tile(size, color, glyph_alpha, square=False, scale=0.58, dy=0.0):
    base = hex_rgb(color)
    bg = gradient(size, shade(base, 0.22), shade(base, -0.22)).convert('RGBA')
    # weicher Glanz oben, wie bei den Stock-Icons
    hi = Image.new('L', (size, size), 0)
    ImageDraw.Draw(hi).ellipse([-size * 0.3, -size * 0.75, size * 1.3, size * 0.42], fill=40)
    hi = hi.filter(ImageFilter.GaussianBlur(size / 18))
    white = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    white.putalpha(hi)
    bg = Image.alpha_composite(bg, white)
    img = Image.alpha_composite(bg, glyph_layer(size, glyph_alpha, scale, dy))
    if not square:
        img.putalpha(squircle_mask(size))
    return img


def app_glyph(px, root):
    """Blatt mit Fragezeichen: weißes Blatt, das Fragezeichen ausgespart."""
    leaf = svg_alpha(os.path.join(root, 'assets/icons-src/eco.svg'), px)
    # Blattader schließen (Closing), damit nur das Fragezeichen ausgespart ist
    k = int(px * 0.045) | 1
    leaf = leaf.filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.MinFilter(k))
    font_path = os.path.expanduser('~/.local/share/fonts/NokiaPure/NokiaPureText_Bd.ttf')
    q = Image.new('L', (px, px), 0)
    d = ImageDraw.Draw(q)
    font = ImageFont.truetype(font_path, int(px * 0.46))
    box = d.textbbox((0, 0), '?', font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    cx, cy = px * 0.555, px * 0.45
    d.text((cx - w / 2 - box[0], cy - h / 2 - box[1]), '?', font=font, fill=255)
    a = np.asarray(leaf, np.float32) - np.asarray(q, np.float32)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'L')


def flat_squircle(size, top, bottom):
    img = gradient(size, hex_rgb(top), hex_rgb(bottom)).convert('RGBA')
    img.putalpha(squircle_mask(size))
    return img


# Squircles der Oberfläche, wie im harmattan-openbox-Theme: blaues Squircle
# für gedrückte Werkzeugknöpfe (Nokia-Verlauf #268CE0 -> #1080DD), dazu
# Avatare und die Ergebnis-Kästchen in derselben Form.
UI_SQUIRCLES = {
    'squircle-highlight': ('#268CE0', '#1080DD'),
    'squircle-right': ('#7ACC1A', '#4E9600'),
    'squircle-wrong': ('#F68372', '#F02B0E'),
    'squircle-empty': ('#3A3A3A', '#2E2E2E'),
    'squircle-hidden': ('#5C5C5C', '#4A4A4A'),
}
AVATAR_COLORS = ['#1080DD', '#EF5500', '#62B700', '#CC09BA', '#09A7CC', '#ED9507', '#821DDE', '#DA201E']


def ui_squircles(root):
    out = os.path.join(root, 'assets/ui')
    os.makedirs(out, exist_ok=True)
    for name, (top, bottom) in UI_SQUIRCLES.items():
        flat_squircle(128, top, bottom).save(os.path.join(out, name + '.png'))
    for i, c in enumerate(AVATAR_COLORS):
        base = hex_rgb(c)
        top = '#%02x%02x%02x' % shade(base, 0.18)
        bottom = '#%02x%02x%02x' % shade(base, -0.15)
        flat_squircle(128, top, bottom).save(os.path.join(out, f'avatar-{i}.png'))


def main():
    root = sys.argv[1]
    ui_squircles(root)
    cats = json.load(open(os.path.join(root, 'content/categories.json')))
    out_cat = os.path.join(root, 'assets/cat')
    os.makedirs(out_cat, exist_ok=True)
    for c in cats:
        a = svg_alpha(os.path.join(root, 'assets/icons-src', c['icon'] + '.svg'), 512)
        tile(256, c['color'], a).save(os.path.join(out_cat, c['key'] + '.png'))
    green = '#4DA30A'
    glyph = app_glyph(1024, root)
    big = tile(1024, green, glyph, scale=0.70)
    out = os.path.join(root, 'assets/appicon')
    os.makedirs(out, exist_ok=True)
    for s in (86, 108, 128, 172, 256, 48, 72, 96, 144, 192, 512, 80, 64):
        big.resize((s, s), Image.LANCZOS).save(os.path.join(out, f'bioquiz-{s}.png'))
    # iOS will ein randloses, deckendes Quadrat; die Ecken schneidet iOS selbst
    ios = tile(1024, green, glyph, square=True, scale=0.70).convert('RGB')
    ios.save(os.path.join(out, 'bioquiz-ios-1024.png'))
    ios_dir = os.path.join(root, 'ios/icons')
    os.makedirs(ios_dir, exist_ok=True)
    for name, px in (('AppIcon60x60@2x', 120), ('AppIcon60x60@3x', 180), ('AppIcon76x76@2x', 152),
                     ('AppIcon83.5x83.5@2x', 167), ('AppIcon76x76', 76)):
        ios.resize((px, px), Image.LANCZOS).save(os.path.join(ios_dir, name + '.png'))
    # macOS: das Squircle mit etwas Rand, wie die Dock-Symbole
    pad = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    inner = big.resize((824, 824), Image.LANCZOS)
    pad.paste(inner, (100, 100), inner)
    pad.save(os.path.join(root, 'macos/bioquiz.icns'),
             sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
    print('fertig:', len(cats), 'Kacheln, App-Icon in', out)


if __name__ == '__main__':
    main()
