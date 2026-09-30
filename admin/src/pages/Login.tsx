import { useState, type FormEvent } from 'react'
import { useAuth } from '../auth-context'
import { errorText } from '../format'
import { Logo } from '../components/Monogram'
import { usePageTitle } from '../motion'

export function Login() {
  usePageTitle('Вход')
  const { login } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await login(email, password)
    } catch (err) {
      setError(errorText(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="login-wrap">
      {/* Медленно плывущие цветные пятна — тот же тёплый фон, что в приложении */}
      <span className="login-orb o1" aria-hidden="true" />
      <span className="login-orb o2" aria-hidden="true" />
      <span className="login-orb o3" aria-hidden="true" />
      <form className="card login-card stack" onSubmit={submit}>
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <Logo size={48} animate />
        </div>
        <div className="login-hello">
          <h2>С возвращением</h2>
          <div className="muted small">Новости, меню и обращения гостей — в одном месте</div>
        </div>
        <label className="field">
          <span className="caps">Email</span>
          <input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </label>
        <label className="field">
          <span className="caps">Пароль</span>
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </label>
        {error && <div className="error">{error}</div>}
        <button type="submit" disabled={busy}>
          {busy ? 'Входим…' : 'Войти'}
        </button>
      </form>
    </div>
  )
}
