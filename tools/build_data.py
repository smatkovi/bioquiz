#!/usr/bin/env python3
"""Baut den Fragenkatalog der App aus den Agenten-Fragen.

Liest content/questions/<buch>/part-*.json, prüft und bereinigt die Fragen und
schreibt data/bioquiz.json. Die Bilder der Bildfragen werden aus dem
Aufbereitungsordner (--figs <ordner>) nach data/figs/<buch>/<id>.webp übernommen, auf höchstens
900 px verkleinert und als WebP (Qualität 80) gespeichert: etwa ein Drittel
kleiner als JPEG bei gleichem Eindruck. Qt liest es über qtimageformats.

Aufruf:
  build_data.py <projektwurzel> --figs <ordner mit <buch>/figs/>   (voll)
  build_data.py <projektwurzel> --demo                           (ohne Buchinhalte)
"""
import argparse
import glob
import hashlib
import json
import os
import re
import sys
import unicodedata

LEVELS = [
    {'key': '5',  'name': '5. Schulstufe',  'sub': '1. Klasse MS/AHS'},
    {'key': '6',  'name': '6. Schulstufe',  'sub': '2. Klasse MS/AHS'},
    {'key': '7',  'name': '7. Schulstufe',  'sub': '3. Klasse MS/AHS'},
    {'key': '8',  'name': '8. Schulstufe',  'sub': '4. Klasse MS/AHS'},
    {'key': '9',  'name': '9. Schulstufe',  'sub': '5. Klasse AHS'},
    {'key': '10', 'name': '10. Schulstufe', 'sub': '6. Klasse AHS'},
    {'key': '11', 'name': '11. Schulstufe', 'sub': '7. Klasse AHS'},
    {'key': '12', 'name': '12. Schulstufe', 'sub': '8. Klasse AHS'},
    {'key': 'bs', 'name': 'Berufsschule',   'sub': 'Lebensmittel-Warenkunde'},
    {'key': 'demo', 'name': 'Beispielfragen', 'sub': 'öffentliche Testfassung ohne Buchinhalte'},
]
MAX_Q, MAX_A = 160, 60


def norm(text):
    t = unicodedata.normalize('NFKC', text).lower()
    return re.sub(r'[^a-zäöüß0-9]+', ' ', t).strip()


def clean(text):
    t = unicodedata.normalize('NFC', str(text)).strip()
    t = re.sub(r'\s+', ' ', t)
    return t


