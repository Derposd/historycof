import { excerpt } from './news.service';

describe('excerpt', () => {
  it('короткий текст без изменений', () => {
    expect(excerpt('Новый  десерт\nуже в витрине', 140)).toBe('Новый десерт уже в витрине');
  });

  it('обрезает по слову и ставит многоточие', () => {
    const text = 'Сегодня в History Coffee появился новый авторский десерт с историей про бабушкин сад';
    const out = excerpt(text, 40);
    expect(out.length).toBeLessThanOrEqual(40);
    expect(out.endsWith('…')).toBe(true);
    expect(out).toBe('Сегодня в History Coffee появился новый…');
  });
});
