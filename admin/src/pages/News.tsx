import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState, type FormEvent } from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api'
import { ask, confirmDanger } from '../ask'
import { BusyButton, ErrorBox, ImageField, Loading, Modal } from '../components/ui'
import { errorText, formatDate } from '../format'
import type { AnalyticsSummary, NewsPost } from '../types'
import { toast, usePageTitle } from '../motion'
import { Monogram } from '../components/Monogram'

export function News() {
  usePageTitle('Новости')
  const qc = useQueryClient()
  const q = useQuery({ queryKey: ['news'], queryFn: () => api<NewsPost[]>('/admin/news') })
  // Сколько гостей дали согласие на рекламу (38-ФЗ ст. 18) — только им уходят уведомления о новостях
  const analytics = useQuery({ queryKey: ['analytics'], queryFn: () => api<AnalyticsSummary>('/admin/analytics/summary') })
  const subscribers = analytics.data?.marketingSubscribers ?? 0

  // /news?new=1 (быстрое действие на обзоре) сразу открывает редактор нового поста
  const [params, setParams] = useSearchParams()
  const [editing, setEditing] = useState<NewsPost | 'new' | null>(() => (params.get('new') ? 'new' : null))
  useEffect(() => {
    if (params.get('new')) setParams({}, { replace: true })
  }, [params, setParams])
  const invalidate = () => qc.invalidateQueries({ queryKey: ['news'] })

  const publish = useMutation({
    mutationFn: ({ id, notify }: { id: string; notify: boolean }) =>
      api(`/admin/news/${id}/publish`, { method: 'POST', json: { notify } }),
    onSuccess: (_, v) => {
      void invalidate()
      toast(v.notify ? 'Опубликовано, уведомление отправлено' : 'Опубликовано')
    },
    onError: (e) => toast(errorText(e), 'error'),
  })
  const unpublish = useMutation({
    mutationFn: (id: string) => api(`/admin/news/${id}/unpublish`, { method: 'POST' }),
    onSuccess: () => {
      void invalidate()
      toast('Снято с публикации')
    },
    onError: (e) => toast(errorText(e), 'error'),
  })
  const remove = useMutation({
    mutationFn: (id: string) => api(`/admin/news/${id}`, { method: 'DELETE' }),
    onSuccess: () => {
      void invalidate()
      toast('Пост удалён')
    },
    onError: (e) => toast(errorText(e), 'error'),
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

      <div className="stack stagger">
        {q.data?.map((p) => (
          <div key={p.id} className="card row news-card">
            {p.imageUrl ? <img src={p.imageUrl} alt="" className="thumb news-thumb" /> : null}
            <div className="stack news-body" style={{ gap: 6 }}>
              <div className="row">
                <span className={`pill ${p.status === 'published' ? 'accent' : ''}`}>
                  {p.status === 'published' ? 'Опубликовано' : 'Черновик'}
                </span>
                {p.pinned && <span className="pill gold">Закреплено</span>}
                {p.pushedAt && <span className="pill outline">Уведомление отправлено</span>}
                <span className="muted small">{formatDate(p.publishedAt ?? p.createdAt)}</span>
              </div>
              <h3>{p.title}</h3>
              <div className="muted small" style={{ whiteSpace: 'pre-line' }}>
                {p.body.length > 220 ? `${p.body.slice(0, 220)}…` : p.body}
              </div>
            </div>
            <div className="row news-actions">
              <button className="ghost small" onClick={() => setEditing(p)}>
                Редактировать
              </button>
              {p.status === 'draft' ? (
                <button
                  className="small"
                  disabled={publish.isPending}
                  onClick={async () => {
                    if (p.pushedAt) return publish.mutate({ id: p.id, notify: false })
                    const notify = await ask({
                      title: 'Опубликовать пост?',
                      text:
                        subscribers > 0
                          ? `Уведомление получат только гости, давшие согласие на рекламу, — сейчас их ${subscribers}. Остальные увидят пост в ленте.`
                          : 'Пока никто из гостей не дал согласие на рекламные уведомления — пост появится только в ленте.',
                      actions: [
                        { label: 'Без уведомления', value: false, kind: 'ghost' },
                        ...(subscribers > 0 ? [{ label: 'Опубликовать и отправить уведомление', value: true }] : []),
                      ],
                    })
                    if (notify !== null) publish.mutate({ id: p.id, notify })
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
                onClick={async () =>
                  (await confirmDanger(`Удалить пост?`, `«${p.title}» пропадёт из ленты приложения. Это нельзя отменить.`)) &&
                  remove.mutate(p.id)
                }
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
  const dirty =
    title !== (post?.title ?? '') ||
    body !== (post?.body ?? '') ||
    imageUrl !== (post?.imageUrl ?? null) ||
    pinned !== (post?.pinned ?? false)

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
      toast(post ? 'Изменения сохранены' : publishNow ? 'Пост опубликован' : 'Черновик сохранён')
      onSaved()
    } catch (err) {
      setError(errorText(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal title={post ? 'Редактировать пост' : 'Новый пост'} onClose={onClose} dirty={dirty && !busy} wide>
      <div className="editor-split">
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
                Отправить уведомление гостям, давшим согласие на рекламу
              </label>
            )}
          </>
        )}
        {error && <div className="error">{error}</div>}
        <div className="row">
          <span className="spacer" />
          <button type="button" className="ghost" data-close>
            Отмена
          </button>
          <BusyButton type="submit" busy={busy}>
            {busy ? 'Сохраняем…' : 'Сохранить'}
          </BusyButton>
        </div>
      </form>
      <aside className="preview-col" aria-label="Предпросмотр">
        <div className="caps">Так пост увидят гости</div>
        <NewsPreview
          title={title}
          body={body}
          imageUrl={imageUrl}
          pinned={pinned}
          push={!post && publishNow && notify}
          date={post?.publishedAt ?? null}
        />
      </aside>
      </div>
    </Modal>
  )
}

/**
 * Предпросмотр поста так, как он выглядит в ленте приложения: телефон, стеклянная
 * карточка с фото, датой, заголовком и тремя строками текста. Если включён push —
 * сверху показывается уведомление.
 */
function NewsPreview({
  title,
  body,
  imageUrl,
  pinned,
  push,
  date,
}: {
  title: string
  body: string
  imageUrl: string | null
  pinned: boolean
  push: boolean
  date: string | null
}) {
  const when = date
    ? new Date(date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', timeZone: 'Europe/Moscow' })
    : 'Сегодня'
  return (
    <div className="phone">
      <div className="phone-screen">
        {push && (
          <div className="phone-push">
            <span className="phone-push-icon"><Monogram size={28} /></span>
            <div>
              <div className="phone-push-app">History Coffee · сейчас</div>
              <div className="phone-push-title">{title || 'Заголовок поста'}</div>
            </div>
          </div>
        )}
        <div className="phone-head">
          <Monogram size={26} />
          <span>History</span>
        </div>
        <div className="phone-card">
          {imageUrl && <img src={imageUrl} alt="" />}
          <div className="phone-card-body">
            <div className="phone-date">
              {when}
              {pinned && (
                <svg viewBox="0 0 24 24" width="12" height="12" aria-label="закреплено">
                  <path d="M9 4h6l-1 5 3 3v2H7v-2l3-3-1-5zM12 14v6" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
                </svg>
              )}
            </div>
            <div className={`phone-title${title ? '' : ' placeholder'}`}>{title || 'Заголовок поста'}</div>
            <div className={`phone-text${body ? '' : ' placeholder'}`}>{body || 'Текст поста появится здесь — в ленте видны первые три строки.'}</div>
          </div>
        </div>
      </div>
    </div>
  )
}
