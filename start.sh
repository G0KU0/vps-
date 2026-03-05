#!/bin/bash
set -e

echo "════════════════════════════════════════"
echo "  🐧 SSH Server - Port 6969"
echo "  🔑 Password: 2003"
echo "════════════════════════════════════════"

# ── Jelszavak beállítása ──
export SSH_PASSWORD="${SSH_PASSWORD:-2003}"
echo "root:$SSH_PASSWORD" | chpasswd
echo "admin:$SSH_PASSWORD" | chpasswd
echo "[OK] Jelszavak beállítva: $SSH_PASSWORD"

# ── SSH daemon teszt ──
echo "[INFO] SSH konfiguráció ellenőrzése..."
/usr/sbin/sshd -t 2>&1
if [ $? -eq 0 ]; then
    echo "[OK] SSH config rendben"
else
    echo "[HIBA] SSH config probléma - próbálom kijavítani..."
    # Fallback: eredeti config visszaállítása
    if [ -f /etc/ssh/sshd_config.bak ]; then
        cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    fi
fi

# ── Publikus IP ──
PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
echo "[INFO] Publikus IP: $PUBLIC_IP"

# ── Kezdeti info fájl ──
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

# ── Tunnel frissítő script ──
cat > /usr/local/bin/update-tunnel.sh << 'UPDATER'
#!/bin/bash

NGROK_LOG="/var/log/tunnel.log"
BORE_LOG="/var/log/bore.log"

while true; do
    # Ngrok ellenőrzés
    if [ -f "$NGROK_LOG" ]; then
        TUNNEL=$(grep -oE 'tcp://[0-9]+\.tcp\.[a-z]+\.ngrok\.io:[0-9]+' "$NGROK_LOG" 2>/dev/null | tail -1)
        
        if [ -n "$TUNNEL" ]; then
            HOST=$(echo "$TUNNEL" | sed 's|tcp://||' | cut -d: -f1)
            PORT=$(echo "$TUNNEL" | sed 's|tcp://||' | cut -d: -f2)
            
            cat > /var/www/html/tunnel.txt << EOF
═══════════════════════════════════════════════════
           ✅ SSH SERVER AKTÍV! (NGROK)
═══════════════════════════════════════════════════

🔐 SSH CSATLAKOZÁS:

  ssh root@${HOST} -p ${PORT}

  🔑 Jelszó: 2003

─────────────────────────────────────────────────

📂 FILEZILLA (SFTP):

  Protocol: SFTP - SSH File Transfer Protocol
  Host: ${HOST}
  Port: ${PORT}
  User: root (vagy admin)
  Pass: 2003

─────────────────────────────────────────────────

💻 PUTTY BEÁLLÍTÁS:

  Host Name: ${HOST}
  Port: ${PORT}
  Connection type: SSH
  
  Login:
    username: root
    password: 2003

─────────────────────────────────────────────────

🖥️ TERMINAL PARANCS (Linux/Mac):

  ssh root@${HOST} -p ${PORT}

Ha nem megy első próbálkozásra:

  ssh -o StrictHostKeyChecking=no root@${HOST} -p ${PORT}

─────────────────────────────────────────────────

📊 RENDSZER INFO:
  Tunnel: ${TUNNEL}
  Frissítve: $(date '+%Y-%m-%d %H:%M:%S')

═══════════════════════════════════════════════════
EOF
            sleep 5
            continue
        fi
    fi
    
    # Bore fallback
    if [ -f "$BORE_LOG" ]; then
        BORE=$(grep -oE 'bore\.pub:[0-9]+' "$BORE_LOG" 2>/dev/null | tail -1)
        
        if [ -n "$BORE" ]; then
            HOST=$(echo "$BORE" | cut -d: -f1)
            PORT=$(echo "$BORE" | cut -d: -f2)
            
            cat > /var/www/html/tunnel.txt << EOF
═══════════════════════════════════════════════════
           ✅ SSH SERVER AKTÍV! (BORE)
═══════════════════════════════════════════════════

🔐 SSH: ssh root@${HOST} -p ${PORT}
🔑 Jelszó: 2003

📂 SFTP (FileZilla):
   Host: ${HOST}
   Port: ${PORT}
   User: root
   Pass: 2003

Frissítve: $(date '+%H:%M:%S')
═══════════════════════════════════════════════════
EOF
        fi
    fi
    
    sleep 5
done
UPDATER

chmod +x /usr/local/bin/update-tunnel.sh

# ── Supervisord indítása ──
echo "[INFO] Szolgáltatások indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
