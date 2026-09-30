import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api, uploadImage } from '../api'
import { confirmDanger } from '../ask'
import { BusyButton, ErrorBox, ImageField, Loading, Modal, Tabs } from '../components/ui'
import { errorText } from '../format'
import { BADGE_LABELS, type MenuBadge, type MenuCategory, type MenuItem, type MenuPrice, type MenuSection } from '../types'
import { toast, usePageTitle } from '../motion'

export function Menu() {
  usePageTitle('Меню')
  const qc = useQueryClient()
  const q = useQuery({ queryKey: ['menu'], queryFn: () => api<MenuSection[]>('/admin/menu') })
  const [sectionId, setSectionId] = useState<string | null>(null)
  const [itemEdit, setItemEdit] = useState<{ item: MenuItem | null; categoryId: string } | null>(null)
  const [catEdit, setCatEdit] = useState<{ category: MenuCategory | null; sectionId: string } | null>(null)
  const invalidate = () => qc.invalidateQueries({ queryKey: ['menu'] })

  const patchItem = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<MenuItem> }) =>
      api(`/admin/menu/items/${id}`, { method: 'PATCH', json: data }),
    onSuccess: invalidate,
  })
  const reorder = useMutation({
    mutationFn: ({ kind, ids }: { kind: 'categories' | 'items'; ids: string[] }) =>
      api(`/admin/menu/reorder/${kind}`, { method: 'PUT', json: { ids } }),
    onSuccess: invalidate,
  })

  if (q.isPending) return <Loading />
  if (q.isError) return <ErrorBox error={q.error} />

  const sections = q.data
  const section = sections.find((s) => s.id === sectionId) ?? sections[0]

  function move<T extends { id: string }>(list: T[], index: number, dir: -1 | 1): string[] {
    const ids = list.map((x) => x.id)
    const j = index + dir
    if (j < 0 || j >= ids.length) return ids
    ;[ids[index], ids[j]] = [ids[j], ids[index]]
    return ids
  }

  return (
    <div>
      <div className="page-head">
        <div>
          <div className="caps">Меню в приложении</div>
          <h1>Меню</h1>
        </div>
        {section && (
          <button className="ghost" onClick={() => setCatEdit({ category: null, sectionId: section.id })}>
            Добавить категорию
          </button>
        )}
      </div>

      {sections.length === 0 ? (
        <div className="card empty">
          Разделов нет. Запустите <code>npm run db:seed</code> на backend, чтобы создать «Кухню» и «Бар».
        </div>
      ) : (
        <div style={{ marginBottom: 20 }}>
          <Tabs
            items={sections.map((s) => ({ value: s.id, label: s.title }))}
            value={section?.id ?? ''}
            onChange={setSectionId}
          />
        </div>
      )}

      {/* Ключ по разделу: при переключении Кухня/Бар категории заново выезжают лесенкой */}
      <div key={section?.id} className="stack stagger" style={{ gap: 20 }}>
        {section?.categories.map((c, ci) => (
          <div key={c.id} className="card">
            <div className="cat-head">
              <div className="row cat-title">
                <h2>{c.title}</h2>
                {!c.visible && <span className="pill">Скрыта</span>}
              </div>
              <div className="row cat-actions">
                <button
                  className="ghost small icon"
                  aria-label="Выше"
                  disabled={ci === 0}
                  onClick={() => reorder.mutate({ kind: 'categories', ids: move(section.categories, ci, -1) })}
                >
                  ↑
                </button>
                <button
                  className="ghost small icon"
                  aria-label="Ниже"
                  disabled={ci === section.categories.length - 1}
                  onClick={() => reorder.mutate({ kind: 'categories', ids: move(section.categories, ci, 1) })}
                >
                  ↓
                </button>
                <button className="ghost small" onClick={() => setCatEdit({ category: c, sectionId: section.id })}>
                  Настроить
                </button>
                <button className="small" onClick={() => setItemEdit({ item: null, categoryId: c.id })}>
                  + Позиция
                </button>
              </div>
            </div>
            {c.items.length === 0 ? (
              <div className="muted small">В категории пока нет позиций — в приложении она не показывается</div>
            ) : (
              <div className="items">
                {c.items.map((i, ii) => (
                  <div key={i.id} className={`item${i.available ? '' : ' off'}`}>
                    <ThumbUpload item={i} onUploaded={(url) => patchItem.mutate({ id: i.id, data: { imageUrl: url } })} />
                    <div className="item-info">
                      <div style={{ fontWeight: 500 }}>{i.title}</div>
                      {i.description && <div className="muted small">{i.description}</div>}
                      {i.badges.length > 0 && (
                        <div className="row" style={{ marginTop: 6, gap: 6 }}>
                          {i.badges.map((b) => (
                            <span key={b} className={`pill ${b === 'story' ? 'outline' : b === 'team_choice' ? 'accent' : 'gold'}`}>
                              {BADGE_LABELS[b]}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                    <div className="item-price">
                      {i.prices.map((p) => `${p.label ? `${p.label} ` : ''}${p.amount} ₽`).join(' / ') || '—'}
                    </div>
                    <div className="item-actions">
                      <label className="check small">
                        <input
                          type="checkbox"
                          checked={i.available}
                          onChange={(e) => patchItem.mutate({ id: i.id, data: { available: e.target.checked } })}
                        />
                        В меню
                      </label>
                      <span className="spacer" />
                      <button
                        className="ghost small icon"
                        aria-label="Выше"
                        disabled={ii === 0}
                        onClick={() => reorder.mutate({ kind: 'items', ids: move(c.items, ii, -1) })}
                      >
                        ↑
                      </button>
                      <button
                        className="ghost small icon"
                        aria-label="Ниже"
                        disabled={ii === c.items.length - 1}
                        onClick={() => reorder.mutate({ kind: 'items', ids: move(c.items, ii, 1) })}
                      >
                        ↓
                      </button>
                      <button className="ghost small" onClick={() => setItemEdit({ item: i, categoryId: c.id })}>
                        Изменить
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>

      <p className="muted small" style={{ marginTop: 24 }}>
        В приложении под меню выводится: «Цены и состав блюд носят информационный характер, актуальное меню — в
        кофейне».
      </p>

      {itemEdit && (
        <ItemEditor
          item={itemEdit.item}
          categoryId={itemEdit.categoryId}
          categories={section?.categories ?? []}
          onClose={() => setItemEdit(null)}
          onSaved={() => {
            setItemEdit(null)
            void invalidate()
          }}
        />
      )}
      {catEdit && (
        <CategoryEditor
          category={catEdit.category}
          sectionId={catEdit.sectionId}
          onClose={() => setCatEdit(null)}
          onSaved={() => {
            setCatEdit(null)
            void invalidate()
          }}
        />
      )}
    </div>
  )
}

function CategoryEditor({
  category,
  sectionId,
  onClose,
  onSaved,
}: {
  category: MenuCategory | null
  sectionId: string
  onClose: () => void
  onSaved: () => void
}) {
  const [title, setTitle] = useState(category?.title ?? '')
  const [visible, setVisible] = useState(category?.visible ?? true)
  const [error, setError] = useState<string | null>(null)

  async function submit(e: FormEvent) {
    e.preventDefault()
    try {
      if (category) await api(`/admin/menu/categories/${category.id}`, { method: 'PATCH', json: { title, visible } })
      else await api('/admin/menu/categories', { method: 'POST', json: { sectionId, title, visible, sort: 999 } })
      toast(category ? 'Категория сохранена' : 'Категория добавлена')
      onSaved()
    } catch (err) {
      setError(errorText(err))
    }
  }

  async function remove() {
    if (
      !category ||
      !(await confirmDanger('Удалить категорию?', `«${category.title}» удалится вместе со всеми позициями. Это нельзя отменить.`))
    )
      return
    try {
      await api(`/admin/menu/categories/${category.id}`, { method: 'DELETE' })
      toast('Категория удалена')
      onSaved()
    } catch (err) {
      setError(errorText(err))
    }
  }

  return (
    <Modal
      title={category ? 'Категория' : 'Новая категория'}
      onClose={onClose}
      dirty={title !== (category?.title ?? '') || visible !== (category?.visible ?? true)}
    >
      <form className="stack" onSubmit={submit}>
        <label className="field">
          <span className="caps">Название</span>
          <input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={80} required />
        </label>
        <label className="check">
          <input type="checkbox" checked={visible} onChange={(e) => setVisible(e.target.checked)} />
          Показывать в приложении
        </label>
        {error && <div className="error">{error}</div>}
        <div className="row">
          {category && (
            <button type="button" className="danger" onClick={remove}>
              Удалить
            </button>
          )}
          <span className="spacer" />
          <button type="button" className="ghost" data-close>
            Отмена
          </button>
          <button type="submit">Сохранить</button>
        </div>
      </form>
    </Modal>
  )
}

function ItemEditor({
  item,
  categoryId,
  categories,
  onClose,
  onSaved,
}: {
  item: MenuItem | null
  categoryId: string
  categories: MenuCategory[]
  onClose: () => void
  onSaved: () => void
}) {
  const [form, setForm] = useState({
    categoryId: item?.categoryId ?? categoryId,
    title: item?.title ?? '',
    description: item?.description ?? '',
    portion: item?.portion ?? '',
    imageUrl: item?.imageUrl ?? null,
    story: item?.story ?? '',
    available: item?.available ?? true,
    allergens: item?.allergens ?? '',
  })
  // Пищевая ценность — строками, чтобы поле можно было оставить пустым
  const [nutrition, setNutrition] = useState(() => ({
    kcal: item?.nutrition?.kcal?.toString() ?? '',
    proteins: item?.nutrition?.proteins?.toString() ?? '',
    fats: item?.nutrition?.fats?.toString() ?? '',
    carbs: item?.nutrition?.carbs?.toString() ?? '',
  }))
  const [prices, setPrices] = useState<MenuPrice[]>(item?.prices.length ? item.prices : [{ label: '', amount: 0 }])
  const [badges, setBadges] = useState<MenuBadge[]>(item?.badges ?? [])
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const set = <K extends keyof typeof form>(k: K, v: (typeof form)[K]) => setForm((f) => ({ ...f, [k]: v }))
  // Есть ли несохранённые правки — сравниваем с тем, с чего открыли окно
  const [initial] = useState(() => JSON.stringify({ form, prices, badges, nutrition }))
  const dirty = JSON.stringify({ form, prices, badges, nutrition }) !== initial

  async function submit(e: FormEvent) {
    e.preventDefault()
    if (badges.includes('story') && !form.story.trim()) {
      setError('Для бейджа «Блюдо с историей» добавьте легенду')
      return
    }
    setBusy(true)
    setError(null)
    const payload = {
      ...form,
      description: form.description || null,
      portion: form.portion || null,
      story: form.story || null,
      allergens: form.allergens.trim() || null,
      nutrition: (() => {
        const num = (v: string) => {
          const x = Number(v.replace(',', '.'))
          return v.trim() === '' || !Number.isFinite(x) ? null : x
        }
        const n = { kcal: num(nutrition.kcal), proteins: num(nutrition.proteins), fats: num(nutrition.fats), carbs: num(nutrition.carbs) }
        return Object.values(n).some((v) => v !== null) ? n : null
      })(),
      prices: prices.filter((p) => p.amount > 0),
      badges,
    }
    try {
      if (item) await api(`/admin/menu/items/${item.id}`, { method: 'PATCH', json: payload })
      else await api('/admin/menu/items', { method: 'POST', json: { ...payload, sort: 999 } })
      toast(item ? 'Позиция сохранена' : 'Позиция добавлена в меню')
      onSaved()
    } catch (err) {
      setError(errorText(err))
    } finally {
      setBusy(false)
    }
  }

  async function remove() {
    if (!item || !(await confirmDanger('Удалить позицию?', `«${item.title}» пропадёт из меню в приложении.`))) return
    await api(`/admin/menu/items/${item.id}`, { method: 'DELETE' })
    toast('Позиция удалена')
    onSaved()
  }

  return (
    <Modal title={item ? 'Позиция меню' : 'Новая позиция'} onClose={onClose} dirty={dirty && !busy}>
      <form className="stack" onSubmit={submit}>
        <div className="field">
          <span className="caps">Фото блюда</span>
          <ImageField value={form.imageUrl} onChange={(u) => set('imageUrl', u)} folder="menu" />
        </div>
        <div className="grid grid-2" style={{ gap: 12 }}>
          <label className="field">
            <span className="caps">Название</span>
            <input value={form.title} onChange={(e) => set('title', e.target.value)} maxLength={120} required />
          </label>
          <label className="field">
            <span className="caps">Категория</span>
            <select value={form.categoryId} onChange={(e) => set('categoryId', e.target.value)}>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.title}
                </option>
              ))}
            </select>
          </label>
        </div>
        <label className="field">
          <span className="caps">Состав / описание</span>
          <textarea
            value={form.description}
            onChange={(e) => set('description', e.target.value)}
            rows={3}
            maxLength={1000}
            style={{ minHeight: 80 }}
          />
        </label>
        <label className="field">
          <span className="caps">Выход</span>
          <input value={form.portion} onChange={(e) => set('portion', e.target.value)} placeholder="250 г / 300 мл" maxLength={40} />
        </label>

        <div className="field">
          <span className="caps">Пищевая ценность на порцию</span>
          <div className="nutrition-grid">
            {(
              [
                ['kcal', 'ккал'],
                ['proteins', 'белки, г'],
                ['fats', 'жиры, г'],
                ['carbs', 'углеводы, г'],
              ] as const
            ).map(([k, label]) => (
              <label key={k} className="field">
                <input
                  inputMode="decimal"
                  value={nutrition[k]}
                  onChange={(e) => setNutrition((n) => ({ ...n, [k]: e.target.value.replace(/[^\d.,]/g, '') }))}
                  placeholder="—"
                />
                <span className="muted small">{label}</span>
              </label>
            ))}
          </div>
          <span className="muted small">Необязательно. По правилам общепита гость вправе знать калорийность и БЖУ — если есть техкарта, заполните.</span>
        </div>

        <label className="field">
          <span className="caps">Аллергены</span>
          <input value={form.allergens} onChange={(e) => set('allergens', e.target.value)} placeholder="молоко, орехи, глютен" maxLength={300} />
        </label>

        <div className="field">
          <span className="caps">Цены</span>
          <span className="muted small">
            Несколько вариантов — например, капучино S 270 / L 290. Для одного варианта подпись можно не заполнять.
          </span>
          {prices.map((p, i) => (
            <div key={i} className="row price-row">
              <input
                placeholder="Подпись (S, L, 250 мл)"
                value={p.label}
                maxLength={30}
                onChange={(e) => setPrices(prices.map((x, j) => (j === i ? { ...x, label: e.target.value } : x)))}
                style={{ flex: 1 }}
              />
              <input
                type="number"
                min={0}
                placeholder="₽"
                value={p.amount || ''}
                onChange={(e) => setPrices(prices.map((x, j) => (j === i ? { ...x, amount: Number(e.target.value) } : x)))}
                className="price-amount"
              />
              {prices.length > 1 && (
                <button type="button" className="ghost small" onClick={() => setPrices(prices.filter((_, j) => j !== i))}>
                  ✕
                </button>
              )}
            </div>
          ))}
          {prices.length < 4 && (
            <button type="button" className="link" style={{ alignSelf: 'flex-start' }} onClick={() => setPrices([...prices, { label: '', amount: 0 }])}>
              + вариант цены
            </button>
          )}
        </div>

        <div className="field">
          <span className="caps">Бейджи</span>
          <div className="row">
            {(Object.keys(BADGE_LABELS) as MenuBadge[]).map((b) => (
              <label key={b} className="check">
                <input
                  type="checkbox"
                  checked={badges.includes(b)}
                  onChange={(e) => setBadges(e.target.checked ? [...badges, b] : badges.filter((x) => x !== b))}
                />
                {BADGE_LABELS[b]}
              </label>
            ))}
          </div>
        </div>

        {badges.includes('story') && (
          <label className="field">
            <span className="caps">Легенда «Блюда с историей»</span>
            <textarea value={form.story} onChange={(e) => set('story', e.target.value)} rows={3} maxLength={2000} style={{ minHeight: 80 }} />
          </label>
        )}

        <label className="check">
          <input type="checkbox" checked={form.available} onChange={(e) => set('available', e.target.checked)} />
          Показывать в приложении
        </label>

        {error && <div className="error">{error}</div>}
        <div className="row">
          {item && (
            <button type="button" className="danger" onClick={remove}>
              Удалить
            </button>
          )}
          <span className="spacer" />
          <button type="button" className="ghost" data-close>
            Отмена
          </button>
          <BusyButton type="submit" busy={busy}>
            {busy ? 'Сохраняем…' : 'Сохранить'}
          </BusyButton>
        </div>
      </form>
    </Modal>
  )
}

/** Миниатюра в таблице: клик — загрузить или заменить фото блюда сразу, без открытия формы. */
function ThumbUpload({ item, onUploaded }: { item: MenuItem; onUploaded: (url: string) => void }) {
  const [busy, setBusy] = useState(false)
  const pick = () => {
    const input = document.createElement('input')
    input.type = 'file'
    input.accept = 'image/jpeg,image/png,image/webp'
    input.onchange = async () => {
      const file = input.files?.[0]
      if (!file) return
      setBusy(true)
      try {
        onUploaded(await uploadImage(file, 'menu'))
      } catch (e) {
        toast(errorText(e), 'error')
      } finally {
        setBusy(false)
      }
    }
    input.click()
  }
  return (
    <button
      type="button"
      className={`thumb-btn${item.imageUrl ? '' : ' empty'}`}
      title={item.imageUrl ? 'Заменить фото' : 'Добавить фото'}
      onClick={pick}
      disabled={busy}
    >
      {item.imageUrl ? <img src={item.imageUrl} alt="" className="thumb" /> : <div className="thumb" />}
      <span className="thumb-add">{busy ? '…' : item.imageUrl ? '↻' : '+'}</span>
    </button>
  )
}
