import { useCallback, useEffect, useRef, useState, type ButtonHTMLAttributes, type ReactNode } from 'react'
import { uploadImage } from '../api'
import { errorText } from '../format'
import { dismiss, reducedMotion, useCountUp, useToasts } from '../motion'
import { ask } from '../ask'

/**
 * Окно редактирования. Закрывается по ✕, фону, Esc и кнопкам с атрибутом data-close
 * (например, «Отмена»); если [dirty] — сначала спрашивает, не потерять ли изменения.
 */
export function Modal({
  title,
  onClose,
  children,
  dirty = false,
  wide = false,
}: {
  title: string
  onClose: () => void
  children: ReactNode
  dirty?: boolean
  wide?: boolean
}) {
  const [closing, setClosing] = useState(false)
  const close = useCallback(async () => {
    if (
      dirty &&
      !(await ask({
        title: 'Закрыть без сохранения?',
        text: 'Изменения в этом окне пропадут.',
        actions: [{ label: 'Закрыть', value: true, kind: 'danger' }],
      }))
    )
      return
    if (reducedMotion()) return onClose()
    setClosing(true)
    setTimeout(onClose, 220)
  }, [onClose, dirty])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && void close()
    document.addEventListener('keydown', onKey)
    // Страница под окном не прокручивается
    const overflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = overflow
    }
  }, [close])

  return (
    <div className={`modal-backdrop${closing ? ' closing' : ''}`} onMouseDown={(e) => e.target === e.currentTarget && void close()}>
      <div
        className={`modal${wide ? ' wide' : ''}`}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(e) => (e.target as HTMLElement).closest('[data-close]') && void close()}
      >
        <div className="row" style={{ marginBottom: 20 }}>
          <h2>{title}</h2>
          <span className="spacer" />
          {dirty && <span className="pill gold">Есть изменения</span>}
          <button type="button" className="ghost small icon-close" data-close aria-label="Закрыть">
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  )
}

/** Кнопка с состоянием «идёт сохранение»: крутилка и заблокирована. */
export function BusyButton({
  busy,
  children,
  className,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { busy?: boolean }) {
  return (
    <button {...rest} className={`${className ?? ''}${busy ? ' is-busy' : ''}`} disabled={busy || rest.disabled} aria-busy={busy}>
      {busy && <span className="spinner" aria-hidden="true" />}
      {children}
    </button>
  )
}

export function ImageField({
  value,
  onChange,
  folder,
}: {
  value: string | null
  onChange: (url: string | null) => void
  folder: 'news' | 'menu'
}) {
  const input = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)
  const [over, setOver] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function pick(file: File | undefined) {
    if (!file) return
    setBusy(true)
    setError(null)
    try {
      onChange(await uploadImage(file, folder))
    } catch (e) {
      setError(errorText(e))
    } finally {
      setBusy(false)
      if (input.current) input.current.value = ''
    }
  }

  return (
    <div className="stack" style={{ gap: 8 }}>
      {value ? (
        <div className="photo-preview">
          <img src={value} alt="" />
          <div className="row">
            <button type="button" className="ghost small" disabled={busy} onClick={() => input.current?.click()}>
              {busy ? 'Загрузка…' : 'Заменить'}
            </button>
            <button type="button" className="danger small" style={{ background: 'rgba(255,255,255,0.9)' }} onClick={() => onChange(null)}>
              Убрать
            </button>
          </div>
        </div>
      ) : (
        <div
          role="button"
          tabIndex={0}
          className={`dropzone${over ? ' over' : ''}`}
          onClick={() => input.current?.click()}
          onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && input.current?.click()}
          onDragOver={(e) => {
            e.preventDefault()
            setOver(true)
          }}
          onDragLeave={() => setOver(false)}
          onDrop={(e) => {
            e.preventDefault()
            setOver(false)
            void pick(e.dataTransfer.files?.[0])
          }}
        >
          <div style={{ fontSize: 28 }}>📷</div>
          <strong>{busy ? 'Загружаем…' : 'Перетащите фото сюда или нажмите'}</strong>
          <span className="small">JPEG, PNG или WEBP до 8 МБ · лучше горизонтальное 4:3</span>
        </div>
      )}
      <input
        ref={input}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        hidden
        onChange={(e) => pick(e.target.files?.[0])}
      />
      {error && <div className="error">{error}</div>}
    </div>
  )
}

/** Переключатель разделов с одним скользящим «ползунком». */
export function Tabs<T extends string>({
  items,
  value,
  onChange,
}: {
  items: { value: T; label: string }[]
  value: T
  onChange: (v: T) => void
}) {
  const index = Math.max(0, items.findIndex((i) => i.value === value))
  return (
    <div className="tabs" role="tablist">
      <span
        className="tabs-thumb"
        style={{ width: `calc((100% - 8px) / ${items.length})`, transform: `translateX(${index * 100}%)` }}
      />
      {items.map((i) => (
        <button key={i.value} role="tab" aria-selected={i.value === value} className={i.value === value ? 'active' : ''} onClick={() => onChange(i.value)}>
          {i.label}
        </button>
      ))}
    </div>
  )
}

/** Загрузка: «скелет» будущего содержимого с бегущим бликом. */
export function Loading({ rows = 3 }: { rows?: number }) {
  return (
    <div className="skeleton-wrap" role="status" aria-label="Загрузка">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="skeleton-card" style={{ animationDelay: `${i * 60}ms` }}>
          <span className="sk" style={{ width: '38%', height: 14 }} />
          <span className="sk" style={{ width: '72%', height: 22 }} />
          <span className="sk" style={{ width: '56%', height: 12 }} />
        </div>
      ))}
    </div>
  )
}

/** Уведомления «Сохранено» и т. п. — внизу по центру, уходят сами. */
export function Toaster() {
  const items = useToasts()
  return (
    <div className="toaster" aria-live="polite">
      {items.map((t) => (
        <div key={t.id} className={`toast ${t.kind}${t.leaving ? ' leaving' : ''}`} onClick={() => dismiss(t.id)}>
          <span className="toast-icon" aria-hidden="true">
            {t.kind === 'ok' ? (
              <svg viewBox="0 0 24 24" width="18" height="18">
                <path d="M5 12.5l4.2 4.2L19 7" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            ) : (
              '!'
            )}
          </span>
          {t.text}
        </div>
      ))}
    </div>
  )
}

export function ErrorBox({ error }: { error: unknown }) {
  return <div className="card error">{errorText(error)}</div>
}

/** Число, которое «набегает» до значения (для показателей на обзоре). */
export function CountUp({ value }: { value: number }) {
  return <>{useCountUp(value).toLocaleString('ru-RU')}</>
}
