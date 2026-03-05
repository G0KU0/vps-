#!/bin/bash
set -e

echo "════════════════════════════════════════════════"
echo "   🐧 LINUX SZERVER INDÍTÁSA"
echo "════════════════════════════════════════════════"

# ── Publikus IP lekérése ──
PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
echo "[INFO] Publikus IP: $PUBLIC_IP"

# ── Info fájl létrehozása ──
cat > /var/www/html/tunnel.txt << EOF
═══════════════════════════════════════════════════════
            🐧 LINUX SZERVER - SSH TUNNEL INFO
═══════════════════════════════════════════════════════

⏳ Tunnel indítása folyamatban...
📡 Frissítsd az oldalt 10 másodperc múlva!

Publikus IP: $PUBLIC_IP
Időbélyeg: $(date)

Használat:
  ssh root@bore.pub -p [PORT]
  Jelszó: Linux2024!

FileZilla (SFTP):
  Protokoll: SFTP
  Host: bore.pub
  Port: [lásd alább]
  User: root
  Pass: Linux2024!

═══════════════════════════════════════════════════════
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
═══════════════════════════════════════════════════════
            🐧 LINUX SZERVER - SSH TUNNEL INFO
═══════════════════════════════════════════════════════

✅ TUNNEL AKTÍV!

SSH csatlakozás:
  ssh root@${HOST} -p ${PORT}
  
  Vagy admin felhasználóval:
  ssh admin@${HOST} -p ${PORT}

Jelszó (mindkettő): Linux2024!

FileZilla (SFTP) beállítás:
  ┌─────────────────────────────────────┐
  │ Protokoll:  SFTP                    │
  │ Host:       ${HOST}                 │
  │ Port:       ${PORT}                 │
  │ User:       root (vagy admin)       │
  │ Password:   Linux2024!              │
  └─────────────────────────────────────┘

PuTTY beállítás:
  Host Name: ${HOST}
  Port: ${PORT}
  Connection type: SSH
  Login as: root
  Password: Linux2024!

Gyors parancsok SSH-ban:
  neofetch              - Rendszer info
  htop                  - Folyamatok
  cd /var/www/html      - Weboldal mappa
  nano index.html       - Szerkesztés
  ls -la                - Fájlok listázása

Utolsó frissítés: $(date)
═══════════════════════════════════════════════════════
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
