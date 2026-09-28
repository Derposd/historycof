/**
 * Клиент API админки. Токены сотрудника хранятся в localStorage;
 * при 401 выполняется одна попытка обновить пару через refresh-токен.
 */
const BASE = (import.meta.env.VITE_API_URL as string | undefined) ?? '/api/v1'
const STORAGE_KEY = 'hc.admin.tokens'

export class ApiError extends Error {
  status: number
  code?: string

  constructor(status: number, message: string, code?: string) {
    super(message)
    this.status = status
    this.code = code
  }
}

interface Tokens {
  accessToken: string
  refreshToken: string
}

function readTokens(): Tokens | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? (JSON.parse(raw) as Tokens) : null
  } catch {
    return null
  }
}

export function saveTokens(t: Tokens | null) {
  try {
    if (t) localStorage.setItem(STORAGE_KEY, JSON.stringify({ accessToken: t.accessToken, refreshToken: t.refreshToken }))
    else localStorage.removeItem(STORAGE_KEY)
  } catch {
    /* приватный режим — живём без сохранения */
  }
}

export function hasTokens() {
  return readTokens() !== null
}

let onUnauthorized: () => void = () => {}
export function setUnauthorizedHandler(fn: () => void) {
  onUnauthorized = fn
}

let refreshing: Promise<boolean> | null = null

async function refresh(): Promise<boolean> {
  const t = readTokens()
  if (!t) return false
  refreshing ??= (async () => {
    try {
      const res = await fetch(`${BASE}/admin/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: t.refreshToken }),
      })
      if (!res.ok) return false
      saveTokens((await res.json()) as Tokens)
      return true
    } catch {
      return false
    } finally {
      setTimeout(() => (refreshing = null), 0)
    }
  })()
  return refreshing
}

async function parseError(res: Response): Promise<ApiError> {
  let body: { message?: string | string[]; error?: string } = {}
  try {
    body = await res.json()
  } catch {
    /* пустое тело */
  }
  const msg = Array.isArray(body.message) ? body.message[0] : body.message
  return new ApiError(res.status, msg || `Ошибка ${res.status}`, body.error)
}

export async function api<T>(path: string, init: RequestInit & { json?: unknown } = {}, retried = false): Promise<T> {
  const headers = new Headers(init.headers)
  const t = readTokens()
  if (t) headers.set('Authorization', `Bearer ${t.accessToken}`)
  let body = init.body
  if (init.json !== undefined) {
    headers.set('Content-Type', 'application/json')
    body = JSON.stringify(init.json)
  }

  let res: Response
  try {
    res = await fetch(`${BASE}${path}`, { ...init, headers, body })
  } catch {
    throw new ApiError(0, 'Нет соединения с сервером')
  }

  if (res.status === 401 && t && !retried && !path.startsWith('/admin/auth/')) {
    if (await refresh()) return api<T>(path, init, true)
    saveTokens(null)
    onUnauthorized()
  }
  if (!res.ok) throw await parseError(res)
  if (res.status === 204) return undefined as T
  return (await res.json()) as T
}

export async function uploadImage(file: File, folder: 'news' | 'menu'): Promise<string> {
  const form = new FormData()
  form.append('file', file)
  const { url } = await api<{ url: string }>(`/admin/uploads?folder=${folder}`, { method: 'POST', body: form })
  return url
}
