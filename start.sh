#!/bin/bash
set -e

echo "════════════════════════════════════════"
echo "  🐧 Dropbear SSH + Web Terminal"
echo "  🔑 Jelszó: 2003"
echo "════════════════════════════════════════"

# ── Jelszavak ──
echo 'root:2003' | chpasswd
echo 'admin:2003' | chpasswd
echo "[OK] Jelszó beállítva: 2003"

# ── /dev/pts javítás (PTY terminálhoz kell) ──
echo "[INFO] PTY beállítása..."
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts -o gid=5,mode=620 2>/dev/null || true
chmod 666 /dev/ptmx 2>/dev/null || true
echo "[OK] PTY kész"

# ── Dropbear SSH teszt ──
echo "[INFO] Dropbear SSH teszt..."
dropbear -F -E -p 22 -R -B 2>/dev/null &
DBPID=$!
sleep 1
if kill -0 $DBPID 2>/dev/null; then
    echo "[OK] Dropbear SSH működik"
    kill $DBPID 2>/dev/null
else
    echo "[WARN] Dropbear probléma, de folytatjuk"
fi

# ── SFTP info ──
cat > /var/www/html/sftp.txt << 'EOF'
⏳ Tunnel indítása...
Kérlek várj 15 másodpercet!
Jelszó: 2003
EOF

# ── SFTP frissítő ──
cat > /usr/local/bin/update-sftp.sh << 'SCRIPT'
#!/bin/bash
while sleep 5; do
    if [ -f /var/log/bore.log ]; then
        ADDR=$(grep -oE 'bore\.pub:[0-9]+' /var/log/bore.log 2>/dev/null | tail -1)
        if [ -n "$ADDR" ]; then
            HOST=$(echo "$ADDR" | cut -d: -f1)
            PORT=$(echo "$ADDR" | cut -d: -f2)
            cat > /var/www/html/sftp.txt << EOF
✅ SZERVER AKTÍV!

SSH csatlakozás:
  ssh root@${HOST} -p ${PORT}
  Jelszó: 2003

FileZilla (SFTP):
  Host: ${HOST}
  Port: ${PORT}
  User: root
  Pass: 2003

PuTTY:
  Host: ${HOST}
  Port: ${PORT}
  User: root
  Pass: 2003

Frissítve: $(date '+%H:%M:%S')
EOF
        fi
    fi
done
SCRIPT

chmod +x /usr/local/bin/update-sftp.sh

# ── Supervisord ──
echo "[INFO] Szolgáltatások indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
