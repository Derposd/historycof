import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { api } from '../api'
import { BusyButton, ErrorBox, Loading, Modal } from '../components/ui'
import { errorText, formatDate, formatPhone, formatWhen } from '../format'
import { toast, usePageTitle } from '../motion'
import {
  FEEDBACK_STATUS_LABELS,
  FEEDBACK_TYPE_LABELS,
  type Feedback as FeedbackT,
  type FeedbackStatus,
  type FeedbackType,
} from '../types'

const PAGE = 30

/** Заготовки ответа — вставляются в поле, их можно дописать перед отправкой. */
const TEMPLATES: Record<FeedbackType, { label: string; text: string }[]> = {
  complaint: [
    {
      label: 'Извиниться',
      text: 'Здравствуйте! Нам очень жаль, что так вышло. Спасибо, что рассказали — мы уже разбираемся и сделаем всё, чтобы это не повторилось. Будем рады видеть вас снова.',
    },
    {
      label: 'Уточнить детали',
      text: 'Здравствуйте! Спасибо, что написали. Подскажите, пожалуйста, дату и примерное время визита — так мы быстрее разберёмся в ситуации.',
    },
  ],
  suggestion: [
    {
      label: 'Спасибо за идею',
      text: 'Здравствуйте! Спасибо за идею — передали её команде. Если решим внедрить, обязательно расскажем в новостях приложения.',
    },
  ],
  thanks: [
    {
      label: 'Поблагодарить',
      text: 'Спасибо за тёплые слова! Передадим их команде — это очень приятно. Ждём вас снова в History Coffee.',
    },
  ],
}

