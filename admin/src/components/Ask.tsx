import { useEffect, useRef, useSyncExternalStore } from 'react'
import { finish, snapshot, subscribe } from '../ask'

export function AskHost() {
  const state = useSyncExternalStore(subscribe, snapshot)
  const firstBtn = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    if (!state || state.leaving) return
    firstBtn.current?.focus()
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopPropagation()
        finish(null)
      }
    }
    // capture: Esc закрывает только диалог, а не окно редактирования под ним
    document.addEventListener('keydown', onKey, true)
    return () => document.removeEventListener('keydown', onKey, true)
  }, [state])

  if (!state) return null
  return (
    <div className={`ask-backdrop${state.leaving ? ' closing' : ''}`} onMouseDown={(e) => e.target === e.currentTarget && finish(null)}>
      <div className="ask" role="alertdialog" aria-modal="true" aria-label={state.title}>
        <h3>{state.title}</h3>
        {state.text && <p className="muted">{state.text}</p>}
        <div className={`ask-actions${state.actions.length > 1 ? ' many' : ''}`}>
          <button type="button" className="ghost" onClick={() => finish(null)}>
            Отмена
          </button>
          {state.actions.map((a, i) => (
            <button
              key={a.label}
              ref={i === state.actions.length - 1 ? firstBtn : undefined}
              type="button"
              className={a.kind === 'danger' ? 'danger solid' : a.kind === 'ghost' ? 'ghost' : ''}
              onClick={() => finish(a.value)}
            >
              {a.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
