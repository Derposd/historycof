#!/usr/bin/env bash
# Проверка стенда снаружи (запускается на раннере GitHub): как его увидит телефон.
# Пароли берутся из расшифрованного env-файла и в лог не выводятся.
set -euo pipefail
BASE="$1"; ENV_FILE="$2"
ADMIN_EMAIL=$(grep '^ADMIN_BOOTSTRAP_EMAIL=' "$ENV_FILE" | cut -d= -f2-)
ADMIN_PASS=$(grep '^ADMIN_BOOTSTRAP_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)
echo "::add-mask::$ADMIN_PASS"
ok() { echo "✓ $1"; }
j() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

curl -fsS -m 20 -o /dev/null "$BASE/" && ok "админка открывается снаружи"
curl -fsS -m 20 "$BASE/api/v1/menu" | j "'меню: ' + ', '.join(s['title']+' ('+str(sum(len(c['items']) for c in s['categories']))+')' for s in d['sections'])"
curl -fsS -m 20 -o /dev/null "$(curl -fsS "$BASE/api/v1/menu" | j "[i['imageUrl'] for s in d['sections'] for c in s['categories'] for i in c['items'] if i['imageUrl']][0]")" && ok "фото блюд отдаются"

ADMIN_TOKEN=$(curl -fsS -m 20 -H 'Content-Type: application/json' -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" "$BASE/api/v1/admin/auth/login" | j "d['accessToken']")
echo "::add-mask::$ADMIN_TOKEN"
ok "вход администратора"

for pair in "+79990000001:2580" "+79990000002:1470"; do
  PHONE=${pair%%:*}; CODE=${pair##*:}
  curl -fsS -m 20 -H 'Content-Type: application/json' -d "{\"phone\":\"$PHONE\"}" "$BASE/api/v1/auth/otp/request" >/dev/null
  TOKEN=$(curl -fsS -m 20 -H 'Content-Type: application/json' -d "{\"phone\":\"$PHONE\",\"code\":\"$CODE\",\"acceptPrivacyPolicy\":true}" "$BASE/api/v1/auth/otp/verify" | j "d['accessToken']")
  echo "::add-mask::$TOKEN"
  BAL=$(curl -fsS -m 20 -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/loyalty" | j "d['balance']")
  ok "клиент $PHONE: вход по коду, бонусная карта, баланс $BAL"
done

curl -fsS -m 20 -H "Authorization: Bearer $TOKEN" -F type=suggestion -F "message=Проверка стенда: обращение от тестового клиента" "$BASE/api/v1/feedback" >/dev/null
N=$(curl -fsS -m 20 -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE/api/v1/admin/feedback?page=0&pageSize=30" | j "sum(1 for f in d['items'] if f['message'].startswith('Проверка стенда'))")
[ "$N" -ge 1 ] && ok "обращение клиента видно в админке"

# Чат: клиент пишет — сообщение видно в админке (открытие диалога отмечает его прочитанным)
curl -fsS -m 20 -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"text":"Проверка стенда: сообщение в чат"}' "$BASE/api/v1/chat" >/dev/null
GID=$(curl -fsS -m 20 -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE/api/v1/admin/chats" | j "next(t['guestId'] for t in d if t['lastText'].startswith('Проверка стенда'))")
curl -fsS -m 20 -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE/api/v1/admin/chats/$GID" >/dev/null && ok "сообщение в чат видно в админке"
