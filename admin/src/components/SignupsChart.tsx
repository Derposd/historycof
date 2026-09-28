import { useMemo, useState } from 'react'

interface Point {
  day: string // YYYY-MM-DD (по Москве)
  n: number
}

const DAYS = 30
const fmtDay = (iso: string, opts: Intl.DateTimeFormatOptions) =>
  new Date(`${iso}T12:00:00+03:00`).toLocaleDateString('ru-RU', { timeZone: 'Europe/Moscow', ...opts })

function plural(n: number) {
  const m10 = n % 10
  const m100 = n % 100
  if (m10 === 1 && m100 !== 11) return 'регистрация'
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'регистрации'
  return 'регистраций'
}

/** Последние 30 дней по Москве, включая сегодня; дни без регистраций — нули. */
function fillDays(points: Point[]): Point[] {
  const byDay = new Map(points.map((p) => [p.day, p.n]))
  const todayMsk = new Date(Date.now() + 3 * 3600_000)
  const out: Point[] = []
  for (let i = DAYS - 1; i >= 0; i--) {
    const d = new Date(todayMsk.getTime() - i * 86400_000).toISOString().slice(0, 10)
    out.push({ day: d, n: byDay.get(d) ?? 0 })
  }
  return out
}

/** «Красивый» верх шкалы: 1, 2, 5, 10, 20, 50… не меньше максимума. */
function niceMax(v: number) {
  if (v <= 1) return 1
  const p = 10 ** Math.floor(Math.log10(v))
  for (const m of [1, 2, 5, 10]) if (m * p >= v) return m * p
  return 10 * p
}

/**
 * Регистрации гостей по дням. Одна серия — легенда не нужна, заголовок её называет.
 * Столбики — магнитуда во времени; нулевые дни видны как тонкая черта у основания,
 * поэтому ось всегда читается как 30 дней, даже если регистрации были в один день.
 */
export function SignupsChart({ points }: { points: Point[] }) {
  const days = useMemo(() => fillDays(points), [points])
  const total = days.reduce((s, d) => s + d.n, 0)
  const top = niceMax(Math.max(...days.map((d) => d.n)))
  const [hover, setHover] = useState<number | null>(null)
  const h = hover !== null ? days[hover] : null

  return (
    <div className="chart">
      <div className="chart-head">
        <div className="caps">Регистрации за 30 дней</div>
        <div className="chart-total">
          <span className="stat-value" style={{ fontSize: 34 }}>{total.toLocaleString('ru-RU')}</span>
          <span className="muted small">{plural(total)}</span>
        </div>
      </div>

      <div className="chart-plot" role="img" aria-label={`Регистрации за 30 дней: всего ${total}`}>
        <div className="chart-grid" aria-hidden="true">
          <div className="chart-gridline" style={{ bottom: '100%' }}>
            <span>{top}</span>
          </div>
          <div className="chart-gridline" style={{ bottom: '50%' }}>
            <span>{top / 2 === Math.round(top / 2) ? top / 2 : ''}</span>
          </div>
          <div className="chart-gridline base" style={{ bottom: 0 }}>
            <span>0</span>
          </div>
        </div>
        <div className="chart-bars" onMouseLeave={() => setHover(null)}>
          {days.map((d, i) => (
            <div
              key={d.day}
              className={`chart-col${hover === i ? ' hover' : ''}`}
              onMouseEnter={() => setHover(i)}
              onFocus={() => setHover(i)}
              onBlur={() => setHover(null)}
              tabIndex={0}
              aria-label={`${fmtDay(d.day, { day: 'numeric', month: 'long' })}: ${d.n} ${plural(d.n)}`}
            >
              {d.n > 0 ? (
                <div className="chart-bar" style={{ height: `${(d.n / top) * 100}%` }} />
              ) : (
                <div className="chart-bar zero" />
              )}
            </div>
          ))}
        </div>
        {h && hover !== null && (
          <div
            className="chart-tip"
            style={{
              left: `${Math.min(Math.max(((hover + 0.5) / DAYS) * 100, 12), 88)}%`,
              bottom: `calc(${(Math.max(h.n, 0) / top) * 100}% + 10px)`,
            }}
            role="status"
          >
            <strong>{h.n}</strong> {plural(h.n)}
            <div className="muted small">{fmtDay(h.day, { day: 'numeric', month: 'long', weekday: 'short' })}</div>
          </div>
        )}
      </div>

      <div className="chart-axis" aria-hidden="true">
        <span>{fmtDay(days[0].day, { day: 'numeric', month: 'short' })}</span>
        <span>{fmtDay(days[Math.floor(DAYS / 2)].day, { day: 'numeric', month: 'short' })}</span>
        <span>сегодня</span>
      </div>

      <table className="sr-only">
        <caption>Регистрации по дням</caption>
        <thead>
          <tr>
            <th>День</th>
            <th>Регистраций</th>
          </tr>
        </thead>
        <tbody>
          {days.map((d) => (
            <tr key={d.day}>
              <td>{fmtDay(d.day, { day: 'numeric', month: 'long' })}</td>
              <td>{d.n}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
