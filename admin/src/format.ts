import { ApiError } from './api'

export function formatDate(iso: string | null | undefined, withTime = true): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('ru-RU', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    ...(withTime ? { hour: '2-digit', minute: '2-digit' } : {}),
    timeZone: 'Europe/Moscow',
  })
}

export function formatPhone(e164: string | null | undefined): string {
  if (!e164) return '—'
  const d = e164.replace(/\D/g, '')
  if (d.length !== 11) return e164
  return `+7 (${d.slice(1, 4)}) ${d.slice(4, 7)}-${d.slice(7, 9)}-${d.slice(9, 11)}`
}

export function errorText(e: unknown): string {
  return e instanceof ApiError ? e.message : 'Что-то пошло не так'
}

const mskDay = (d: Date) => d.toLocaleDateString('en-CA', { timeZone: 'Europe/Moscow' })
/** Время по Москве: «08:25». */
export const mskTime = (d: Date) => d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Moscow' })

/** День по Москве для подписей в переписке: «30 сентября». */
export const mskDayLabel = (iso: string) =>
  new Date(iso).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', timeZone: 'Europe/Moscow' })

/** Время по-человечески: «сегодня, 08:25», «вчера, 21:10», «28 сент., 08:25», «3 мар. 2025». */
export function formatWhen(iso: string | null | undefined): string {
  if (!iso) return '—'
  const d = new Date(iso)
  const now = new Date()
  const day = mskDay(d)
  if (day === mskDay(now)) return `сегодня, ${mskTime(d)}`
  if (day === mskDay(new Date(now.getTime() - 86400_000))) return `вчера, ${mskTime(d)}`
  const sameYear = day.slice(0, 4) === mskDay(now).slice(0, 4)
  const date = d.toLocaleDateString('ru-RU', {
    day: 'numeric',
    month: 'short',
    ...(sameYear ? {} : { year: 'numeric' }),
    timeZone: 'Europe/Moscow',
  })
  return sameYear ? `${date}, ${mskTime(d)}` : date
}
