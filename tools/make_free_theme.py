#!/usr/bin/env python3
"""Freie Ersatzgrafiken für die Harmattan-Bilder (öffentliches Repo).

Die Originale aus dem blanco-Theme gehören Nokia und bleiben privat. Dieses
Skript zeichnet Bilder mit denselben Namen und Größen nach: Knöpfe, Listen-
und Kopfleisten, Fortschrittsbalken, Eingabefeld, Werkzeugsymbole (Material
Symbols, Apache 2.0). Die App nimmt sie, wenn ihr Datenordner kein
harmattan/ enthält.

Aufruf: make_free_theme.py <projektwurzel>  -> assets/harmattan-free/
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_icons import gradient, hex_rgb, squircle_mask, svg_alpha, tile  # noqa: E402

SS = 4


def rounded(size, radius, corners=(True, True, True, True)):
    """Maske eines abgerundeten Rechtecks; corners = (lo, ro, ru, lu)."""
    w, h = size
    m = Image.new('L', (w * SS, h * SS), 0)
    d = ImageDraw.Draw(m)
    r = radius * SS
    d.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], r, fill=255, corners=corners)
    return m.resize((w, h), Image.LANCZOS)


def button(size, top, bottom, border=None, corners=(True, True, True, True), radius=12):
    w, h = size
    img = gradient(max(w, h), hex_rgb(top), hex_rgb(bottom)).resize((w, h)).convert('RGBA')
    if border:
        hl = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(hl)
        d.rounded_rectangle([0, 0, w - 1, h - 1], radius, outline=hex_rgb(border) + (200,), width=1, corners=corners)
        img = Image.alpha_composite(img, hl)
    img.putalpha(rounded((w, h), radius, corners))
    return img


BUTTONS = {
    '': ('#3C3C3C', '#1E1E1E', '#6A6A6A'),
    '-pressed': ('#13568F', '#0B3D69', '#2A7AC0'),
    '-selected': ('#2E93EA', '#1272C9', '#6FB6F2'),
    '-disabled': ('#222222', '#1A1A1A', '#333333'),
}
POSITIONS = {
    '': (True, True, True, True),
    '-horizontal-left': (True, False, False, True),
    '-horizontal-center': (False, False, False, False),
    '-horizontal-right': (False, True, True, False),
}


def white_icon(svg, px, canvas=None):
    canvas = canvas or px
    a = svg_alpha(svg, px)
    img = Image.new('RGBA', (canvas, canvas), (255, 255, 255, 0))
    layer = Image.new('RGBA', (px, px), (255, 255, 255, 255))
    layer.putalpha(a)
    img.paste(layer, ((canvas - px) // 2, (canvas - px) // 2), layer)
    return img


def main():
    root = sys.argv[1]
    out = os.path.join(root, 'assets/harmattan-free')
    src = os.path.join(root, 'assets/icons-src/ui')
    os.makedirs(out, exist_ok=True)

    def save(img, name):
        img.save(os.path.join(out, name + '.png'))

    for state, (top, bottom, border) in BUTTONS.items():
        for pos, corners in POSITIONS.items():
            if state == '-disabled' and pos:
                continue
            save(button((51, 51), top, bottom, border, corners), f'meegotouch-button-inverted-background{state}{pos}')
    save(button((51, 51), '#45A3F2', '#1A7FD8', '#7CC0F7'), 'meegotouch-button-accent-inverted-background')
    save(button((51, 51), '#1C6CB4', '#105394', '#3D8BD0'), 'meegotouch-button-accent-inverted-background-pressed')
    save(button((51, 51), '#2B4258', '#22364A', '#3A5470'), 'meegotouch-button-accent-inverted-background-disabled')
    save(button((51, 51), '#86CC4E', '#5EA82E', '#A6DD7A'), 'meegotouch-button-positive-inverted-background')
    save(button((51, 51), '#FF6B5B', '#E2392A', '#FF9A8E'), 'meegotouch-button-negative-inverted-background')

    save(gradient(67, hex_rgb('#1E6FB8'), hex_rgb('#14548E')).convert('RGBA'),
         'meegotouch-list-fullwidth-inverted-background-pressed')
    save(button((24, 10), '#2A2A2A', '#3A3A3A', '#444444', radius=5),
         'meegotouch-progressindicator-inverted-bar-background')
    save(gradient(9, hex_rgb('#4BA8F5'), hex_rgb('#1478D4')).resize((8, 9)).convert('RGBA'),
         'meegotouch-progressindicator-inverted-bar-known-texture')
    for name, color in (('on', (255, 255, 255, 255)), ('off', (110, 110, 110, 255))):
        dot = Image.new('RGBA', (40, 40), (0, 0, 0, 0))
        ImageDraw.Draw(dot).ellipse([2, 2, 37, 37], fill=color)
        save(dot.resize((10, 10), Image.LANCZOS), f'meegotouch-progressindicator-inverted-spinner-medium-{name}')
    line = Image.new('RGBA', (18, 2), hex_rgb('#3A3A3A') + (255,))
    save(line, 'meegotouch-separator-inverted-background-horizontal')
    save(line, 'meegotouch-groupheader-inverted-background')

    field = button((100, 52), '#F4F4F4', '#E2E2E2', '#B0B0B0', radius=10)
    save(field, 'meegotouch-textedit-inverted-background')
    field_sel = button((100, 52), '#FFFFFF', '#ECECEC', '#1080DD', radius=10)
    edge = Image.new('RGBA', (100, 52), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle([1, 1, 98, 50], 10, outline=(16, 128, 221, 255), width=2)
    save(Image.alpha_composite(field_sel, edge), 'meegotouch-textedit-inverted-background-selected')

    bar = gradient(72, hex_rgb('#1C1C1C'), hex_rgb('#050505')).resize((480, 72)).convert('RGBA')
    ImageDraw.Draw(bar).line([0, 0, 479, 0], fill=(60, 60, 60, 255))
    save(bar, 'meegotouch-toolbar-portrait-inverted-background')
    head = gradient(41, hex_rgb('#2C2C2C'), hex_rgb('#121212')).resize((480, 41)).convert('RGBA')
    ImageDraw.Draw(head).line([0, 40, 479, 40], fill=(70, 70, 70, 255))
    save(head, 'meegotouch-view-header-inverted')
    note = button((64, 64), '#2E2E2E', '#232323', '#4A4A4A', radius=10)
    save(note, 'meegotouch-notification-information-background')

    # Werkzeug- und Listensymbole
    for name, svg, px, canvas in (
        ('icon-m-toolbar-back-white', 'arrow_back', 34, 52),
        ('icon-m-toolbar-settings-white', 'settings', 30, 40),
        ('icon-m-toolbar-view-menu-white', 'menu', 30, 40),
        ('icon-m-toolbar-refresh-white', 'refresh', 30, 40),
        ('icon-m-toolbar-done-white', 'check', 30, 40),
        ('icon-m-toolbar-close-white', 'close', 30, 40),
        ('icon-m-toolbar-home-white', 'home', 30, 40),
        ('icon-m-toolbar-search-white', 'search', 30, 40),
        ('icon-m-toolbar-add-white', 'add', 30, 40),
        ('icon-m-common-drilldown-arrow-inverse', 'chevron_right', 30, 32),
    ):
        save(white_icon(os.path.join(src, svg + '.svg'), px, canvas), name)
    for name, svg, color in (
        ('icon-m-content-avatar-placeholder-inverse', 'person', '#3A3A3A'),
        ('icon-m-common-wlan-strength3', 'wifi', '#3A3A3A'),
        ('icon-m-common-wlan', 'wifi', '#3A3A3A'),
        ('icon-m-bluetooth-active', 'bluetooth', '#1080DD'),
        ('icon-m-framework-close-thumbnail', 'close', '#E8402E'),
    ):
        big = tile(256, color, svg_alpha(os.path.join(src, svg + '.svg'), 512), scale=0.6)
        save(big.resize((64, 64), Image.LANCZOS), name)
    print('freie Ersatzgrafiken:', len(os.listdir(out)), 'Dateien in', out)


if __name__ == '__main__':
    main()
