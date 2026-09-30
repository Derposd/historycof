import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '../api'
import { BusyButton, ErrorBox, Loading } from '../components/ui'
import { errorText, formatPhone, formatWhen, mskDayLabel, mskTime } from '../format'
import { toast, usePageTitle } from '../motion'
import type { ChatMessage, ChatThread } from '../types'

/** Как часто подтягивать новые сообщения, пока страница открыта. */
const POLL_MS = 5_000

const guestLabel = (t: { guestName: string | null; guestPhone: string | null }) =>
  t.guestName || (t.guestPhone ? formatPhone(t.guestPhone) : 'Гость')

export function Chat() {
  usePageTitle('Чат')
  const { guestId } = useParams()
  const navigate = useNavigate()

  const threads = useQuery({
    queryKey: ['chats'],
    queryFn: () => api<ChatThread[]>('/admin/chats'),
    refetchInterval: POLL_MS,
  })

  return (
    <div>
      <div className="page-head">
        <div>
          <div className="caps">Сообщения гостей из приложения</div>
          <h1>Чат</h1>
        </div>
      </div>

      {threads.isPending && <Loading />}
      {threads.isError && <ErrorBox error={threads.error} />}
      {threads.data && (
        <div className={`chat-layout${guestId ? ' has-thread' : ''}`}>
          <div className="card chat-list" role="list">
            {threads.data.length === 0 ? (
              <div className="empty">
                <div className="empty-icon" aria-hidden="true">✉︎</div>
                Пока никто не написал. Гости пишут из приложения: вкладка «Контакты» → «Чат».
              </div>
            ) : (
              threads.data.map((t) => (
                <button
                  key={t.guestId}
                  role="listitem"
                  className={`chat-item${t.guestId === guestId ? ' active' : ''}`}
                  onClick={() => navigate(`/chat/${t.guestId}`)}
                >
                  <span className="chat-item-top">
                    <span className="chat-item-name">{guestLabel(t)}</span>
                    <span className="muted small">{formatWhen(t.lastAt)}</span>
                  </span>
                  <span className="chat-item-bottom">
                    <span className={`chat-item-text${t.unread ? ' unread' : ''}`}>
                      {t.lastFromStaff && <span className="muted">Вы: </span>}
                      {t.lastText}
                    </span>
                    {t.unread > 0 && <span className="pill terracotta">{t.unread}</span>}
                  </span>
                </button>
              ))
            )}
          </div>

          {guestId ? (
            <Thread key={guestId} guestId={guestId} />
          ) : (
            threads.data.length > 0 && (
              <div className="card chat-thread chat-placeholder muted">Выберите диалог слева</div>
            )
          )}
        </div>
      )}
    </div>
  )
}

function Thread({ guestId }: { guestId: string }) {
  const qc = useQueryClient()
  const [text, setText] = useState('')
  const scroller = useRef<HTMLDivElement>(null)

  const thread = useQuery({
    queryKey: ['chat', guestId],
    queryFn: () =>
      api<{ guest: { id: string; name: string | null; phone: string | null }; messages: ChatMessage[] }>(
        `/admin/chats/${guestId}`,
      ),
    refetchInterval: POLL_MS,
  })

  // Открытие диалога отмечает сообщения прочитанными — обновляем список и счётчик в меню
  const loaded = thread.data?.messages.length ?? -1
  useEffect(() => {
    if (loaded < 0) return
    void qc.invalidateQueries({ queryKey: ['chats'] })
    void qc.invalidateQueries({ queryKey: ['chat-unread'] })
  }, [loaded, qc])

  // Новые сообщения — прокручиваем вниз
  useLayoutEffect(() => {
    const el = scroller.current
    if (el) el.scrollTop = el.scrollHeight
  }, [loaded])

  const send = useMutation({
    mutationFn: (body: string) => api<ChatMessage>(`/admin/chats/${guestId}`, { method: 'POST', json: { text: body } }),
    onSuccess: () => {
      setText('')
      void qc.invalidateQueries({ queryKey: ['chat', guestId] })
      void qc.invalidateQueries({ queryKey: ['chats'] })
    },
    onError: (e) => toast(errorText(e), 'error'),
  })

  const submit = () => {
    const body = text.trim()
    if (body && !send.isPending) send.mutate(body)
  }

  if (thread.isPending) return <div className="card chat-thread"><Loading /></div>
  if (thread.isError) return <div className="card chat-thread"><ErrorBox error={thread.error} /></div>

  const { guest, messages } = thread.data
  return (
    <div className="card chat-thread">
      <div className="chat-head">
        <Link to="/chat" className="chat-back" aria-label="Все диалоги">
          ←
        </Link>
        <div className="stack" style={{ gap: 2 }}>
          <strong>{guest.name || 'Гость'}</strong>
          {guest.phone && (
            <a href={`tel:${guest.phone}`} className="small">
              {formatPhone(guest.phone)}
            </a>
          )}
        </div>
      </div>

      <div className="chat-messages" ref={scroller} aria-live="polite">
        {messages.map((m, i) => {
          const day = mskDayLabel(m.createdAt)
          const showDay = i === 0 || mskDayLabel(messages[i - 1].createdAt) !== day
          return (
            <div key={m.id} className="stack" style={{ gap: 6 }}>
              {showDay && <div className="chat-day muted small">{day}</div>}
              <div className={`bubble ${m.fromStaff ? 'mine' : 'theirs'}`}>
                <div className="bubble-text">{m.text}</div>
                <div className="bubble-meta">
                  {mskTime(new Date(m.createdAt))}
                  {m.fromStaff && (m.readAt ? ' · прочитано' : ' · доставлено')}
                </div>
              </div>
            </div>
          )
        })}
      </div>

      <form
        className="chat-compose"
        onSubmit={(e) => {
          e.preventDefault()
          submit()
        }}
      >
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            // Enter — отправить, Shift+Enter — новая строка
            if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
              e.preventDefault()
              submit()
            }
          }}
          rows={2}
          maxLength={2000}
          placeholder="Ответ гостю…"
          title="Enter — отправить, Shift+Enter — новая строка"
          aria-label="Сообщение гостю"
        />
        <BusyButton type="submit" busy={send.isPending} disabled={!text.trim()}>
          Отправить
        </BusyButton>
      </form>
    </div>
  )
}
