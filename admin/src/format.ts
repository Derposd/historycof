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
