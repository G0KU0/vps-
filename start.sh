#!/bin/bash
set -e

echo "════════════════════════════════════════"
echo "  🐧 SSH Server Indítás"
echo "════════════════════════════════════════"

# ── Jelszavak ──
export SSH_PASSWORD="${SSH_PASSWORD:-2003}"
echo "root:$SSH_PASSWORD" | chpasswd
echo "admin:$SSH_PASSWORD" | chpasswd
echo "[OK] Jelszó: $SSH_PASSWORD"

# ── SSH teszt ──
/usr/sbin/sshd -t && echo "[OK] SSH config rendben" || echo "[WARN] SSH config hiba"

# ── Info fájl ──
cat > /var/www/html/tunnel.txt << 'EOF'
═══════════════════════════════════════════
      ⏳ TUNNEL INDÍTÁSA...
═══════════════════════════════════════════
Várj 10-15 másodpercet, majd frissítsd!
Jelszó: 2003
EOF

# ── Tunnel frissítő ──
cat > /usr/local/bin/update-tunnel.sh << 'SCRIPT'
#!/bin/bash
while sleep 5; do
    if [ -f /var/log/bore.log ]; then
        ADDR=$(grep -oE 'bore\.pub:[0-9]+' /var/log/bore.log 2>/dev/null | tail -1)
        if [ -n "$ADDR" ]; then
            HOST=$(echo "$ADDR" | cut -d: -f1)
            PORT=$(echo "$ADDR" | cut -d: -f2)
            cat > /var/www/html/tunnel.txt << EOF
═══════════════════════════════════════════
      ✅ SSH SERVER AKTÍV!
═══════════════════════════════════════════

SSH CSATLAKOZÁS:
  ssh root@${HOST} -p ${PORT}
  
  Jelszó: 2003

FILEZILLA (SFTP):
  Protocol: SFTP
  Host: ${HOST}
  Port: ${PORT}
  User: root
  Pass: 2003

TERMINAL:
  ssh root@${HOST} -p ${PORT}

Ha problémád van:
  ssh -v root@${HOST} -p ${PORT}

Felhasználók: root, admin
Jelszó: 2003
Frissítve: $(date '+%H:%M:%S')

═══════════════════════════════════════════
EOF
        fi
    fi
done
SCRIPT

chmod +x /usr/local/bin/update-tunnel.sh

# ── Supervisord ──
echo "[INFO] Supervisord indítása..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
