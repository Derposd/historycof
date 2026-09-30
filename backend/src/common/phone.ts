/**
 * Нормализует российский номер к формату E.164 (+7XXXXXXXXXX).
 * Принимает «+7 (960) 431-62-23», «8 960 431 62 23», «9604316223».
 * Возвращает null, если номер не распознан.
 */
export function normalizeRuPhone(input: string | null | undefined): string | null {
  if (!input) return null;
  let digits = input.replace(/\D/g, '');
  if (digits.length === 10 && /^[3489]/.test(digits)) digits = `7${digits}`;
  if (digits.length === 11 && digits.startsWith('8')) digits = `7${digits.slice(1)}`;
  if (digits.length !== 11 || !digits.startsWith('7')) return null;
  return `+${digits}`;
}

/**
 * Номер для входа: только российский мобильный (+79…). Требование 149-ФЗ (ст. 10.6,
 * в ред. 406-ФЗ): пользователей из РФ авторизуют по российскому номеру телефона.
 * Номера Казахстана тоже начинаются с +7, но дальше идёт 6 или 7 — их не пускаем.
 */
export function normalizeRuMobile(input: string | null | undefined): string | null {
  const phone = normalizeRuPhone(input);
  return phone && phone.startsWith('+79') ? phone : null;
}

/** +79604316223 → +7 (960) 431-62-23 */
export function formatRuPhone(e164: string): string {
  const d = e164.replace(/\D/g, '');
  if (d.length !== 11) return e164;
  return `+7 (${d.slice(1, 4)}) ${d.slice(4, 7)}-${d.slice(7, 9)}-${d.slice(9, 11)}`;
}

/** Маскирует номер для логов: +7960***6223 */
export function maskPhone(e164: string): string {
  return e164.length > 8 ? `${e164.slice(0, 5)}***${e164.slice(-4)}` : '***';
}
