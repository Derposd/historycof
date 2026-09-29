#!/usr/bin/env bash
# Резервные копии тестового стенда: база и загруженные фото. Запускается из workflow VPS
# (или автоматически перед каждым деплоем). Трогает только /opt/history-coffee
# и compose-проект «historycoffee» — соседние приложения сервера не затрагиваются.
#
#   backup [метка]  — снять копию в /opt/history-coffee/backups/<дата>-<метка>
#   restore <имя>   — вернуть базу и фото из копии (перед этим снимается копия before-restore)
#   list            — показать копии
set -euo pipefail
APP=/opt/history-coffee
DIR=$APP/backups
KEEP=15
[ -f "$APP/.env" ] && [ -d "$APP/src/deploy" ] || { echo "STOP: стенд не установлен"; exit 3; }
cd "$APP/src/deploy"
dc() { docker compose -p historycoffee -f docker-compose.vps.yml --env-file "$APP/.env" "$@"; }

list() {
  echo "== копии на сервере (новые сверху)"
  for b in $(ls -1t "$DIR" 2>/dev/null); do
    [ -f "$DIR/$b/db.sql.gz" ] || continue
    echo "  $b   $(du -sh "$DIR/$b" | cut -f1)   версия: $(cat "$DIR/$b/revision" 2>/dev/null || echo '?')"
  done
}

backup() {
  local label name tmp
  label=$(printf '%s' "${1:-manual}" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-40)
  name="$(date -u +%Y%m%d-%H%M%S)-$label"
  tmp="$DIR/.$name"
  mkdir -p "$tmp" && chmod 700 "$DIR"
  dc exec -T db pg_dump -U history --no-owner history | gzip -6 > "$tmp/db.sql.gz"
  gunzip -c "$tmp/db.sql.gz" | grep -q 'CREATE TABLE' || { rm -rf "$tmp"; echo "STOP: пустой дамп базы"; exit 5; }
  dc exec -T backend tar czf - -C /data uploads > "$tmp/uploads.tgz"
  cp "$APP/src/REVISION" "$tmp/revision" 2>/dev/null || echo "?" > "$tmp/revision"
  mv "$tmp" "$DIR/$name"
  # Храним последние $KEEP копий
  ls -1dt "$DIR"/*/ 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -rf
  echo "BACKUP $name"
}

wait_api() {
  local port; port=$(cat "$APP/port")
  for i in $(seq 1 90); do
    curl -fsS "http://127.0.0.1:$port/api/v1/venue" >/dev/null 2>&1 && { echo "API отвечает"; return; }
    [ "$i" = 90 ] && { echo "STOP: API не поднялся"; dc logs --tail=60 backend; exit 6; }
    sleep 2
  done
}

case "${1:-list}" in
  backup)
    backup "${2:-manual}"
    list
    ;;
  restore)
    name="${2:?укажите имя копии}"
    [ -f "$DIR/$name/db.sql.gz" ] || { echo "STOP: нет копии $name"; list; exit 4; }
    echo "== страховочная копия текущего состояния"
    backup before-restore
    echo "== фото"
    dc exec -T backend sh -c 'find /data/uploads -mindepth 1 -delete && tar xzf - -C /data' < "$DIR/$name/uploads.tgz"
    echo "== база (одной транзакцией: при ошибке останется как было)"
    dc stop backend
    if ! { echo 'DROP SCHEMA IF EXISTS drizzle CASCADE; DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
      gunzip -c "$DIR/$name/db.sql.gz"; } \
      | dc exec -T db psql -q -1 -v ON_ERROR_STOP=1 -U history history >/dev/null; then
      dc start backend
      echo "STOP: база не восстановилась, осталась прежней"; exit 7
    fi
    dc start backend
    wait_api
    echo "RESTORED $name"
    list
    ;;
  list) list ;;
  *) echo "Использование: backup [метка] | restore <имя> | list"; exit 1 ;;
esac
