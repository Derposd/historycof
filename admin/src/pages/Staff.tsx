import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { useAuth } from '../auth-context'
import { ErrorBox, Loading, Modal } from '../components/ui'
import { errorText, formatDate } from '../format'
import type { StaffRole, StaffUser } from '../types'

const ROLE_LABELS: Record<StaffRole, string> = {
  admin: 'Администратор',
  editor: 'Редактор',
}

export function Staff() {
  const { user } = useAuth()
  const qc = useQueryClient()
  const q = useQuery({ queryKey: ['staff'], queryFn: () => api<StaffUser[]>('/admin/staff') })
  const [creating, setCreating] = useState(false)
  const invalidate = () => qc.invalidateQueries({ queryKey: ['staff'] })

  const toggle = useMutation({
    mutationFn: (u: StaffUser) => api(`/admin/staff/${u.id}`, { method: 'PATCH', json: { active: !u.active } }),
    onSuccess: invalidate,
    onError: (e) => alert(errorText(e)),
  })

  return (
    <div>
      <div className="page-head">
        <div>
          <div className="caps">Доступ к админке</div>
          <h1>Сотрудники</h1>
        </div>
        <button onClick={() => setCreating(true)}>Добавить сотрудника</button>
      </div>
      <p className="muted small" style={{ marginTop: -12, marginBottom: 20 }}>
        Редактор ведёт новости и меню и отвечает на обращения. Администратор также управляет контактами и сотрудниками.
      </p>

      {q.isPending && <Loading />}
      {q.isError && <ErrorBox error={q.error} />}
      {q.data && (
        <div className="card" style={{ padding: 8 }}>
          <table className="rows-table staff-table">
            <thead>
              <tr>
                <th>Имя</th>
                <th>Email</th>
                <th>Роль</th>
                <th>Последний вход</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {q.data.map((u) => (
                <tr key={u.id} style={{ opacity: u.active ? 1 : 0.5 }}>
                  <td className="st-name">{u.name}</td>
                  <td className="st-email">{u.email}</td>
                  <td className="st-role">
                    <span className={`pill ${u.role === 'admin' ? 'accent' : ''}`}>{ROLE_LABELS[u.role]}</span>
                  </td>
                  <td className="small st-login">
                    <span className="mobile-only muted">Вход: </span>
                    {formatDate(u.lastLoginAt)}
                  </td>
                  <td className="st-action" style={{ textAlign: 'right' }}>
                    {u.id !== user?.id && (
                      <button className={u.active ? 'danger small' : 'ghost small'} onClick={() => toggle.mutate(u)}>
                        {u.active ? 'Отключить' : 'Включить'}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {creating && (
        <CreateStaff
          onClose={() => setCreating(false)}
          onSaved={() => {
            setCreating(false)
            void invalidate()
          }}
        />
      )}
    </div>
  )
}

function CreateStaff({ onClose, onSaved }: { onClose: () => void; onSaved: () => void }) {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [role, setRole] = useState<StaffRole>('editor')
  const [error, setError] = useState<string | null>(null)

  async function submit(e: FormEvent) {
    e.preventDefault()
    try {
      await api('/admin/staff', { method: 'POST', json: { name, email, password, role } })
      onSaved()
    } catch (err) {
      setError(errorText(err))
    }
  }

  return (
    <Modal title="Новый сотрудник" onClose={onClose}>
      <form className="stack" onSubmit={submit}>
        <label className="field">
          <span className="caps">Имя</span>
          <input value={name} onChange={(e) => setName(e.target.value)} required />
        </label>
        <label className="field">
          <span className="caps">Email</span>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </label>
        <label className="field">
          <span className="caps">Временный пароль (от 10 символов)</span>
          <input type="text" value={password} onChange={(e) => setPassword(e.target.value)} minLength={10} required />
        </label>
        <label className="field">
          <span className="caps">Роль</span>
          <select value={role} onChange={(e) => setRole(e.target.value as StaffRole)}>
            <option value="editor">{ROLE_LABELS.editor}</option>
            <option value="admin">{ROLE_LABELS.admin}</option>
          </select>
        </label>
        {error && <div className="error">{error}</div>}
        <div className="row">
          <span className="spacer" />
          <button type="button" className="ghost" onClick={onClose}>
            Отмена
          </button>
          <button type="submit">Создать</button>
        </div>
      </form>
    </Modal>
  )
}
