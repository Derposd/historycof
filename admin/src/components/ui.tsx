import { useRef, useState, type ReactNode } from 'react'
import { uploadImage } from '../api'
import { errorText } from '../format'

export function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal" role="dialog" aria-modal="true" aria-label={title}>
        <div className="row" style={{ marginBottom: 20 }}>
          <h2>{title}</h2>
          <span className="spacer" />
          <button className="ghost small" onClick={onClose} aria-label="Закрыть">
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
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

export function Loading() {
  return <div className="empty">Загрузка…</div>
}

export function ErrorBox({ error }: { error: unknown }) {
  return <div className="card error">{errorText(error)}</div>
}
