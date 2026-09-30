import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState, type FormEvent } from 'react'
import { api } from '../api'
import { BusyButton, ErrorBox, Loading } from '../components/ui'
import { errorText } from '../format'
import type { DayHours, Venue as VenueT } from '../types'
import { toast, usePageTitle } from '../motion'

const DAYS = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье']

export function Venue() {
  usePageTitle('Контакты и часы')
  const q = useQuery({ queryKey: ['venue'], queryFn: () => api<VenueT>('/admin/venue') })
  if (q.isError) return <ErrorBox error={q.error} />
  if (q.isPending) return <Loading />
  return <VenueForm initial={q.data} />
}

function VenueForm({ initial }: { initial: VenueT }) {
  const qc = useQueryClient()
  const [form, setForm] = useState<VenueT>(initial)
  const [saved, setSaved] = useState<VenueT>(initial)
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null)
  const dirty = JSON.stringify(form) !== JSON.stringify(saved)

  // Закрытие вкладки с несохранёнными изменениями — браузер переспросит
  useEffect(() => {
    if (!dirty) return
    const onUnload = (e: BeforeUnloadEvent) => e.preventDefault()
    window.addEventListener('beforeunload', onUnload)
    return () => window.removeEventListener('beforeunload', onUnload)
  }, [dirty])

  const set = <K extends keyof VenueT>(k: K, v: VenueT[K]) => setForm({ ...form, [k]: v })
  const setDay = (day: number, patch: Partial<DayHours>) =>
    set(
      'hours',
      form.hours.map((h) => (h.day === day ? { ...h, ...patch } : h)),
    )

  async function submit(e: FormEvent) {
    e.preventDefault()
    setMsg(null)
    setBusy(true)
    try {
      const result = await api<VenueT>('/admin/venue', { method: 'PUT', json: form })
      setForm(result)
      setSaved(result)
      void qc.invalidateQueries({ queryKey: ['venue'] })
      setMsg(null)
      toast('Сохранено — в приложении обновится при следующем открытии экрана')
    } catch (err) {
      setMsg({ ok: false, text: errorText(err) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit}>
      <div className="page-head">
        <div>
          <div className="caps">Раздел «Контакты» в приложении</div>
          <h1>Контакты и часы</h1>
        </div>
        <div className="row desktop-only">
          {dirty && <span className="pill gold">Есть несохранённые изменения</span>}
          <BusyButton type="submit" busy={busy} disabled={!dirty}>
            {dirty ? 'Сохранить' : 'Сохранено'}
          </BusyButton>
        </div>
      </div>
      {msg && (
        <div className={`desktop-only ${msg.ok ? 'card' : 'card error'}`} style={{ marginBottom: 16 }}>
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
            <span className="caps">WhatsApp (необязательно)</span>
            <input value={form.whatsapp} onChange={(e) => set('whatsapp', e.target.value.trim())} placeholder="+79604316223" />
            <span className="muted small">
              Пусто — кнопки WhatsApp в приложении не будет. В России WhatsApp заблокирован с февраля 2026 года и у многих
              гостей откроется только через VPN.
            </span>
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
                <div key={h.day} className="hours-row">
                  <span className="hours-day">{DAYS[h.day - 1]}</span>
                  <input
                    type="time"
                    className="hours-open"
                    value={h.open ?? ''}
                    disabled={off}
                    onChange={(e) => setDay(h.day, { open: e.target.value })}
                    required={!off}
                  />
                  <span className="hours-dash">–</span>
                  <input
                    type="time"
                    className="hours-close"
                    value={h.close ?? ''}
                    disabled={off}
                    onChange={(e) => setDay(h.day, { close: e.target.value })}
                    required={!off}
                  />
                  <label className="check small hours-off">
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

      <div className="card stack" style={{ marginTop: 16 }}>
        <h3>Продавец и документы</h3>
        <span className="muted small">
          Подставляются в согласие на обработку персональных данных и политику — по закону там обязательны
          наименование и адрес продавца.
        </span>
        <div className="grid grid-2" style={{ gap: 12 }}>
          <label className="field">
            <span className="caps">Наименование (ИП или организация)</span>
            <input value={form.legalName} onChange={(e) => set('legalName', e.target.value)} required />
          </label>
          <label className="field">
            <span className="caps">Адрес продавца</span>
            <input value={form.legalAddress} onChange={(e) => set('legalAddress', e.target.value)} required />
          </label>
          <label className="field">
            <span className="caps">ИНН</span>
            <input value={form.inn} onChange={(e) => set('inn', e.target.value.replace(/\D/g, ''))} inputMode="numeric" maxLength={12} placeholder="10 или 12 цифр" />
          </label>
          <label className="field">
            <span className="caps">ОГРН / ОГРНИП</span>
            <input value={form.ogrn} onChange={(e) => set('ogrn', e.target.value.replace(/\D/g, ''))} inputMode="numeric" maxLength={15} placeholder="13 или 15 цифр" />
          </label>
        </div>
        <label className="field">
          <span className="caps">Почта для запросов гостей о данных (необязательно)</span>
          <input type="email" value={form.privacyEmail} onChange={(e) => set('privacyEmail', e.target.value)} placeholder="pd@historycoffee.ru" />
        </label>
        <div className="row" style={{ gap: 14 }}>
          {(['privacy', 'consent', 'marketing', 'loyalty'] as const).map((k) => (
            <a key={k} href={`/api/v1/legal/${k}/page`} target="_blank" rel="noreferrer" className="small">
              {{ privacy: 'Политика', consent: 'Согласие на обработку', marketing: 'Согласие на рекламу', loyalty: 'Правила бонусов' }[k]} ↗
            </a>
          ))}
        </div>
      </div>

      <div className="save-bar">
        {msg && <div className={`save-msg ${msg.ok ? 'small' : 'error'}`}>{msg.text}</div>}
        <BusyButton type="submit" busy={busy} disabled={!dirty}>
          {dirty ? 'Сохранить изменения' : 'Всё сохранено'}
        </BusyButton>
      </div>
    </form>
  )
}
