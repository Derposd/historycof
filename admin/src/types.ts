export type StaffRole = 'admin' | 'editor'

export interface StaffUser {
  id: string
  email: string
  name: string
  role: StaffRole
  active?: boolean
  lastLoginAt?: string | null
  createdAt?: string
}

export interface NewsPost {
  id: string
  title: string
  body: string
  imageUrl: string | null
  status: 'draft' | 'published'
  pinned: boolean
  publishedAt: string | null
  pushedAt: string | null
  createdAt: string
  updatedAt: string
}

export type MenuBadge = 'team_choice' | 'bestseller' | 'new' | 'story'

export const BADGE_LABELS: Record<MenuBadge, string> = {
  team_choice: 'Выбор команды',
  bestseller: 'Хит продаж',
  new: 'Новинка',
  story: 'Блюдо с историей',
}

export interface MenuPrice {
  label: string
  amount: number
}

/** Пищевая ценность на порцию (ПП РФ № 1515) */
export interface MenuNutrition {
  kcal?: number | null
  proteins?: number | null
  fats?: number | null
  carbs?: number | null
}

export interface MenuItem {
  id: string
  categoryId: string
  title: string
  description: string | null
  portion: string | null
  imageUrl: string | null
  prices: MenuPrice[]
  badges: MenuBadge[]
  story: string | null
  nutrition: MenuNutrition | null
  allergens: string | null
  available: boolean
  sort: number
}

export interface MenuCategory {
  id: string
  sectionId: string
  title: string
  sort: number
  visible: boolean
  items: MenuItem[]
}

export interface MenuSection {
  id: string
  slug: string
  title: string
  sort: number
  categories: MenuCategory[]
}

export type FeedbackType = 'complaint' | 'suggestion' | 'thanks'
export type FeedbackStatus = 'sent' | 'viewed' | 'answered'

export const FEEDBACK_TYPE_LABELS: Record<FeedbackType, string> = {
  complaint: 'Жалоба',
  suggestion: 'Предложение',
  thanks: 'Благодарность',
}

export const FEEDBACK_STATUS_LABELS: Record<FeedbackStatus, string> = {
  sent: 'Новое',
  viewed: 'Просмотрено',
  answered: 'Отвечено',
}

export interface Feedback {
  id: string
  guestId: string | null
  guestPhone: string | null
  guestName: string | null
  type: FeedbackType
  message: string
  photoUrl: string | null
  contactPhone: string | null
  status: FeedbackStatus
  reply: string | null
  createdAt: string
  viewedAt: string | null
  answeredAt: string | null
}

export interface DayHours {
  day: number
  open: string | null
  close: string | null
}

export interface Venue {
  name: string
  tagline: string
  address: string
  lat: number | null
  lng: number | null
  phone: string
  whatsapp: string
  website: string
  hours: DayHours[]
  legalName: string
  inn: string
  ogrn: string
  legalAddress: string
  privacyEmail: string
}

export interface AnalyticsSummary {
  guests: { total: number; new30d: number; active7d: number; loyaltyLinked: number }
  devices: number
  /** Гости с согласием на рекламу — получат новости уведомлением */
  marketingSubscribers: number
  newsPublished: number
  menuItems: number
  feedback: { open: number; last30dByType: { type: FeedbackType; n: number }[] }
  signupsByDay: { day: string; n: number }[]
}

// ─── Чат с гостями ───

export interface ChatMessage {
  id: string
  /** true — написала кофейня, false — гость */
  fromStaff: boolean
  text: string
  createdAt: string
  readAt: string | null
}

export interface ChatThread {
  guestId: string
  guestName: string | null
  guestPhone: string | null
  lastText: string
  lastFromStaff: boolean
  lastAt: string
  unread: number
}
