import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { api, hasTokens, saveTokens, setUnauthorizedHandler } from './api'
import { AuthContext } from './auth-context'
import type { StaffUser } from './types'


export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<StaffUser | null>(null)
  const [loading, setLoading] = useState(hasTokens())

  useEffect(() => {
    setUnauthorizedHandler(() => setUser(null))
    if (!hasTokens()) return
    api<StaffUser>('/admin/staff/me')
      .then(setUser)
      .catch(() => saveTokens(null))
      .finally(() => setLoading(false))
  }, [])

  const login = useCallback(async (email: string, password: string) => {
    const res = await api<{ accessToken: string; refreshToken: string; user: StaffUser }>('/admin/auth/login', {
      method: 'POST',
      json: { email, password },
    })
    saveTokens(res)
    setUser(res.user)
  }, [])

  const logout = useCallback(async () => {
    try {
      const raw = localStorage.getItem('hc.admin.tokens')
      const refreshToken = raw ? (JSON.parse(raw) as { refreshToken: string }).refreshToken : null
      if (refreshToken) await api('/admin/auth/logout', { method: 'POST', json: { refreshToken } })
    } catch {
      /* выходим локально в любом случае */
    }
    saveTokens(null)
    setUser(null)
  }, [])

  const value = useMemo(() => ({ user, loading, login, logout }), [user, loading, login, logout])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
