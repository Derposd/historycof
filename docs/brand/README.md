# Логотип History Coffee

- `logo.svg` — знак кофейни (зелёное кольцо, H · перо · S) в системе координат 0..100.
  Векторизован по картинке от заказчика (`logo-source.jpg`). Логотип принадлежит кофейне
  History Coffee и используется в приложении с её согласия; это не открытый ресурс.
- Цвета: зелёный `#5E6D50`, светлый круг `#EAE9E5`.
- `store-icon-512.png` — иконка для Google Play / App Store.

Когда заказчик передаст оригинал в векторе — заменить пути в `logo.svg` (id `ring`, `h`,
`feather`, `s` оставить) и пересобрать:

```bash
python3 tools/brand/make-code.py                          # пути → приложение и админка
cd backend && npm ci && node ../tools/brand/make-icons.cjs # иконки Android/iOS, favicon
```
