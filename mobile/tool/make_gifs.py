"""Склеивает кадры из tool/screens/motion/<сцена>-NNN.png в GIF (tool/screens/<сцена>.gif).

Запуск после tool/motion_test.dart:  python3 tool/make_gifs.py
Нужен Pillow (pip install pillow).
"""
import collections
import pathlib
import re

from PIL import Image

root = pathlib.Path(__file__).parent / 'screens'
frames = collections.defaultdict(list)
for f in sorted((root / 'motion').glob('*.png')):
    m = re.match(r'(.+)-(\d+)\.png$', f.name)
    if m:
        frames[m.group(1)].append(f)

for scene, files in frames.items():
    imgs = []
    for f in files:
        im = Image.open(f).convert('RGB')
        im = im.resize((300, round(im.height * 300 / im.width)), Image.LANCZOS)
        imgs.append(im.convert('P', palette=Image.ADAPTIVE, colors=224))
    out = root / f'{scene}.gif'
    imgs[0].save(out, save_all=True, append_images=imgs[1:], duration=50, loop=0, optimize=True)
    print(out, len(imgs), 'кадров')
