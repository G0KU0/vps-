#!/bin/bash
set -e

echo "════════════════════════════════════════"
echo "  🐧 SSH Server - Port 6969"
echo "  🔑 Password: 2003"
echo "════════════════════════════════════════"

# ── Jelszó beállítása ──
export SSH_PASSWORD="${SSH_PASSWORD:-2003}"
echo "root:$SSH_PASSWORD" | chpasswd
echo "admin:$SSH_PASSWORD" | chpasswd
echo "[OK] Jelszavak beállítva: $SSH_PASSWORD"

# ── SSH daemon tesztelés ──
echo "[INFO] SSH daemon tesztelése..."
/usr/sbin/sshd -t
if [ $? -eq 0 ]; then
    echo "[OK] SSH konfig helyes"
else
    echo "[HIBA] SSH konfig probléma!"
fi

# ── Publikus IP ──
PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
echo "[INFO] IP: $PUBLIC_IP"

# ── Info fájl ──
cat > /var/www/html/tunnel.txt << 'EOF'
═══════════════════════════════════════════════════
           🐧 SSH SERVER INDÍTÁSA...
═══════════════════════════════════════════════════

⏳ Tunnel létrehozása folyamatban...
⏳ Kérlek várj 15-30 másodpercet!
📡 Frissítsd az oldalt!

Jelszó: 2003
Felhasználók: root, admin

═══════════════════════════════════════════════════
EOF

# ── Tunnel frissítő ──
cat > /usr/local/bin/update-tunnel.sh << 'UPDATER'
#!/bin/bash

LOGFILE="/var/log/tunnel.log"

while true; do
    # ngrok log ellenőrzése
    if [ -f "$LOGFILE" ]; then
        TUNNEL=$(grep -oE 'tcp://[0-9]+\.tcp\.[a-z]+\.ngrok\.io:[0-9]+' "$LOGFILE" 2>/dev/null | tail -1)
        
        if [ -n "$TUNNEL" ]; then
            # ngrok formátum: tcp://0.tcp.eu.ngrok.io:12345
            HOST=$(echo "$TUNNEL" | sed 's|tcp://||' | cut -d: -f1)
            PORT=$(echo "$TUNNEL" | sed 's|tcp://||' | cut -d: -f2)
            
            cat > /var/www/html/tunnel.txt << EOF
═══════════════════════════════════════════════════
           ✅ SSH SERVER AKTÍV!
═══════════════════════════════════════════════════

SSH CSATLAKOZÁS:
  ssh root@${HOST} -p ${PORT}

JELSZÓ: 2003

FILEZILLA (SFTP):
  Protocol: SFTP
  Host: ${HOST}
  Port: ${PORT}
  User: root
  Pass: 2003

PUTTY:
  Host: ${HOST}
  Port: ${PORT}
  Connection: SSH
  User: root
  Pass: 2003

TERMINAL PARANCS:
  ssh root@${HOST} -p ${PORT}

Ha nem megy, próbáld meg:
  ssh -o StrictHostKeyChecking=no root@${HOST} -p ${PORT}

Tunnel: ${TUNNEL}
Frissítve: $(date '+%H:%M:%S')

═══════════════════════════════════════════════════
EOF
        else
            # Bore fallback
            BORE=$(grep -oE 'bore\.pub:[0-9]+' /var/log/bore.log 2>/dev/null | tail -1)
            if [ -n "$BORE" ]; then
                HOST=$(echo "$BORE" | cut -d: -f1)
                PORT=$(echo "$BORE" | cut -d: -f2)
                
                cat > /var/www/html/tunnel.txt << EOF
═══════════════════════════════════════════════════
           ✅ SSH SERVER AKTÍV (BORE)!
═══════════════════════════════════════════════════

SSH: ssh root@${HOST} -p ${PORT}
Jelszó: 2003

SFTP (FileZilla):
  Host: ${HOST}
  Port: ${PORT}
  User: root
  Pass: 2003

Frissítve: $(date '+%H:%M:%S')
═══════════════════════════════════════════════════
EOF
            fi
        fi
    fi
    
    sleep 5
done
UPDATER

chmod +x /usr/local/bin/update-tunnel.sh

# ── Supervisord ──
echo "[INFO] Szolgáltatások indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
