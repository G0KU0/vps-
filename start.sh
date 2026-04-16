#!/bin/bash
set -e

BORE_PORT="${BORE_PORT:-20020}"

echo "════════════════════════════════════════"
echo "  🐧 Linux Server + Persistent Procs"
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
mkdir -p /root/.persistent-cmds
mkdir -p /var/log/user-processes
echo "[OK] Könyvtárak kész"

# ── Indításkori cleanup ──
echo "[INFO] Indításkori memória tisztítás..."
apt-get clean 2>/dev/null || true
journalctl --vacuum-size=50M 2>/dev/null || true
find /tmp -type f -mtime +1 -delete 2>/dev/null || true
pip3 cache purge 2>/dev/null || true
echo "[OK] Cleanup kész"

# ── SFTP info ──
cat > /var/www/html/sftp.txt << EOF
Tunnel indítása (port: ${BORE_PORT})...
Várj 15 másodpercet!

ssh root@bore.pub -p ${BORE_PORT}
Jelszó: 2003
EOF

# ── Bore wrapper script ──
cat > /usr/local/bin/bore-wrapper.sh << BORESCRIPT
#!/bin/bash
echo "[BORE] Fix port: ${BORE_PORT}"

while true; do
    echo "[BORE] \$(date '+%H:%M:%S') Csatlakozás bore.pub:${BORE_PORT}..."
    /usr/local/bin/bore local 22 --to bore.pub --port ${BORE_PORT} 2>&1
    echo "[BORE] \$(date '+%H:%M:%S') Megszakadt, újra 5mp múlva..."
    sleep 5
done
BORESCRIPT

chmod +x /usr/local/bin/bore-wrapper.sh

# ── Keep-Alive script ──
cat > /usr/local/bin/keep-alive.sh << 'KEEPALIVE'
#!/bin/bash
RENDER_URL="${RENDER_EXTERNAL_URL:-}"
echo "[KEEP-ALIVE] Indítás..."
echo "[KEEP-ALIVE] URL: $RENDER_URL"

while true; do
    sleep 300
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[KEEP-ALIVE] Ping: $TIMESTAMP"
    if [ -n "$RENDER_URL" ]; then
        curl -s -o /dev/null -w "External: %{http_code}\n" "$RENDER_URL" 2>/dev/null || true
    fi
    curl -s -o /dev/null "http://127.0.0.1:6969" 2>/dev/null || true
    echo "[KEEP-ALIVE] OK"
done
KEEPALIVE

chmod +x /usr/local/bin/keep-alive.sh

# ── SFTP frissítő ──
cat > /usr/local/bin/update-sftp.sh << SCRIPT
#!/bin/bash
while sleep 5; do
    if [ -f /var/log/bore.log ]; then
        if grep -q 'bore\.pub' /var/log/bore.log 2>/dev/null; then
            PROC_COUNT=\$(ls /etc/supervisor/conf.d/user-*.conf 2>/dev/null | wc -l)
            SCREEN_COUNT=\$(screen -list 2>/dev/null | grep -c "\..*(" || echo 0)
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

🚀 Persistent processek: \${PROC_COUNT}
📺 Screen session-ök: \${SCREEN_COUNT}

✅ Keep-Alive AKTÍV
   Szerver 24/7 fut!

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
