/** День недели ISO: 1 — понедельник … 7 — воскресенье. */
export type IsoWeekday = 1 | 2 | 3 | 4 | 5 | 6 | 7;

export interface DayHours {
  day: IsoWeekday;
  /** «08:00». null — выходной. */
  open: string | null;
  /** «23:00». Может быть меньше open — работа после полуночи. */
  close: string | null;
}

export interface OpenState {
  isOpen: boolean;
  /** Если открыто — во сколько закроется (HH:MM). */
  closesAt: string | null;
  /** Если закрыто — ближайшее открытие. */
  nextOpen: { day: IsoWeekday; time: string } | null;
}

const toMinutes = (hhmm: string): number => {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
};

/** Локальные день недели и минуты от полуночи в указанной таймзоне. */
export function localTime(now: Date, timeZone: string): { day: IsoWeekday; minutes: number } {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '';
  const days: Record<string, IsoWeekday> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
  return { day: days[get('weekday')], minutes: Number(get('hour')) * 60 + Number(get('minute')) };
}

const prevDay = (d: IsoWeekday): IsoWeekday => (d === 1 ? 7 : ((d - 1) as IsoWeekday));
const nextDay = (d: IsoWeekday): IsoWeekday => (d === 7 ? 1 : ((d + 1) as IsoWeekday));

export function computeOpenState(hours: DayHours[], now: Date, timeZone: string): OpenState {
  const byDay = new Map(hours.map((h) => [h.day, h]));
  const { day, minutes } = localTime(now, timeZone);

  // Хвост вчерашней смены после полуночи (например, 18:00–02:00).
  const y = byDay.get(prevDay(day));
  if (y?.open && y.close && toMinutes(y.close) < toMinutes(y.open) && minutes < toMinutes(y.close)) {
    return { isOpen: true, closesAt: y.close, nextOpen: null };
  }

  const t = byDay.get(day);
  if (t?.open && t.close) {
    const o = toMinutes(t.open);
    const c = toMinutes(t.close);
    const overnight = c < o;
    if (minutes >= o && (overnight || minutes < c)) {
      return { isOpen: true, closesAt: t.close, nextOpen: null };
    }
    if (minutes < o) return { isOpen: false, closesAt: null, nextOpen: { day, time: t.open } };
  }

  let d = nextDay(day);
  for (let i = 0; i < 7; i++, d = nextDay(d)) {
    const h = byDay.get(d);
    if (h?.open && h.close) return { isOpen: false, closesAt: null, nextOpen: { day: d, time: h.open } };
  }
  return { isOpen: false, closesAt: null, nextOpen: null };
}
