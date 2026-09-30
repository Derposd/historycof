"""Пути логотипа из docs/brand/logo.svg → код приложения и админки.

Запуск: python3 tools/brand/make-code.py
Пишет mobile/lib/core/widgets/brand_paths.dart и admin/src/components/brandPaths.ts.
"""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[2]
svg = (root / 'docs/brand/logo.svg').read_text()
get = lambda i: re.search(rf'id="{i}" d="([^"]+)"', svg).group(1)
ring = re.search(r'id="ring"[^>]*r="([\d.]+)"[^>]*stroke-width="([\d.]+)"', svg)
parts = {'h': get('h'), 'feather': get('feather'), 's': get('s')}
note = 'Сгенерировано tools/brand/make-code.py из docs/brand/logo.svg — не править вручную.'

dart = [f'// {note}', '// Логотип History Coffee в системе координат 0..100 (центр 50,50).', '',
        f'const brandRingRadius = {ring.group(1)};', f'const brandRingWidth = {ring.group(2)};', '']
for k, v in parts.items():
    name = {'h': 'brandPathH', 'feather': 'brandPathFeather', 's': 'brandPathS'}[k]
    dart.append(f"const {name} = '{v}';")
(root / 'mobile/lib/core/widgets/brand_paths.dart').write_text('\n'.join(dart) + '\n')

ts = [f'// {note}', '// Логотип History Coffee в системе координат 0..100 (центр 50,50).', '',
      f'export const BRAND_RING = {{ r: {ring.group(1)}, width: {ring.group(2)} }}', '']
for k, v in parts.items():
    ts.append(f"export const BRAND_{k.upper()} = '{v}'")
(root / 'admin/src/components/brandPaths.ts').write_text('\n'.join(ts) + '\n')
print('ok')
