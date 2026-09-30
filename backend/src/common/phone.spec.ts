import { formatRuPhone, normalizeRuMobile, normalizeRuPhone } from './phone';

describe('normalizeRuPhone', () => {
  it.each([
    ['+7 (960) 431-62-23', '+79604316223'],
    ['8 960 431 62 23', '+79604316223'],
    ['9604316223', '+79604316223'],
    ['79604316223', '+79604316223'],
  ])('%s → %s', (input, expected) => {
    expect(normalizeRuPhone(input)).toBe(expected);
  });

  it.each(['', '123', '+1 555 123 4567', '+7 960 431 62 2', null, undefined])('отклоняет %p', (input) => {
    expect(normalizeRuPhone(input)).toBeNull();
  });

  it('форматирует для показа', () => {
    expect(formatRuPhone('+79604316223')).toBe('+7 (960) 431-62-23');
  });
});

describe('normalizeRuMobile — вход только по российскому мобильному', () => {
  it.each([
    ['+7 (960) 431-62-23', '+79604316223'],
    ['89001112233', '+79001112233'],
  ])('%s → %s', (input, expected) => {
    expect(normalizeRuMobile(input)).toBe(expected);
  });

  it.each(['+7 701 123-45-67', '+7 495 123-45-67', '+375291234567'])('%s — не российский мобильный', (input) => {
    expect(normalizeRuMobile(input)).toBeNull();
  });
});
