import { Navigate, Route, Routes } from 'react-router-dom'
import { useAuth } from './auth-context'
import { Layout } from './components/Layout'
import { Loading } from './components/ui'
import { Dashboard } from './pages/Dashboard'
import { Feedback } from './pages/Feedback'
import { Login } from './pages/Login'
import { Menu } from './pages/Menu'
import { News } from './pages/News'
import { Staff } from './pages/Staff'
import { Venue } from './pages/Venue'

export default function App() {
  const { user, loading } = useAuth()
  if (loading) return <Loading />
  if (!user) return <Login />

  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Dashboard />} />
        <Route path="news" element={<News />} />
        <Route path="menu" element={<Menu />} />
        <Route path="feedback" element={<Feedback />} />
        <Route path="feedback/:id" element={<Feedback />} />
        {user.role === 'admin' && <Route path="venue" element={<Venue />} />}
        {user.role === 'admin' && <Route path="staff" element={<Staff />} />}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}
