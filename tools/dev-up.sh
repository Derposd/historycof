#!/usr/bin/env bash
# Поднять всё локально в свежем контейнере Claude Code (или на Linux-машине разработчика):
# PostgreSQL 16, зависимости, API на :3000 с данными, админку на :5173.
#
#   tools/dev-up.sh            # backend + admin
#   tools/dev-up.sh --flutter  # плюс Flutter SDK в /opt/sdk/flutter (≈1 ГБ, для flutter test/analyze)
#
# Повторный запуск безопасен: уже установленное и запущенное пропускается.
# Вход в локальную админку: admin@historycoffee.ru / change-me-please (только локально).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG=/tmp/hc-dev && mkdir -p "$LOG"
PG_BIN=/usr/lib/postgresql/16/bin
PG_DATA=/var/lib/pg-hc/data
say() { printf '\n== %s\n' "$1"; }

say "PostgreSQL"
if [ ! -x "$PG_BIN/pg_ctl" ]; then
  echo "Нет PostgreSQL 16: apt-get install -y postgresql-16" >&2; exit 1
fi
if [ ! -s "$PG_DATA/PG_VERSION" ]; then
  mkdir -p "$PG_DATA" && chown -R postgres:postgres /var/lib/pg-hc
  su postgres -c "$PG_BIN/initdb -D $PG_DATA -A trust -U postgres" >"$LOG/initdb.log"
fi
if ! "$PG_BIN/pg_isready" -q -h /tmp; then
  su postgres -c "$PG_BIN/pg_ctl -D $PG_DATA -l /var/lib/pg-hc/pg.log -o '-k /tmp' -w start" >/dev/null
fi
psql() { su postgres -c "psql -h /tmp -tAc \"$1\""; }
[ "$(psql "select 1 from pg_roles where rolname='history'")" = 1 ] \
  || psql "create role history login password 'history' createdb"
for db in history history_test; do
  [ "$(psql "select 1 from pg_database where datname='$db'")" = 1 ] || psql "create database $db owner history"
done
echo "готово: postgres://history:history@localhost:5432/history (+ history_test для e2e)"

say "Зависимости"
for app in backend admin; do
  [ -d "$ROOT/$app/node_modules" ] || (cd "$ROOT/$app" && npm ci --no-audit --no-fund >"$LOG/npm-$app.log")
  echo "$app: ok"
done

say "API"
cd "$ROOT/backend"
npm run build >"$LOG/build.log" 2>&1
node dist/db/migrate.js >"$LOG/migrate.log" 2>&1
node dist/db/seed.js >"$LOG/seed.log" 2>&1
if ! curl -fs localhost:3000/health >/dev/null 2>&1; then
  ADMIN_BOOTSTRAP_EMAIL=admin@historycoffee.ru ADMIN_BOOTSTRAP_PASSWORD=change-me-please PORT=3000 \
    nohup node dist/main.js >"$LOG/api.log" 2>&1 &
  for _ in $(seq 1 30); do curl -fs localhost:3000/health >/dev/null 2>&1 && break; sleep 1; done
fi
curl -fs localhost:3000/health >/dev/null && echo "http://localhost:3000/api/v1 (лог: $LOG/api.log)"

say "Админка"
cd "$ROOT/admin"
if ! curl -fs -o /dev/null localhost:5173/ 2>/dev/null; then
  API_PROXY=http://localhost:3000 nohup npx vite --port 5173 --strictPort >"$LOG/vite.log" 2>&1 &
  for _ in $(seq 1 30); do curl -fs -o /dev/null localhost:5173/ 2>/dev/null && break; sleep 1; done
fi
curl -fs -o /dev/null localhost:5173/ && echo "http://localhost:5173 (admin@historycoffee.ru / change-me-please)"

if [ "${1:-}" = "--flutter" ]; then
  say "Flutter"
  if [ ! -x /opt/sdk/flutter/bin/flutter ]; then
    mkdir -p /opt/sdk && cd /opt/sdk
    curl -fsS -o flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.5-stable.tar.xz
    tar xf flutter.tar.xz && rm flutter.tar.xz
    git config --global --add safe.directory /opt/sdk/flutter
    /opt/sdk/flutter/bin/flutter config --no-analytics >/dev/null 2>&1 || true
  fi
  (cd "$ROOT/mobile" && /opt/sdk/flutter/bin/flutter pub get >"$LOG/pub.log" 2>&1)
  echo "export PATH=/opt/sdk/flutter/bin:\$PATH   # затем: cd mobile && flutter test"
fi
