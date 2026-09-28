import { computeOpenState, DayHours, localTime } from './hours';
import { DEFAULT_VENUE } from './venue.service';

const TZ = 'Europe/Moscow';
// Время в МСК (UTC+3) → Date
const msk = (iso: string) => new Date(`${iso}+03:00`);

describe('localTime', () => {
  it('переводит в московское время', () => {
    // 2026-09-28 — понедельник
    expect(localTime(new Date('2026-09-28T05:30:00Z'), TZ)).toEqual({ day: 1, minutes: 8 * 60 + 30 });
  });
});

describe('computeOpenState — часы History Coffee', () => {
  const hours = DEFAULT_VENUE.hours;

  it('понедельник 08:00 — открыто до 23:00', () => {
    expect(computeOpenState(hours, msk('2026-09-28T08:00:00'), TZ)).toEqual({ isOpen: true, closesAt: '23:00', nextOpen: null });
  });

  it('понедельник 07:59 — закрыто, откроется в 08:00 сегодня', () => {
    expect(computeOpenState(hours, msk('2026-09-28T07:59:00'), TZ)).toEqual({
      isOpen: false,
      closesAt: null,
      nextOpen: { day: 1, time: '08:00' },
    });
  });

  it('пятница 23:00 — закрыто, суббота откроется в 09:00', () => {
    expect(computeOpenState(hours, msk('2026-10-02T23:00:00'), TZ)).toEqual({
      isOpen: false,
      closesAt: null,
      nextOpen: { day: 6, time: '09:00' },
    });
  });

  it('воскресенье 08:30 — ещё закрыто (выходные с 09:00)', () => {
    expect(computeOpenState(hours, msk('2026-10-04T08:30:00'), TZ).isOpen).toBe(false);
  });

  it('воскресенье 23:30 — следующее открытие в понедельник 08:00', () => {
    expect(computeOpenState(hours, msk('2026-10-04T23:30:00'), TZ).nextOpen).toEqual({ day: 1, time: '08:00' });
  });
});

describe('computeOpenState — ночные смены и выходные', () => {
  const hours: DayHours[] = [
    { day: 1, open: null, close: null },
    { day: 2, open: '18:00', close: '02:00' },
    { day: 3, open: '10:00', close: '20:00' },
    { day: 4, open: null, close: null },
    { day: 5, open: null, close: null },
    { day: 6, open: null, close: null },
    { day: 7, open: null, close: null },
  ];

  it('среда 01:00 — открыто по хвосту вторника', () => {
    expect(computeOpenState(hours, msk('2026-09-30T01:00:00'), TZ)).toEqual({ isOpen: true, closesAt: '02:00', nextOpen: null });
  });

  it('среда 03:00 — закрыто, откроется в 10:00', () => {
    expect(computeOpenState(hours, msk('2026-09-30T03:00:00'), TZ).nextOpen).toEqual({ day: 3, time: '10:00' });
  });

  it('понедельник (выходной) — ближайшее открытие во вторник', () => {
    expect(computeOpenState(hours, msk('2026-09-28T12:00:00'), TZ).nextOpen).toEqual({ day: 2, time: '18:00' });
  });
});
