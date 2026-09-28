import { useQuery } from '@tanstack/react-query'
import { NavLink, Outlet } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth-context'
import type { AnalyticsSummary } from '../types'
import { Logo } from './Monogram'

export function Layout() {
  const { user, logout } = useAuth()
  // Счётчик неотвеченных обращений в меню — обновляется раз в минуту.
  const summary = useQuery({
    queryKey: ['analytics'],
    queryFn: () => api<AnalyticsSummary>('/admin/analytics/summary'),
    refetchInterval: 60_000,
  })
  const open = summary.data?.feedback.open ?? 0

  return (
    <div className="layout">
      <aside className="sidebar">
        <Logo size={40} />
        <NavLink to="/" end className="nav-link">
          Обзор
        </NavLink>
        <NavLink to="/news" className="nav-link">
          Новости
        </NavLink>
        <NavLink to="/menu" className="nav-link">
          Меню
        </NavLink>
        <NavLink to="/feedback" className="nav-link">
          Обращения {open > 0 && <span className="pill terracotta">{open}</span>}
        </NavLink>
        {user?.role === 'admin' && (
          <>
            <NavLink to="/venue" className="nav-link">
              Контакты и часы
            </NavLink>
            <NavLink to="/staff" className="nav-link">
              Сотрудники
            </NavLink>
          </>
        )}
        <div className="sidebar-footer stack" style={{ gap: 6 }}>
          <div>{user?.name}</div>
          <div className="muted small">{user?.email}</div>
          <button className="link" style={{ justifyContent: 'flex-start' }} onClick={logout}>
            Выйти
          </button>
        </div>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  )
}
