#!/bin/bash
set -e

BORE_PORT="${BORE_PORT:-48252}"

echo "════════════════════════════════════════"
echo "  🐧 Linux Server + Screen Support"
echo "  🔑 Jelszó: 2003"
echo "  📌 Fix SSH port: ${BORE_PORT}"
echo "════════════════════════════════════════"

# ── Jelszavak ──
echo 'root:2003' | chpasswd
echo 'admin:2003' | chpasswd
echo "[OK] Jelszó: 2003"

# ── Screen könyvtár fix ──
mkdir -p /var/run/screen
chmod 777 /var/run/screen
chmod +t /var/run/screen
mkdir -p /var/log/screen
chmod 777 /var/log/screen
mkdir -p /root/.screen-sessions
echo "[OK] Screen könyvtárak kész"

# ── Cleanup ──
apt-get clean 2>/dev/null || true
find /tmp -type f -mtime +1 -delete 2>/dev/null || true
pip3 cache purge 2>/dev/null || true
echo "[OK] Cleanup kész"

# ── Screen visszaállítás induláskor ──
cat > /usr/local/bin/restore-screens.sh << 'RESTORE'
#!/bin/bash
sleep 10
echo "[RESTORE] Screen session-ök visszaállítása..."
if [ -d /root/.screen-sessions ]; then
    for cmd_file in /root/.screen-sessions/*.cmd 2>/dev/null; do
        [ -f "$cmd_file" ] || continue
        NAME=$(basename "$cmd_file" .cmd)
        COMMAND=$(cat "$cmd_file")
        if ! screen -list 2>/dev/null | grep -q "\.${NAME}[[:space:]]"; then
            echo "[RESTORE] Újraindítás: ${NAME} → ${COMMAND}"
            sstart "$NAME" "$COMMAND"
            sleep 2
        fi
    done
fi
echo "[RESTORE] Kész!"
RESTORE
chmod +x /usr/local/bin/restore-screens.sh

# ── SFTP info ──
cat > /var/www/html/sftp.txt << EOF
Tunnel indítása (port: ${BORE_PORT})...
Várj 15 másodpercet!
ssh root@bore.pub -p ${BORE_PORT}
Jelszó: 2003
EOF

# ── Bore wrapper ──
cat > /usr/local/bin/bore-wrapper.sh << BORESCRIPT
#!/bin/bash
echo "[BORE] Fix port: ${BORE_PORT}"
while true; do
    echo "[BORE] \$(date '+%H:%M:%S') Csatlakozás bore.pub:${BORE_PORT}..."
    /usr/local/bin/bore local 22 --to bore.pub --port ${BORE_PORT} 2>&1
    echo "[BORE] Megszakadt, újra 5mp múlva..."
    sleep 5
done
BORESCRIPT
chmod +x /usr/local/bin/bore-wrapper.sh

# ── Agresszív Keep-Alive ──
cat > /usr/local/bin/keep-alive.sh << 'KEEPALIVE'
#!/bin/bash
RENDER_URL="${RENDER_EXTERNAL_URL:-}"

echo "╔═══════════════════════════════════════════╗"
echo "║  KEEP-ALIVE RENDSZER                      ║"
echo "╚═══════════════════════════════════════════╝"

if [ -z "$RENDER_URL" ]; then
    echo "[KEEP-ALIVE] ⚠️  RENDER_EXTERNAL_URL nincs beállítva"
    echo "[KEEP-ALIVE] ⚠️  Használj UptimeRobot/cron-job.org-ot!"
else
    echo "[KEEP-ALIVE] URL: $RENDER_URL"
fi

FAIL_COUNT=0

while true; do
    sleep 60

    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    if [ -n "$RENDER_URL" ]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 15 \
            -H "User-Agent: KeepAlive/1.0" \
            "$RENDER_URL/health" 2>/dev/null || echo "000")

        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
            echo "[KEEP-ALIVE] ${TIMESTAMP} ✅ External: ${HTTP_CODE}"
            FAIL_COUNT=0
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo "[KEEP-ALIVE] ${TIMESTAMP} ❌ External: ${HTTP_CODE} (fail #${FAIL_COUNT})"
        fi
    fi

    curl -s -o /dev/null --max-time 5 "http://127.0.0.1:6969/health" 2>/dev/null || true

    SCREEN_COUNT=$(screen -list 2>/dev/null | grep -c "\..*(" || echo 0)

    MINUTE=$(date +%M)
    if [ "$((MINUTE % 5))" -eq 0 ]; then
        echo "[KEEP-ALIVE] ══════════════════════════════"
        echo "[KEEP-ALIVE] Screens: ${SCREEN_COUNT}"
        echo "[KEEP-ALIVE] Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
        echo "[KEEP-ALIVE] Uptime: $(uptime -p 2>/dev/null || uptime)"
        echo "[KEEP-ALIVE] Fails: ${FAIL_COUNT}"
        echo "[KEEP-ALIVE] ══════════════════════════════"
    fi
done
KEEPALIVE
chmod +x /usr/local/bin/keep-alive.sh

# ── SFTP frissítő ──
cat > /usr/local/bin/update-sftp.sh << SCRIPT
#!/bin/bash
while sleep 5; do
    if [ -f /var/log/bore.log ]; then
        if grep -q 'bore\.pub' /var/log/bore.log 2>/dev/null; then
            SCREEN_COUNT=\$(screen -list 2>/dev/null | grep -c "\..*(" || echo 0)
            UPTIME=\$(uptime -p 2>/dev/null || uptime | awk '{print \$3,\$4}')
            cat > /var/www/html/sftp.txt << EOF
AKTIV

SSH: ssh root@bore.pub -p ${BORE_PORT}
Jelszó: 2003

FileZilla (SFTP):
  Protocol: SFTP
  Host: bore.pub
  Port: ${BORE_PORT}
  User: root
  Pass: 2003

📌 Fix port: ${BORE_PORT}
📺 Screen session-ök: \${SCREEN_COUNT}
⏱️  Uptime: \${UPTIME}

Frissítve: \$(date '+%H:%M:%S')
EOF
        fi
    fi
done
SCRIPT
chmod +x /usr/local/bin/update-sftp.sh

# ── Auto cleanup ──
cat > /usr/local/bin/auto-cleanup.sh << 'AUTOCLEAN'
#!/bin/bash
while true; do
    CURRENT_HOUR=$(date +%H)
    if [ "$CURRENT_HOUR" -eq 3 ]; then
        echo "[AUTO-CLEANUP] $(date) - Cleanup indítása..."
        /usr/local/bin/cleanup.sh >> /var/log/cleanup.log 2>&1
        echo "[AUTO-CLEANUP] Kész!"
        sleep 3600
    fi
    sleep 300
done
AUTOCLEAN
chmod +x /usr/local/bin/auto-cleanup.sh

echo "[INFO] Supervisord indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
