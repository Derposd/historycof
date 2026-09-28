import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { ErrorBox, Loading } from '../components/ui'
import { errorText } from '../format'
import type { DayHours, Venue as VenueT } from '../types'

const DAYS = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье']

export function Venue() {
  const q = useQuery({ queryKey: ['venue'], queryFn: () => api<VenueT>('/admin/venue') })
  if (q.isError) return <ErrorBox error={q.error} />
  if (q.isPending) return <Loading />
  return <VenueForm initial={q.data} />
}

function VenueForm({ initial }: { initial: VenueT }) {
  const qc = useQueryClient()
  const [form, setForm] = useState<VenueT>(initial)
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null)

  const set = <K extends keyof VenueT>(k: K, v: VenueT[K]) => setForm({ ...form, [k]: v })
  const setDay = (day: number, patch: Partial<DayHours>) =>
    set(
      'hours',
      form.hours.map((h) => (h.day === day ? { ...h, ...patch } : h)),
    )

  async function submit(e: FormEvent) {
    e.preventDefault()
    setMsg(null)
    try {
      const saved = await api<VenueT>('/admin/venue', { method: 'PUT', json: form })
      setForm(saved)
      void qc.invalidateQueries({ queryKey: ['venue'] })
      setMsg({ ok: true, text: 'Сохранено — приложение покажет новые данные при следующем открытии экрана' })
    } catch (err) {
      setMsg({ ok: false, text: errorText(err) })
    }
  }

  return (
    <form onSubmit={submit}>
      <div className="page-head">
        <div>
          <div className="caps">Раздел «Контакты» в приложении</div>
          <h1>Контакты и часы</h1>
        </div>
        <button type="submit">Сохранить</button>
      </div>
      {msg && (
        <div className={msg.ok ? 'card' : 'card error'} style={{ marginBottom: 16 }}>
          {msg.text}
        </div>
      )}

      <div className="grid grid-2">
        <div className="card stack">
          <h3>Адрес и связь</h3>
          <label className="field">
            <span className="caps">Адрес</span>
            <input value={form.address} onChange={(e) => set('address', e.target.value)} required />
          </label>
          <div className="row">
            <label className="field" style={{ flex: 1 }}>
              <span className="caps">Широта</span>
              <input
                type="number"
                step="any"
                value={form.lat ?? ''}
                onChange={(e) => set('lat', e.target.value === '' ? null : Number(e.target.value))}
                placeholder="43.48…"
              />
            </label>
            <label className="field" style={{ flex: 1 }}>
              <span className="caps">Долгота</span>
              <input
                type="number"
                step="any"
                value={form.lng ?? ''}
                onChange={(e) => set('lng', e.target.value === '' ? null : Number(e.target.value))}
                placeholder="43.6…"
              />
            </label>
          </div>
          <span className="muted small">
            Без координат маршрут строится по адресу. Точные координаты можно взять в Яндекс Картах (правый клик по
            точке).
          </span>
          <label className="field">
            <span className="caps">Телефон</span>
            <input value={form.phone} onChange={(e) => set('phone', e.target.value)} placeholder="+79604316223" required />
          </label>
          <label className="field">
            <span className="caps">WhatsApp</span>
            <input value={form.whatsapp} onChange={(e) => set('whatsapp', e.target.value)} placeholder="+79604316223" required />
          </label>
          <label className="field">
            <span className="caps">Instagram (без @)</span>
            <input value={form.instagram} onChange={(e) => set('instagram', e.target.value)} required />
          </label>
          <label className="field">
            <span className="caps">Юрлицо (подвал приложения)</span>
            <input value={form.legalName} onChange={(e) => set('legalName', e.target.value)} />
          </label>
        </div>

        <div className="card stack">
          <h3>Часы работы</h3>
          <span className="muted small">Время по Москве. Если закрытие раньше открытия — смена считается ночной.</span>
          {[...form.hours]
            .sort((a, b) => a.day - b.day)
            .map((h) => {
              const off = h.open === null
              return (
                <div key={h.day} className="row">
                  <span style={{ width: 120 }}>{DAYS[h.day - 1]}</span>
                  <input
                    type="time"
                    value={h.open ?? ''}
                    disabled={off}
                    onChange={(e) => setDay(h.day, { open: e.target.value })}
                    required={!off}
                  />
                  <span>–</span>
                  <input
                    type="time"
                    value={h.close ?? ''}
                    disabled={off}
                    onChange={(e) => setDay(h.day, { close: e.target.value })}
                    required={!off}
                  />
                  <label className="check small">
                    <input
                      type="checkbox"
                      checked={off}
                      onChange={(e) =>
                        setDay(h.day, e.target.checked ? { open: null, close: null } : { open: '09:00', close: '23:00' })
                      }
                    />
                    выходной
                  </label>
                </div>
              )
            })}
        </div>
      </div>
    </form>
  )
}
