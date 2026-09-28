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
      {value && <img src={value} alt="" className="cover" />}
      <div className="row">
        <button type="button" className="ghost small" disabled={busy} onClick={() => input.current?.click()}>
          {busy ? 'Загрузка…' : value ? 'Заменить фото' : 'Загрузить фото'}
        </button>
        {value && (
          <button type="button" className="danger small" onClick={() => onChange(null)}>
            Убрать
          </button>
        )}
        <span className="muted small">JPEG, PNG или WEBP до 8 МБ</span>
      </div>
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

export function Loading() {
  return <div className="empty">Загрузка…</div>
}

export function ErrorBox({ error }: { error: unknown }) {
  return <div className="card error">{errorText(error)}</div>
}