export function Feedback() {
  usePageTitle('Обращения')
  const { id } = useParams()
  const navigate = useNavigate()
  const [status, setStatus] = useState<FeedbackStatus | ''>('')
  const [type, setType] = useState<FeedbackType | ''>('')
  const [page, setPage] = useState(0)

  const params = new URLSearchParams({ page: String(page), pageSize: String(PAGE) })
  if (status) params.set('status', status)
  if (type) params.set('type', type)

  const q = useQuery({
    queryKey: ['feedback', status, type, page],
    queryFn: () => api<{ items: FeedbackT[]; total: number }>(`/admin/feedback?${params}`),
    refetchInterval: 60_000,
  })

  return (
    <div>
      <div className="page-head">
        <div>
          <div className="caps">Жалобы, предложения, благодарности</div>
          <h1>Обращения</h1>
        </div>
        <div className="row filters">
          <select value={status} onChange={(e) => (setStatus(e.target.value as FeedbackStatus | ''), setPage(0))}>
            <option value="">Все статусы</option>
            {Object.entries(FEEDBACK_STATUS_LABELS).map(([k, v]) => (
              <option key={k} value={k}>
                {v}
              </option>
            ))}
          </select>
          <select value={type} onChange={(e) => (setType(e.target.value as FeedbackType | ''), setPage(0))}>
            <option value="">Все типы</option>
            {Object.entries(FEEDBACK_TYPE_LABELS).map(([k, v]) => (
              <option key={k} value={k}>
                {v}
              </option>
            ))}
          </select>
        </div>
      </div>

      {q.isPending && <Loading />}
      {q.isError && <ErrorBox error={q.error} />}
      {q.data && (
        <div className="card" style={{ padding: 8 }}>
          {q.data.items.length === 0 ? (
            <div className="empty">
              <div className="empty-icon" aria-hidden="true">✉︎</div>
              {status || type ? 'С такими фильтрами обращений нет' : 'Обращений пока нет — здесь появятся жалобы, идеи и благодарности гостей'}
            </div>
          ) : (
            <table className="rows-table fb-table">
              <thead>
                <tr>
                  <th>Дата</th>
                  <th>Тип</th>
                  <th>Сообщение</th>
                  <th>Гость</th>
                  <th>Статус</th>
                </tr>
              </thead>
              <tbody>
                {q.data.items.map((f) => (
                  <tr key={f.id} className="clickable" onClick={() => navigate(`/feedback/${f.id}`)}>
                    <td style={{ whiteSpace: 'nowrap' }} className="small fb-date" title={formatDate(f.createdAt)}>
                      {formatWhen(f.createdAt)}
                    </td>
                    <td className="fb-type">
                      <TypePill type={f.type} />
                    </td>
                    <td className="fb-msg" style={{ fontWeight: f.status === 'sent' ? 600 : 400 }}>
                      {f.status === 'sent' && <span className="unread-dot" aria-label="новое" />}
                      {f.message.length > 140 ? `${f.message.slice(0, 140)}…` : f.message}
                      {f.photoUrl && <span className="muted small"> · фото</span>}
                    </td>
                    <td className="small fb-guest">
                      {f.guestName ?? ''} {formatPhone(f.contactPhone ?? f.guestPhone)}
                    </td>
                    <td className="fb-status">
                      <StatusPill status={f.status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          {q.data.total > PAGE && (
            <div className="row" style={{ padding: 12 }}>
              <span className="muted small">
                {page * PAGE + 1}–{Math.min((page + 1) * PAGE, q.data.total)} из {q.data.total}
              </span>
              <span className="spacer" />
              <button className="ghost small" disabled={page === 0} onClick={() => setPage(page - 1)}>
                ← Назад
              </button>
              <button className="ghost small" disabled={(page + 1) * PAGE >= q.data.total} onClick={() => setPage(page + 1)}>
                Вперёд →
              </button>
            </div>
          )}
        </div>
      )}

      {id && <FeedbackDetail id={id} onClose={() => navigate('/feedback')} />}
    </div>
  )
}

function TypePill({ type }: { type: FeedbackType }) {
  return <span className={`pill ${type === 'complaint' ? 'terracotta' : 'accent'}`}>{FEEDBACK_TYPE_LABELS[type]}</span>
}

function StatusPill({ status }: { status: FeedbackStatus }) {
  const cls = status === 'sent' ? 'gold' : status === 'answered' ? 'accent' : ''
  return <span className={`pill ${cls}`}>{FEEDBACK_STATUS_LABELS[status]}</span>
}

function FeedbackDetail({ id, onClose }: { id: string; onClose: () => void }) {
  const qc = useQueryClient()
  // Открытие карточки на сервере переводит обращение в «Просмотрено».
  const q = useQuery({ queryKey: ['feedback-item', id], queryFn: () => api<FeedbackT>(`/admin/feedback/${id}`) })
  const [reply, setReply] = useState('')
  const [error, setError] = useState<string | null>(null)

  const answer = useMutation({
    mutationFn: (data: { reply?: string; status?: FeedbackStatus }) =>
      api<FeedbackT>(`/admin/feedback/${id}`, { method: 'PATCH', json: data }),
    onSuccess: (_, v) => {
      toast(v.reply ? 'Ответ отправлен гостю' : 'Отмечено как решённое')
      void qc.invalidateQueries({ queryKey: ['feedback'] })
      void qc.invalidateQueries({ queryKey: ['feedback-item', id] })
      void qc.invalidateQueries({ queryKey: ['analytics'] })
      setReply('')
    },
    onError: (e) => setError(errorText(e)),
  })

  const f = q.data
  const phone = f?.contactPhone ?? f?.guestPhone

  return (
    <Modal title="Обращение" onClose={onClose}>
      {q.isPending && <Loading />}
      {q.isError && <ErrorBox error={q.error} />}
      {f && (
        <div className="stack">
          <div className="row">
            <TypePill type={f.type} />
            <StatusPill status={f.status} />
            <span className="muted small" title={formatDate(f.createdAt)}>
              {formatWhen(f.createdAt)}
            </span>
          </div>
          <div className="note">{f.message}</div>
          {f.photoUrl && (
            <a href={f.photoUrl} target="_blank" rel="noreferrer">
              <img src={f.photoUrl} alt="Фото к обращению" className="cover" />
            </a>
          )}
          <div className="soft stack" style={{ gap: 4 }}>
            <div className="caps">Гость</div>
            <div>{f.guestName ?? (f.guestId ? 'Гость приложения' : 'Анонимно')}</div>
            {phone ? (
              <div className="row">
                <a href={`tel:${phone}`}>{formatPhone(phone)}</a>
                <a href={`https://wa.me/${phone.replace(/\D/g, '')}`} target="_blank" rel="noreferrer">
                  WhatsApp
                </a>
              </div>
            ) : (
              <div className="muted small">Телефон не указан</div>
            )}
          </div>

          {f.reply && (
            <div className="soft stack" style={{ gap: 4, background: 'rgba(138,151,112,0.1)' }}>
              <div className="caps">Ответ · {formatWhen(f.answeredAt)}</div>
              <div style={{ whiteSpace: 'pre-line' }}>{f.reply}</div>
            </div>
          )}

          {f.guestId ? (
            <>
            <label className="field">
              <span className="caps">{f.reply ? 'Новый ответ' : 'Ответить гостю'}</span>
              <textarea
                value={reply}
                onChange={(e) => setReply(e.target.value)}
                onKeyDown={(e) => {
                  // Ctrl/⌘ + Enter — отправить, не отрывая рук от клавиатуры
                  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey) && reply.trim() && !answer.isPending) answer.mutate({ reply })
                }}
                rows={4}
                maxLength={3000}
                placeholder="Ответ увидит гость в приложении и получит push-уведомление"
              />
            </label>
            <div className="templates">
              <span className="muted small">Быстрый ответ:</span>
              {TEMPLATES[f.type].map((t) => (
                <button key={t.label} type="button" className="chip" onClick={() => setReply(t.text)}>
                  {t.label}
                </button>
              ))}
              <span className="spacer" />
              <span className="muted small kbd-hint">Ctrl + Enter — отправить</span>
            </div>
            </>
          ) : (
            <p className="muted small">
              Обращение анонимное — ответить в приложении нельзя. Свяжитесь по телефону, если он указан.
            </p>
          )}
          {error && <div className="error">{error}</div>}
          <div className="row">
            {f.status !== 'answered' && (
              <button className="ghost" onClick={() => answer.mutate({ status: 'answered' })}>
                Отметить как решённое
              </button>
            )}
            <span className="spacer" />
            {f.guestId && (
              <BusyButton busy={answer.isPending} disabled={!reply.trim()} onClick={() => answer.mutate({ reply })}>
                Отправить ответ
              </BusyButton>
            )}
          </div>
        </div>
      )}
    </Modal>
  )
}
