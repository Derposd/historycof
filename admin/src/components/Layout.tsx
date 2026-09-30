import { useQuery } from '@tanstack/react-query'
import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth-context'
import type { AnalyticsSummary } from '../types'
import { Logo } from './Monogram'
import { AskHost } from './Ask'
import { Toaster } from './ui'

export function Layout() {
  const { user, logout } = useAuth()
  const { pathname } = useLocation()
  // На телефоне меню — выезжающая панель. Она «привязана» к странице, на которой её открыли,
  // поэтому переход по ссылке закрывает её сам.
  const [navFor, setNavFor] = useState<string | null>(null)
  const navOpen = navFor === pathname
  const setNavOpen = (v: boolean) => setNavFor(v ? pathname : null)
  useEffect(() => {
    if (!navOpen) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setNavFor(null)
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [navOpen])

  // Счётчик неотвеченных обращений в меню — обновляется раз в минуту.
  const summary = useQuery({
    queryKey: ['analytics'],
    queryFn: () => api<AnalyticsSummary>('/admin/analytics/summary'),
    refetchInterval: 60_000,
  })
  const open = summary.data?.feedback.open ?? 0
  // Непрочитанные сообщения чата — чаще, гость ждёт ответа
  const chatUnread = useQuery({
    queryKey: ['chat-unread'],
    queryFn: () => api<{ count: number }>('/admin/chats/unread'),
    refetchInterval: 15_000,
  })
  const unread = chatUnread.data?.count ?? 0
  const hasOpen = open > 0 || unread > 0

  // Одна подсветка, которая переезжает к активному пункту меню.
  const navRef = useRef<HTMLElement>(null)
  const [ind, setInd] = useState<{ top: number; height: number } | null>(null)
  const section = '/' + (pathname.split('/')[1] ?? '')
  useLayoutEffect(() => {
    const measure = () => {
      const el = navRef.current?.querySelector<HTMLElement>('.nav-link.active')
      setInd(el ? { top: el.offsetTop, height: el.offsetHeight } : null)
    }
    measure()
    window.addEventListener('resize', measure)
    return () => window.removeEventListener('resize', measure)
  }, [section, user?.role, hasOpen])

  return (
    <div className={`layout${navOpen ? ' nav-open' : ''}`}>
      <header className="topbar">
        <Logo size={34} />
        <span className="spacer" />
        <button
          className="ghost burger"
          aria-label={navOpen ? 'Закрыть меню' : 'Открыть меню'}
          aria-expanded={navOpen}
          aria-controls="sidebar"
          onClick={() => setNavOpen(!navOpen)}
        >
          <span className="burger-lines" aria-hidden="true" />
          {hasOpen && !navOpen && <span className="burger-dot" aria-hidden="true" />}
        </button>
      </header>
      <div className="scrim" onClick={() => setNavOpen(false)} aria-hidden="true" />

      <aside className="sidebar" id="sidebar" ref={navRef}>
        {ind && (
          <span className="nav-indicator" aria-hidden="true" style={{ transform: `translateY(${ind.top}px)`, height: ind.height }} />
        )}
        <Logo size={40} animate />
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
        <NavLink to="/chat" className="nav-link">
          Чат {unread > 0 && <span className="pill terracotta">{unread}</span>}
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
        {/* Ключ по разделу: при переходе страница заново «проявляется»,
            а открытие карточки обращения (/feedback/:id) или диалога (/chat/:id) страницу не перезапускает */}
        <div key={section} className="page">
          <Outlet />
        </div>
      </main>
      <Toaster />
      <AskHost />
    </div>
  )
}
