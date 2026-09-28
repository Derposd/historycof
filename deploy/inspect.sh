#!/usr/bin/env bash
# Осмотр сервера перед установкой. ТОЛЬКО ЧТЕНИЕ — ничего не меняет.
set +e
section() { printf '\n== %s\n' "$1"; }
section "система";   uname -a; grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release; echo "cpu: $(nproc)"; free -m; df -h / /opt 2>/dev/null
section "пользователь"; id; sudo -n true 2>/dev/null && echo "sudo без пароля: да" || echo "sudo без пароля: нет"
section "docker";    docker --version 2>&1; docker compose version 2>&1
section "контейнеры"; docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>&1
section "compose-проекты"; docker compose ls 2>&1
section "сети docker"; docker network ls 2>&1
section "слушающие порты"; (ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null)
section "веб-серверы"; for s in nginx apache2 caddy traefik; do printf '%s: ' "$s"; systemctl is-active "$s" 2>/dev/null || echo "нет"; done
ls -la /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null
section "файрвол";   ufw status 2>/dev/null | head -30; iptables -S INPUT 2>/dev/null | head -20
section "/opt";      ls -la /opt 2>/dev/null
section "занят ли каталог приложения"; ls -la /opt/history-coffee 2>&1 | head
