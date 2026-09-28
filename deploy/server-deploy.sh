#!/usr/bin/env bash
# Установка/обновление тестового стенда на сервере. Запускается из workflow VPS.
# Трогает только /opt/history-coffee и compose-проект «historycoffee».
set -euo pipefail
APP=/opt/history-coffee
HOST="${HC_HOST:?}"

command -v docker >/dev/null || { echo "STOP: Docker не установлен — сам ставить не буду, нужно согласие владельца"; exit 3; }
docker compose version >/dev/null 2>&1 || { echo "STOP: нет плагина docker compose"; exit 3; }

mkdir -p "$APP"
rm -rf "$APP/src.new" && mkdir "$APP/src.new"
tar xzf /tmp/hc-release.tgz -C "$APP/src.new"
[ -d "$APP/src" ] && mv "$APP/src" "$APP/src.old"
mv "$APP/src.new" "$APP/src"
rm -rf "$APP/src.old"

# Порт: однажды выбранный сохраняется; иначе первый свободный из 8090–8099
if [ -f "$APP/port" ]; then
  PORT=$(cat "$APP/port")
else
  PORT=""
  for p in $(seq 8090 8099); do
    if ! ss -tln | awk '{print $4}' | grep -qE "[:.]$p\$"; then PORT=$p; break; fi
  done
  [ -n "$PORT" ] || { echo "STOP: порты 8090–8099 заняты"; exit 4; }
  echo "$PORT" > "$APP/port"
fi
echo "Порт стенда: $PORT"

echo "== загрузка готовых образов"
gunzip -c /tmp/hc-images.tar.gz | docker load
rm -f /tmp/hc-images.tar.gz

install -m 600 /tmp/hc-secrets.env "$APP/.env"
cat >> "$APP/.env" <<ENV
HC_PORT=$PORT
PUBLIC_URL=http://$HOST:$PORT
ADMIN_URL=http://$HOST:$PORT
CORS_ORIGINS=http://$HOST:$PORT
ENV
rm -f /tmp/hc-secrets.env /tmp/hc-release.tgz

cd "$APP/src/deploy"
dc() { docker compose -p historycoffee -f docker-compose.vps.yml --env-file "$APP/.env" "$@"; }

echo "== запуск"
dc up -d --remove-orphans

echo "== ожидание API"
for i in $(seq 1 90); do
  if curl -fsS "http://127.0.0.1:$PORT/api/v1/venue" >/dev/null 2>&1; then echo "API отвечает"; break; fi
  [ "$i" = 90 ] && { echo "STOP: API не поднялся"; dc ps; dc logs --tail=60 backend; exit 5; }
  sleep 2
done

echo "== демо-фото и стартовое наполнение (только если меню пустое)"
dc exec -T backend mkdir -p /data/uploads/demo
dc cp ../mobile/assets/demo/. backend:/data/uploads/demo/
dc exec -T -e SEED_DEMO=true backend node dist/db/seed.js

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow "$PORT/tcp" comment 'history-coffee' >/dev/null && echo "ufw: открыт порт $PORT"
fi

# Убираем только свои устаревшие образы (по метке), чужие не трогаем
docker image prune -f --filter label=com.historycoffee=1 >/dev/null || true

dc ps
echo "READY http://$HOST:$PORT"
