// Фирменный диалог подтверждения — состояние и функции (окно рисует components/Ask.tsx).

/** Вариант ответа в диалоге. kind: primary — основная кнопка, danger — опасное действие. */
export interface AskAction<T> {
  label: string
  value: T
  kind?: 'primary' | 'danger' | 'ghost'
}

interface AskState {
  title: string
  text?: string
  actions: AskAction<unknown>[]
  resolve: (v: unknown) => void
  leaving?: boolean
}

let current: AskState | null = null
const listeners = new Set<() => void>()
const emit = () => listeners.forEach((l) => l())

/**
 * Фирменный диалог вместо системного confirm(): вопрос и несколько вариантов ответа.
 * Возвращает value выбранной кнопки или null, если диалог закрыли (Esc, фон, «Отмена»).
 */
export function ask<T>(opts: { title: string; text?: string; actions: AskAction<T>[] }): Promise<T | null> {
  return new Promise((resolve) => {
    current?.resolve(null)
    current = { ...opts, resolve: resolve as (v: unknown) => void } as AskState
    emit()
  })
}

/** Короткая форма для «Удалить? — Удалить / Отмена». */
export async function confirmDanger(title: string, text: string, label = 'Удалить') {
  return (await ask({ title, text, actions: [{ label, value: true, kind: 'danger' }] })) === true
}

export function finish(value: unknown) {
  if (!current || current.leaving) return
  const s = current
  current = { ...s, leaving: true }
  emit()
  setTimeout(() => {
    current = null
    emit()
    s.resolve(value)
  }, 180)
}

export const subscribe = (l: () => void) => {
  listeners.add(l)
  return () => {
    listeners.delete(l)
  }
}
export const snapshot = () => current
