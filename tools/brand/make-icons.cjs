// Иконки приложения и админки из единого логотипа docs/brand/logo.svg.
// Запуск (нужен sharp из backend):  cd backend && npm ci && node ../tools/brand/make-icons.cjs
const path = require('path');
const fs = require('fs');
const sharp = require(path.join(__dirname, '../../backend/node_modules/sharp'));

const root = path.join(__dirname, '../..');
const logo = fs.readFileSync(path.join(root, 'docs/brand/logo.svg'), 'utf8');
const get = (id) => logo.match(new RegExp(`id="${id}" d="([^"]+)"`))[1];
const GREEN = '#5E6D50';
const LIGHT = '#EAE9E5';
const RING = { r: 47.39, w: 5.21 };
const INNER = RING.r - RING.w / 2; // радиус светлого круга в системе 0..100
const glyphs = (fill = GREEN) =>
  `<g fill="${fill}" fill-rule="evenodd"><path d="${get('h')}"/><path d="${get('feather')}"/><path d="${get('s')}"/></g>`;
const fullLogo = () =>
  `<circle cx="50" cy="50" r="${RING.r}" fill="${LIGHT}" stroke="${GREEN}" stroke-width="${RING.w}"/>${glyphs()}`;
const svg = (px, view, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${px}" height="${px}" viewBox="0 0 ${view} ${view}">${body}</svg>`;
const png = (s, file) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  return sharp(Buffer.from(s)).png().toFile(file);
};

// Адаптивная иконка Android (слои 108dp, видно центральные 72dp):
// фон — зелёный бренда, передний план — светлый круг со знаком. Маска лаунчера
// оставляет вокруг круга зелёный ободок — получается сам логотип.
const k = 36 / 50; // логотип 0..100 → круг радиусом 36dp
const place = (body) => `<g transform="translate(${54 - 50 * k} ${54 - 50 * k}) scale(${k})">${body}</g>`;
const fg = (px) => svg(px, 108, place(`<circle cx="50" cy="50" r="${INNER}" fill="${LIGHT}"/>${glyphs()}`));
// Монохромный слой (тематические иконки Android 13+): только буквы и перо, крупнее
const km = 1.25;
const mono = (px) =>
  svg(px, 108, `<g transform="translate(${54 - 50 * k * km} ${54 - 50 * k * km}) scale(${k * km})">${glyphs('#000')}</g>`);
// Старые Android: круглая иконка целиком
const legacy = (px) => svg(px, 100, fullLogo());
// Сплэш: логотип целиком в поле 240dp (Android 12 показывает круг ∅160dp)
const splash = (px) => svg(px, 240, `<g transform="translate(45 45) scale(1.5)">${fullLogo()}</g>`);
// iOS и магазины: квадрат без прозрачности — зелёный фон и светлый круг со знаком
const square = (px) =>
  svg(px, 100, `<rect width="100" height="100" fill="${GREEN}"/><g transform="translate(4 4) scale(0.92)">${fullLogo()}</g>`);

(async () => {
  const res = path.join(root, 'mobile/android/app/src/main/res');
  const dens = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
  for (const [d, m] of Object.entries(dens)) {
    await png(legacy(Math.round(48 * m)), `${res}/mipmap-${d}/ic_launcher.png`);
    await png(fg(Math.round(108 * m)), `${res}/mipmap-${d}/ic_launcher_foreground.png`);
    await png(mono(Math.round(108 * m)), `${res}/mipmap-${d}/ic_launcher_monochrome.png`);
    await png(splash(Math.round(240 * m)), `${res}/drawable-${d}/splash_logo.png`);
  }
  // iOS
  const ios = path.join(root, 'mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset');
  const contents = JSON.parse(fs.readFileSync(`${ios}/Contents.json`, 'utf8'));
  for (const img of contents.images) {
    const [w] = img.size.split('x').map(Number);
    const scale = Number(img.scale.replace('x', ''));
    await png(square(Math.round(w * scale)), `${ios}/${img.filename}`);
  }
  // Магазины и админка
  await png(square(512), path.join(root, 'docs/brand/store-icon-512.png'));
  fs.writeFileSync(path.join(root, 'admin/public/favicon.svg'), svg(64, 100, fullLogo()));
  await png(legacy(180), path.join(root, 'admin/public/apple-touch-icon.png'));
  console.log('иконки обновлены');
})();
