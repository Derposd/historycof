import { useEffect, useRef, useState, useSyncExternalStore } from 'react'

/** Пользователь попросил систему убрать анимации. */
export const reducedMotion = () =>
  typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches

/**
 * Число «набегает» от предыдущего значения к новому (плавное замедление в конце).
 * Первый показ — от нуля, как на приборной панели.
 */
export function useCountUp(value: number, duration = 900) {
  const [shown, setShown] = useState(0)
  const from = useRef(0)

  useEffect(() => {
    if (reducedMotion()) return
    const start = performance.now()
    const a = from.current
    let raf = 0
    // Время берём из performance.now(), а не из аргумента rAF: метка кадра бывает
    // раньше момента старта, и тогда прогресс уходил бы в минус (числа «−1»).
    const tick = () => {
      const t = Math.min(1, Math.max(0, (performance.now() - start) / duration))
      const eased = 1 - Math.pow(1 - t, 3)
      const v = Math.round(a + (value - a) * eased)
      setShown(v)
      from.current = v
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [value, duration])

  // Без анимаций — сразу итоговое число
  return reducedMotion() ? value : shown
}

// ── Всплывающие уведомления ──

export interface Toast {
  id: number
  text: string
  kind: 'ok' | 'error'
  leaving?: boolean
}

let toasts: Toast[] = []
let nextId = 1
const listeners = new Set<() => void>()
const emit = () => listeners.forEach((l) => l())

/** Короткое уведомление внизу экрана: «Сохранено», «Опубликовано»… */
export function toast(text: string, kind: Toast['kind'] = 'ok') {
  const id = nextId++
  toasts = [...toasts.slice(-2), { id, text, kind }]
  emit()
  setTimeout(() => dismiss(id), kind === 'error' ? 5200 : 2600)
}

export function dismiss(id: number) {
  if (!toasts.some((t) => t.id === id && !t.leaving)) return
  toasts = toasts.map((t) => (t.id === id ? { ...t, leaving: true } : t))
  emit()
  // Даём уходу доиграть, потом убираем из списка
  setTimeout(() => {
    toasts = toasts.filter((t) => t.id !== id)
    emit()
  }, 260)
}

export function useToasts() {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l)
      return () => listeners.delete(l)
    },
    () => toasts,
  )
}

/** Заголовок вкладки браузера: «Обращения · History Coffee». */
export function usePageTitle(title: string) {
  useEffect(() => {
    document.title = `${title} · History Coffee`
  }, [title])
}