def load_book(root, book, cats, problems):
    out = []
    for part in sorted(glob.glob(os.path.join(root, 'content/questions', book, 'part-*.json'))):
        try:
            items = json.load(open(part, encoding='utf-8'))
        except ValueError as e:
            problems.append(f'{part}: kein gültiges JSON ({e})')
            continue
        for n, q in enumerate(items):
            where = f'{os.path.basename(part)}#{n}'
            try:
                text = clean(q['q'])
                answers = [clean(a) for a in q['a']]
                cat = q['cat']
            except (KeyError, TypeError):
                problems.append(f'{book} {where}: Feld fehlt')
                continue
            if cat not in cats:
                problems.append(f'{book} {where}: Kategorie {cat!r} unbekannt')
                continue
            if len(answers) != 4 or len({norm(a) for a in answers}) != 4 or not all(answers):
                problems.append(f'{book} {where}: Antworten nicht 4 verschiedene')
                continue
            if len(text) > MAX_Q or max(len(a) for a in answers) > MAX_A:
                problems.append(f'{book} {where}: zu lang ({len(text)}/{max(len(a) for a in answers)})')
                continue
            out.append({'b': book, 'c': cat, 'q': text, 'a': answers,
                        'p': int(q.get('p') or 0), 'img': (q.get('img') or '').strip()})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('root')
    ap.add_argument('--figs', help='Ordner mit <buch>/figs/<id>.jpg')
    ap.add_argument('--demo', action='store_true', help='nur content/demo-questions.json')
    ap.add_argument('--out', help='Zielordner statt <projektwurzel>/data')
    args = ap.parse_args()
    root = args.root
    cats = json.load(open(os.path.join(root, 'content/categories.json'), encoding='utf-8'))
    cat_keys = {c['key'] for c in cats}
    # Doppelte Downloads (duplicateOf) und ältere Ausgaben einer Reihe
    # (supersededBy) bleiben draußen: je Reihe zählt nur die neueste Ausgabe.
    books_file = os.path.join(root, 'content/books.json')
    books = [b for b in (json.load(open(books_file, encoding='utf-8')) if os.path.exists(books_file) else [])
             if 'duplicateOf' not in b and 'supersededBy' not in b]
    data_dir = args.out or os.path.join(root, 'data')
    os.makedirs(data_dir, exist_ok=True)

    problems = []
    questions = []
    if args.demo:
        books = [{'id': 'demo', 'title': 'Beispielfragen', 'level': 'demo'}]
        for q in json.load(open(os.path.join(root, 'content/demo-questions.json'), encoding='utf-8')):
            questions.append({'b': 'demo', 'c': q['cat'], 'q': clean(q['q']),
                              'a': [clean(a) for a in q['a']], 'p': 0, 'img': ''})
    else:
        for b in books:
            questions += load_book(root, b['id'], cat_keys, problems)

    # Doppelte Fragen innerhalb einer Schulstufe entfernen (gleicher Wortlaut
    # und gleiche richtige Antwort, auch aus verschiedenen Büchern).
    level_of = {b['id']: b['level'] for b in books}
    seen = set()
    unique = []
    for q in questions:
        key = (level_of[q['b']], norm(q['q']), norm(q['a'][0]))
        if key in seen:
            continue
        seen.add(key)
        unique.append(q)
    dropped = len(questions) - len(unique)

    figs_out = os.path.join(data_dir, 'figs')
    result = []
    missing = 0
    for q in unique:
        h = hashlib.sha1(f"{q['b']}|{q['q']}|{q['a'][0]}".encode('utf-8')).hexdigest()[:10]
        item = {'id': h, 'b': q['b'], 'c': q['c'], 'q': q['q'], 'a': q['a'], 'p': q['p']}
        if q['img']:
            src = os.path.join(args.figs or '', q['b'], 'figs', q['img'] + '.jpg')
            rel = f"figs/{q['b']}/{q['img']}.webp"
            dst = os.path.join(data_dir, rel)
            if args.figs and os.path.exists(src):
                if not os.path.exists(dst):
                    from PIL import Image
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    im = Image.open(src).convert('RGB')
                    im.thumbnail((900, 900))
                    im.save(dst, 'WEBP', quality=80, method=6)
                item['i'] = rel
            elif os.path.exists(dst):
                item['i'] = rel
            else:
                missing += 1
                continue  # Bildfrage ohne Bild ergibt keinen Sinn
        result.append(item)

    # Bilder, die keine Frage mehr braucht (z. B. von ersetzten Ausgaben), entfernen
    used = {os.path.join(data_dir, q['i']) for q in result if 'i' in q}
    removed = 0
    for dirpath, _, files in os.walk(figs_out):
        for name in files:
            path = os.path.join(dirpath, name)
            if path not in used:
                os.remove(path)
                removed += 1
    for dirpath, dirs, files in sorted(os.walk(figs_out), reverse=True):
        if dirpath != figs_out and not os.listdir(dirpath):
            os.rmdir(dirpath)
    if removed:
        print(f'{removed} nicht mehr benutzte Bilder entfernt')

    # Private Teile des Datenordners: Nokias Harmattan-Grafiken und Nokia Pure.
    # Fehlen sie (öffentliches Repo), nimmt die App ihre freien Ersatzbilder.
    import shutil
    for name in ('harmattan', 'fonts'):
        src = os.path.join(root, 'assets', name)
        dst = os.path.join(data_dir, name)
        if os.path.isdir(dst):
            shutil.rmtree(dst)
        if os.path.isdir(src) and not args.demo:
            shutil.copytree(src, dst)

    version = hashlib.sha1(json.dumps(result, ensure_ascii=False, sort_keys=True).encode('utf-8')).hexdigest()[:12]
    used_levels = {level_of[q['b']] for q in result}
    catalog = {
        'version': version,
        'categories': [{'key': c['key'], 'name': c['name'], 'color': c['color']} for c in cats],
        'levels': [l for l in LEVELS if l['key'] in used_levels],
        'books': [{'id': b['id'], 'title': b['title'], 'level': b['level']} for b in books],
        'questions': result,
    }
    with open(os.path.join(data_dir, 'bioquiz.json'), 'w', encoding='utf-8') as f:
        json.dump(catalog, f, ensure_ascii=False, separators=(',', ':'))

    pictures = sum(1 for q in result if 'i' in q)
    print(f'{len(result)} Fragen ({pictures} mit Bild), {dropped} Doppelte entfernt, '
          f'{missing} Bildfragen ohne Bild verworfen, {len(problems)} Probleme, Version {version}')
    per_level = {}
    for q in result:
        per_level.setdefault(level_of[q['b']], 0)
        per_level[level_of[q['b']]] += 1
    print('je Stufe:', ', '.join(f'{k}: {v}' for k, v in sorted(per_level.items(), key=lambda kv: (len(kv[0]), kv[0]))))
    # Lage der richtigen Antwort im Quelltext soll immer 0 sein (die App mischt)
    for p in problems[:40]:
        print('  !', p, file=sys.stderr)


if __name__ == '__main__':
    main()
