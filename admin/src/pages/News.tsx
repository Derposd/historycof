import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { ErrorBox, ImageField, Loading, Modal } from '../components/ui'
import { errorText, formatDate } from '../format'
import type { NewsPost } from '../types'

export function News() {
  const qc = useQueryClient()
  const q = useQuery({ queryKey: ['news'], queryFn: () => api<NewsPost[]>('/admin/news') })
  const [editing, setEditing] = useState<NewsPost | 'new' | null>(null)
  const invalidate = () => qc.invalidateQueries({ queryKey: ['news'] })

  const publish = useMutation({
    mutationFn: ({ id, notify }: { id: string; notify: boolean }) =>
      api(`/admin/news/${id}/publish`, { method: 'POST', json: { notify } }),
    onSuccess: invalidate,
  })
  const unpublish = useMutation({
    mutationFn: (id: string) => api(`/admin/news/${id}/unpublish`, { method: 'POST' }),
    onSuccess: invalidate,
  })
  const remove = useMutation({
    mutationFn: (id: string) => api(`/admin/news/${id}`, { method: 'DELETE' }),
    onSuccess: invalidate,
  })

  return (
    <div>
      <div className="page-head">
        <div>
          <div className="caps">Информационная доска</div>
          <h1>Новости</h1>
        </div>
        <button onClick={() => setEditing('new')}>Новый пост</button>
      </div>

      {q.isPending && <Loading />}
      {q.isError && <ErrorBox error={q.error} />}
      {q.data?.length === 0 && <div className="card empty">Постов пока нет — расскажите гостям о новинках</div>}

      <div className="stack">
        {q.data?.map((p) => (
          <div key={p.id} className="card row" style={{ alignItems: 'flex-start', gap: 16 }}>
            {p.imageUrl ? <img src={p.imageUrl} alt="" className="thumb" style={{ width: 96, height: 72 }} /> : null}
            <div className="stack" style={{ gap: 6, flex: 1, minWidth: 240 }}>
              <div className="row">
                <span className={`pill ${p.status === 'published' ? 'accent' : ''}`}>
                  {p.status === 'published' ? 'Опубликовано' : 'Черновик'}
                </span>
                {p.pinned && <span className="pill gold">Закреплено</span>}
                {p.pushedAt && <span className="pill outline">Push отправлен</span>}
                <span className="muted small">{formatDate(p.publishedAt ?? p.createdAt)}</span>
              </div>
              <h3>{p.title}</h3>
              <div className="muted small" style={{ whiteSpace: 'pre-line' }}>
                {p.body.length > 220 ? `${p.body.slice(0, 220)}…` : p.body}
              </div>
            </div>
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button className="ghost small" onClick={() => setEditing(p)}>
                Редактировать
              </button>
              {p.status === 'draft' ? (
                <button
                  className="small"
                  disabled={publish.isPending}
                  onClick={() => {
                    const notify = !p.pushedAt && confirm('Отправить push-уведомление подписчикам?')
                    publish.mutate({ id: p.id, notify })
                  }}
                >
                  Опубликовать
                </button>
              ) : (
                <button className="ghost small" onClick={() => unpublish.mutate(p.id)}>
                  Снять с публикации
                </button>
              )}
              <button
                className="danger small"
                onClick={() => confirm(`Удалить «${p.title}»?`) && remove.mutate(p.id)}
              >
                Удалить
              </button>
            </div>
          </div>
        ))}
      </div>

      {editing && (
        <NewsEditor
          post={editing === 'new' ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null)
            void invalidate()
          }}
        />
      )}
    </div>
  )
}

function NewsEditor({ post, onClose, onSaved }: { post: NewsPost | null; onClose: () => void; onSaved: () => void }) {
  const [title, setTitle] = useState(post?.title ?? '')
  const [body, setBody] = useState(post?.body ?? '')
  const [imageUrl, setImageUrl] = useState<string | null>(post?.imageUrl ?? null)
  const [pinned, setPinned] = useState(post?.pinned ?? false)
  const [publishNow, setPublishNow] = useState(false)
  const [notify, setNotify] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      if (post) {
        await api(`/admin/news/${post.id}`, { method: 'PATCH', json: { title, body, imageUrl, pinned } })
      } else {
        await api('/admin/news', { method: 'POST', json: { title, body, imageUrl, pinned, publish: publishNow, notify } })
      }
      onSaved()
    } catch (err) {
      setError(errorText(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal title={post ? 'Редактировать пост' : 'Новый пост'} onClose={onClose}>
      <form className="stack" onSubmit={submit}>
        <label className="field">
          <span className="caps">Заголовок</span>
          <input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={200} required />
        </label>
        <label className="field">
          <span className="caps">Текст</span>
          <textarea value={body} onChange={(e) => setBody(e.target.value)} rows={8} maxLength={10000} required />
        </label>
        <div className="field">
          <span className="caps">Фото</span>
          <ImageField value={imageUrl} onChange={setImageUrl} folder="news" />
        </div>
        <label className="check">
          <input type="checkbox" checked={pinned} onChange={(e) => setPinned(e.target.checked)} />
          Закрепить вверху ленты
        </label>
        {!post && (
          <>
            <label className="check">
              <input type="checkbox" checked={publishNow} onChange={(e) => setPublishNow(e.target.checked)} />
              Опубликовать сразу
            </label>
            {publishNow && (
              <label className="check">
                <input type="checkbox" checked={notify} onChange={(e) => setNotify(e.target.checked)} />
                Отправить push-уведомление подписчикам
              </label>
            )}
          </>
        )}
        {error && <div className="error">{error}</div>}
        <div className="row">
          <span className="spacer" />
          <button type="button" className="ghost" onClick={onClose}>
            Отмена
          </button>
          <button type="submit" disabled={busy}>
            {busy ? 'Сохраняем…' : 'Сохранить'}
          </button>
        </div>
      </form>
    </Modal>
  )
}
