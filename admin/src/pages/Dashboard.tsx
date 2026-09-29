import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { api } from '../api'
import { SignupsChart } from '../components/SignupsChart'
import { CountUp, ErrorBox, Loading } from '../components/ui'
import { FEEDBACK_TYPE_LABELS, type AnalyticsSummary } from '../types'

export function Dashboard() {
  const q = useQuery({ queryKey: ['analytics'], queryFn: () => api<AnalyticsSummary>('/admin/analytics/summary') })
  if (q.isPending) return <Loading />
  if (q.isError) return <ErrorBox error={q.error} />
  const s = q.data

  return (
    <div className="stack stagger" style={{ gap: 24 }}>
      <div className="page-head">
        <div>
          <div className="caps">History Coffee</div>
          <h1>Обзор</h1>
        </div>
      </div>

      <div className="grid grid-4 stagger">
        <Stat label="Гостей в приложении" value={s.guests.total} hint={`+${s.guests.new30d} за 30 дней`} />
        <Stat label="Активны за неделю" value={s.guests.active7d} />
        <Stat label="С бонусной картой" value={s.guests.loyaltyLinked} hint="связаны с iiko" />
        <Stat label="Устройств для push" value={s.devices} />
      </div>

      <div className="grid grid-2">
        <div className="card">
          <SignupsChart points={s.signupsByDay} />
        </div>
        <div className="card stack">
          <div className="row">
            <div className="caps">Обращения</div>
            <span className="spacer" />
            <Link to="/feedback">Открыть →</Link>
          </div>
          <div className="stat-value">
            <CountUp value={s.feedback.open} />
          </div>
          <div className="muted small">ждут ответа</div>
          <hr style={{ margin: '4px 0' }} />
          <div className="row">
            {s.feedback.last30dByType.length === 0 && <span className="muted small">За 30 дней обращений не было</span>}
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
