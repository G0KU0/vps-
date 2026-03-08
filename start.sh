#!/bin/bash
set -e

BORE_PORT="${BORE_PORT:-48252}"

echo "════════════════════════════════════════"
echo "  🐧 Linux Server + Persistent Procs"
echo "  🔑 Jelszó: 2003"
echo "  📌 Fix SSH port: ${BORE_PORT}"
echo "════════════════════════════════════════"

# ── Jelszavak ──
echo 'root:2003' | chpasswd
echo 'admin:2003' | chpasswd

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

# ── Cleanup ──
apt-get clean 2>/dev/null || true
find /tmp -type f -mtime +1 -delete 2>/dev/null || true
echo "[OK] Cleanup kész"

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

# ── Keep-Alive ──
cat > /usr/local/bin/keep-alive.sh << 'KEEPALIVE'
#!/bin/bash
RENDER_URL="${RENDER_EXTERNAL_URL:-}"
echo "[KEEP-ALIVE] Indítás... URL: $RENDER_URL"
while true; do
    sleep 300
    echo "[KEEP-ALIVE] Ping: $(date '+%H:%M:%S')"
    [ -n "$RENDER_URL" ] && curl -s -o /dev/null "$RENDER_URL" 2>/dev/null || true
    curl -s -o /dev/null "http://127.0.0.1:6969" 2>/dev/null || true
done
KEEPALIVE
chmod +x /usr/local/bin/keep-alive.sh

# ── SFTP frissítő ──
cat > /usr/local/bin/update-sftp.sh << SCRIPT
#!/bin/bash
while sleep 5; do
    if [ -f /var/log/bore.log ] && grep -q 'bore\.pub' /var/log/bore.log 2>/dev/null; then
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

Frissítve: \$(date '+%H:%M:%S')
EOF
    fi
done
SCRIPT
chmod +x /usr/local/bin/update-sftp.sh

# ── Auto cleanup ──
cat > /usr/local/bin/auto-cleanup.sh << 'AUTOCLEAN'
#!/bin/bash
while true; do
    [ "$(date +%H)" -eq 3 ] && /usr/local/bin/cleanup.sh >> /var/log/cleanup.log 2>&1 && sleep 3600
    sleep 300
done
AUTOCLEAN
chmod +x /usr/local/bin/auto-cleanup.sh

echo "[INFO] Supervisord indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
