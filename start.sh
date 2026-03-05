#!/bin/bash
set -e

echo "════════════════════════════════════════════════"
echo "   🐧 LINUX SZERVER INDÍTÁSA"
echo "   📡 Port: 6969"
echo "   🔑 Jelszó: 2003"
echo "════════════════════════════════════════════════"

# ── Jelszó beállítása ──
if [ -z "$SSH_PASSWORD" ]; then
    export SSH_PASSWORD="2003"
fi

echo "[INFO] Jelszó beállítása..."
echo "root:$SSH_PASSWORD" | chpasswd
echo "admin:$SSH_PASSWORD" | chpasswd
echo "[OK] Root és admin jelszó beállítva: $SSH_PASSWORD"

# ── Publikus IP lekérése ──
PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
echo "[INFO] Publikus IP: $PUBLIC_IP"

# ── Info fájl létrehozása ──
cat > /var/www/html/tunnel.txt << EOF
═══════════════════════════════════════════════════════════════════
                🐧 LINUX SZERVER - SSH TUNNEL INFO
═══════════════════════════════════════════════════════════════════

⏳ Tunnel indítása folyamatban...
📡 Frissítsd az oldalt 10 másodperc múlva!

Publikus IP: $PUBLIC_IP
Web Port: 6969
Időbélyeg: $(date)

🔑 SSH/SFTP Jelszó: 2003

Használat:
  ssh root@bore.pub -p [PORT]
  Jelszó: 2003

FileZilla (SFTP):
  Protokoll: SFTP
  Host: bore.pub
  Port: [lásd alább]
  User: root vagy admin
  Pass: 2003

═══════════════════════════════════════════════════════════════════
EOF

# ── Tunnel info frissítő script ──
cat > /usr/local/bin/update-tunnel.sh << 'UPDATER'
#!/bin/bash
while true; do
    if [ -f /var/log/bore.log ]; then
        # Tunnel cím kinyerése
        TUNNEL=$(grep -oE 'bore\.pub:[0-9]+' /var/log/bore.log 2>/dev/null | tail -1)
        
        if [ -n "$TUNNEL" ]; then
            HOST=$(echo "$TUNNEL" | cut -d: -f1)
            PORT=$(echo "$TUNNEL" | cut -d: -f2)
            
            cat > /var/www/html/tunnel.txt << EOF
═══════════════════════════════════════════════════════════════════
                🐧 LINUX SZERVER - SSH TUNNEL INFO
═══════════════════════════════════════════════════════════════════

✅ TUNNEL AKTÍV!

╔═══════════════════════════════════════════════════════════════╗
║                    SSH CSATLAKOZÁS                            ║
╚═══════════════════════════════════════════════════════════════╝

  ssh root@${HOST} -p ${PORT}
  
  Vagy admin felhasználóval:
  ssh admin@${HOST} -p ${PORT}

  🔑 Jelszó (mindkettő): 2003

╔═══════════════════════════════════════════════════════════════╗
║                 FILEZILLA (SFTP) BEÁLLÍTÁS                    ║
╚═══════════════════════════════════════════════════════════════╝

  Protokoll:  SFTP - SSH File Transfer Protocol
  Host:       ${HOST}
  Port:       ${PORT}
  User:       root  (vagy admin)
  Password:   2003

╔═══════════════════════════════════════════════════════════════╗
║                     PUTTY BEÁLLÍTÁS                           ║
╚═══════════════════════════════════════════════════════════════╝

  Host Name (or IP address): ${HOST}
  Port: ${PORT}
  Connection type: SSH
  
  Bejelentkezés:
    login as: root
    password: 2003

╔═══════════════════════════════════════════════════════════════╗
║                    MOBAXTERM BEÁLLÍTÁS                        ║
╚═══════════════════════════════════════════════════════════════╝

  Session → SSH
  Remote host: ${HOST}
  Port: ${PORT}
  Username: root
  Password: 2003

╔═══════════════════════════════════════════════════════════════╗
║                   HASZNOS SSH PARANCSOK                       ║
╚═══════════════════════════════════════════════════════════════╝

  neofetch                    - Rendszer információ
  htop                        - Folyamatok megtekintése
  cd /var/www/html            - Weboldal mappa
  nano /var/www/html/index.html  - Weboldal szerkesztése
  ls -la                      - Fájlok listázása
  df -h                       - Tárhely info
  free -h                     - Memória info
  whoami                      - Aktuális felhasználó
  pwd                         - Aktuális mappa
  
╔═══════════════════════════════════════════════════════════════╗
║                  WEBOLDAL SZERKESZTÉSE                        ║
╚═══════════════════════════════════════════════════════════════╝

  1. FileZilla-val csatlakozz (fenti beállításokkal)
  2. Menj a /var/www/html/ mappába
  3. Húzd be a HTML/CSS/JS fájlokat
  4. Azonnal elérhető: https://linux-server-XXXX.onrender.com

  Vagy SSH-ban:
    nano /var/www/html/index.html
    
╔═══════════════════════════════════════════════════════════════╗
║                    RENDSZER INFORMÁCIÓ                        ║
╚═══════════════════════════════════════════════════════════════╝

  Publikus IP: $(curl -s ifconfig.me 2>/dev/null || echo "N/A")
  Web Port: 6969
  SSH Tunnel: ${HOST}:${PORT}
  Felhasználók: root, admin
  Jelszó: 2003
  
  Utolsó frissítés: $(date)

═══════════════════════════════════════════════════════════════════
EOF
        fi
    fi
    sleep 10
done
UPDATER

chmod +x /usr/local/bin/update-tunnel.sh

# ── Supervisord indítása ──
echo "[INFO] Supervisord indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
