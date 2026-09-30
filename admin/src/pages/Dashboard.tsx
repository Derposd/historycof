import { useQuery } from '@tanstack/react-query'
import { Link, useNavigate } from 'react-router-dom'
import { api } from '../api'
import { SignupsChart } from '../components/SignupsChart'
import { CountUp, ErrorBox, Loading } from '../components/ui'
import { formatWhen } from '../format'
import { usePageTitle } from '../motion'
import { FEEDBACK_TYPE_LABELS, type AnalyticsSummary, type Feedback as FeedbackT } from '../types'

/** Приветствие по московскому времени. */
function greeting() {
  const h = Number(new Date().toLocaleString('en-GB', { hour: '2-digit', hour12: false, timeZone: 'Europe/Moscow' }))
  if (h < 5) return 'Доброй ночи'
  if (h < 12) return 'Доброе утро'
  if (h < 18) return 'Добрый день'
  return 'Добрый вечер'
}

export function Dashboard() {
  usePageTitle('Обзор')
  const navigate = useNavigate()
  const q = useQuery({ queryKey: ['analytics'], queryFn: () => api<AnalyticsSummary>('/admin/analytics/summary') })
  // Обращения, которые ждут ответа, — прямо на обзоре, чтобы разбирать их в один клик
  const waiting = useQuery({
    queryKey: ['feedback', 'waiting'],
    queryFn: () => api<{ items: FeedbackT[]; total: number }>('/admin/feedback?status=sent&page=0&pageSize=4'),
    refetchInterval: 60_000,
  })
  if (q.isPending) return <Loading />
  if (q.isError) return <ErrorBox error={q.error} />
  const s = q.data

  return (
    <div className="stack stagger" style={{ gap: 24 }}>
      <div className="page-head">
        <div>
          <div className="caps">
            {new Date().toLocaleDateString('ru-RU', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'Europe/Moscow' })}
          </div>
          <h1>{greeting()}</h1>
        </div>
        <div className="row quick-actions">
          <button className="ghost" onClick={() => navigate('/menu')}>
            Меню
          </button>
          <button onClick={() => navigate('/news?new=1')}>Новый пост</button>
        </div>
      </div>

      <div className="grid grid-4 stagger">
        <Stat label="Гостей в приложении" value={s.guests.total} hint={`+${s.guests.new30d} за 30 дней`} />
        <Stat label="Активны за неделю" value={s.guests.active7d} />
        <Stat label="С бонусной картой" value={s.guests.loyaltyLinked} hint="связаны с iiko" />
        <Stat label="Согласны на рассылку" value={s.marketingSubscribers ?? 0} hint="получат новости уведомлением" />
      </div>

      <div className="grid grid-2">
        <div className="card">
          <SignupsChart points={s.signupsByDay} />
        </div>
        <div className="card stack">
          <div className="row">
            <div className="caps">Ждут ответа</div>
            {s.feedback.open > 0 && (
              <span className="pill terracotta">
                <CountUp value={s.feedback.open} />
              </span>
            )}
            <span className="spacer" />
            <Link to="/feedback">Все обращения →</Link>
          </div>
          {waiting.data && waiting.data.items.length === 0 && (
            <div className="all-done">
              <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
                <path d="M5 12.5l4.2 4.2L19 7" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Новых обращений нет — всё разобрано
            </div>
          )}
          <div className="waiting-list">
            {waiting.data?.items.map((f) => (
              <button key={f.id} type="button" className="waiting-item" onClick={() => navigate(`/feedback/${f.id}`)}>
                <span className={`pill ${f.type === 'complaint' ? 'terracotta' : 'accent'}`}>{FEEDBACK_TYPE_LABELS[f.type]}</span>
                <span className="waiting-text">{f.message}</span>
                <span className="muted small waiting-when">{formatWhen(f.createdAt)}</span>
              </button>
            ))}
          </div>
          <hr style={{ margin: '4px 0' }} />
          <div className="row">
            <span className="muted small">За 30 дней:</span>
            {s.feedback.last30dByType.length === 0 && <span className="muted small">обращений не было</span>}
            {s.feedback.last30dByType.map((t) => (
              <span key={t.type} className={`pill ${t.type === 'complaint' ? 'terracotta' : 'accent'}`}>
                {FEEDBACK_TYPE_LABELS[t.type]}: {t.n}
              </span>
            ))}
          </div>
        </div>
      </div>

      <div className="grid grid-4 stagger">
        <Stat label="Опубликовано новостей" value={s.newsPublished} />
        <Stat label="Позиций в меню" value={s.menuItems} />
      </div>
      <p className="muted small">
        Выручка, средний чек и суммы начисленных бонусов — в отчётах iiko (iikoOffice / iikoCard): приложение их не
        дублирует.
      </p>
    </div>
  )
}

function Stat({ label, value, hint }: { label: string; value: number; hint?: string }) {
  return (
    <div className="card">
      <div className="caps">{label}</div>
      <div className="stat-value">
        <CountUp value={value} />
      </div>
      {hint && <div className="muted small" style={{ marginTop: 6 }}>{hint}</div>}
    </div>
  )
}
