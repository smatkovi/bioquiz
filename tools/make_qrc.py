#!/usr/bin/env python3
"""Schreibt bioquiz.qrc: QML, freie Ersatzgrafiken, Squircles, Kacheln, Icon.

Der Fragenkatalog, die Bilder, die Nokia-Grafiken und Nokia Pure stehen nicht
darin; sie liegen im Datenordner neben der App (data/), weil sie groß sind
bzw. nur privat weitergegeben werden.

Aufruf: make_qrc.py <projektwurzel>
"""
import os
import sys

ENTRIES = [
    # (Präfix, Ordner im Projekt, Dateiendungen)
    ('qml', 'qml', ('.qml', 'qmldir')),
    ('harmattan-free', 'assets/harmattan-free', ('.png',)),
    ('ui', 'assets/ui', ('.png',)),
    ('cat', 'assets/cat', ('.png',)),
    ('appicon', 'assets/appicon', ('bioquiz-128.png', 'bioquiz-172.png', 'bioquiz-256.png')),
]


def main():
    root = sys.argv[1]
    lines = ['<!DOCTYPE RCC>', '<RCC version="1.0">']
    for prefix, folder, endings in ENTRIES:
        path = os.path.join(root, folder)
        if not os.path.isdir(path):
            continue
        lines.append(f'  <qresource prefix="/{prefix}">')
        for dirpath, _, files in sorted(os.walk(path)):
            for name in sorted(files):
                if not name.endswith(endings):
                    continue
                full = os.path.relpath(os.path.join(dirpath, name), root)
                alias = os.path.relpath(os.path.join(dirpath, name), path)
                lines.append(f'    <file alias="{alias}">{full}</file>')
        lines.append('  </qresource>')
    lines.append('</RCC>')
    with open(os.path.join(root, 'bioquiz.qrc'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print('bioquiz.qrc:', sum(1 for l in lines if '<file' in l), 'Dateien')


if __name__ == '__main__':
    main()
