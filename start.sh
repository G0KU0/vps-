#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║    🐧 Render VPS (Keep-Alive Extreme)   ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Multi-layer aktivitás szimuláció        ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# 0) AGRESSZÍV Keep-Alive (multi-layer)
# ============================================
echo -e "${BLUE}[0/5]${NC} Agresszív keep-alive indítása..."

# Layer 1: Belső HTTP ping (minden 2 percben)
(
  sleep 60
  while true; do
    curl -s http://localhost:${PORT:-10000}/ > /dev/null 2>&1 || true
    sleep 120
  done
) &

# Layer 2: Random CPU aktivitás (alacsony terhelés)
(
  while true; do
    echo "$(date +%s%N)" | sha256sum > /dev/null
    sleep 60
  done
) &

# Layer 3: Memória aktivitás (fájl írás/olvasás)
(
  while true; do
    echo "keepalive-$(date +%s)" > /tmp/ka_$RANDOM.txt
    find /tmp -name "ka_*.txt" -type f 2>/dev/null | head -100 | xargs cat > /dev/null 2>&1
    find /tmp -name "ka_*.txt" -type f -mmin +10 -delete 2>/dev/null
    sleep 180
  done
) &

# Layer 4: Dummy process aktivitás
(
  while true; do
    sleep 300
    ps aux > /dev/null
    df -h > /dev/null
    free -h > /dev/null
  done
) &

# Layer 5: WebSocket ping szimuláció
(
  sleep 30
  while true; do
    timeout 5 curl -s -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
      http://localhost:${PORT:-10000}/ws 2>/dev/null || true
    sleep 180
  done
) &

echo -e "${GREEN}  ✓ 5 rétegű keep-alive aktív${NC}"
echo -e "${YELLOW}  → HTTP ping (2 perc)${NC}"
echo -e "${YELLOW}  → CPU aktivitás (1 perc)${NC}"
echo -e "${YELLOW}  → Fájl I/O (3 perc)${NC}"
echo -e "${YELLOW}  → Process check (5 perc)${NC}"
echo -e "${YELLOW}  → WebSocket ping (3 perc)${NC}"

# ============================================
# 1) SSH szerver indítása
# ============================================
echo ""
echo -e "${BLUE}[1/5]${NC} SSH szerver indítása..."
mkdir -p /run/sshd
/usr/sbin/sshd

SSH_PASSWORD="${SSH_PASSWORD:-render2024}"
echo "root:${SSH_PASSWORD}" | chpasswd

if ps aux | grep -v grep | grep sshd > /dev/null; then
    echo -e "${GREEN}  ✓ SSH szerver fut (port 22)${NC}"
    echo -e "${GREEN}  ✓ Root jelszó: ${SSH_PASSWORD}${NC}"
else
    echo -e "${RED}  ✗ SSH szerver hiba${NC}"
fi

# ============================================
# 1.5) ÚJ: Nginx Webszerver indítása (Weboldal hosztoláshoz)
# ============================================
echo ""
echo -e "${BLUE}[1.5/5]${NC} Nginx webszerver indítása..."
service nginx start
mkdir -p /var/www/html
# Létrehozunk egy alapoldalt a neofetch kimenetével
echo "<html><body style='background:#1a1b26;color:#c0caf5;font-family:monospace;padding:20px;'><pre style='color:#7aa2f7;'>" > /var/www/html/index.html
neofetch --stdout >> /var/www/html/index.html
echo "</pre><hr><h1 style='color:#bb9af7'>Saját weboldal a VPS-en!</h1>" >> /var/www/html/index.html
echo "<p>Ezt a fájlt itt találod: <b>/var/www/html/index.html</b></p></body></html>" >> /var/www/html/index.html

# ============================================
# 2) bore.pub Tunnel (FileZilla SFTP és Weboldal)
# ============================================
echo ""
echo -e "${BLUE}[2/5]${NC} bore.pub tunnel-ek indítása..."

if command -v bore >/dev/null 2>&1; then
    # SFTP Tunnel (22-es port)
    bore local 22 --to bore.pub > /tmp/bore.log 2>&1 &
    # ÚJ: Web Tunnel (80-as port)
    bore local 80 --to bore.pub > /tmp/bore_web.log 2>&1 &
    
    echo -e "  Várakozás a tunnel felépülésére..."
    sleep 8

    BORE_PORT=""
    BORE_WEB_PORT=""
    for i in $(seq 1 10); do
        if [ -f /tmp/bore.log ]; then
            BORE_PORT=$(grep -oP 'listening at bore\.pub:\K[0-9]+' /tmp/bore.log 2>/dev/null | head -1)
        fi
        if [ -f /tmp/bore_web.log ]; then
            BORE_WEB_PORT=$(grep -oP 'listening at bore\.pub:\K[0-9]+' /tmp/bore_web.log 2>/dev/null | head -1)
        fi
        if [ -n "$BORE_PORT" ] && [ -n "$BORE_WEB_PORT" ]; then
            break
        fi
        sleep 2
    done

    if [ -n "$BORE_PORT" ]; then
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  📁 FILEZILLA SFTP ÉS WEBOLDAL INFÓ                          ║${NC}"
        echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Weboldal címe: http://bore.pub:${BORE_WEB_PORT}${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Protocol: SFTP - SSH File Transfer Protocol${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Host: bore.pub${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Port: ${BORE_PORT}${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}User: root${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Pass: ${SSH_PASSWORD}${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        cat > /tmp/ssh-info.txt << EOF
╔══════════════════════════════════════════════════════╗
║  📁 HÁLÓZATI ADATOK                                  ║
╠══════════════════════════════════════════════════════╣
║  Weboldal: http://bore.pub:${BORE_WEB_PORT}
║  SFTP Host: bore.pub
║  SFTP Port: ${BORE_PORT}
║  User: root
║  Pass: ${SSH_PASSWORD}
╚══════════════════════════════════════════════════════╝
EOF
        echo -e "${GREEN}  ✓ bore.pub tunnel aktív${NC}"
    else
        echo -e "${RED}  ✗ bore.pub tunnel hiba${NC}"
    fi
else
    echo -e "${RED}  ✗ bore parancs nincs telepítve${NC}"
fi

# ============================================
# 3) tmate SSH tunnel (PuTTY SSH)
# ============================================
echo ""
echo -e "${BLUE}[3/5]${NC} tmate SSH tunnel (PuTTY-hoz)..."

TMATE_SOCK="/tmp/tmate.sock"
rm -f "$TMATE_SOCK"
tmate -S "$TMATE_SOCK" new-session -d -s main 2>/dev/null

sleep 5
for i in $(seq 1 20); do
    SSH_CMD=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh}' 2>/dev/null)
    if [ -n "$SSH_CMD" ] && [ "$SSH_CMD" != "" ]; then
        TMATE_USER=$(echo "$SSH_CMD" | sed 's/ssh //' | cut -d@ -f1)
        TMATE_HOST=$(echo "$SSH_CMD" | sed 's/ssh //' | cut -d@ -f2)

        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🔐 PUTTY SSH (interaktív terminál)                         ║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}Terminálból (legegyszerűbb):${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}${SSH_CMD}${NC}"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}PUTTY beállítások:${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Host Name: ${TMATE_HOST}${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Port: 22${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Connection → Data → Auto-login username:${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}  ${TMATE_USER}${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Password: (nincs - automatikus belépés)${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        cat >> /tmp/ssh-info.txt << EOF

╔══════════════════════════════════════════════════════╗
║  🔐 PUTTY SSH                                        ║
╠══════════════════════════════════════════════════════╣
║  Host: ${TMATE_HOST}
║  Port: 22
║  User: ${TMATE_USER}
║  Pass: (nincs - automatikus)
║
║  Terminálból:
║    ${SSH_CMD}
╚══════════════════════════════════════════════════════╝
EOF

        echo "$SSH_CMD" > /tmp/tmate-ssh.txt
        echo -e "${GREEN}  ✓ tmate SSH aktív${NC}"
        break
    fi
    sleep 1
done

# ============================================
# 4) Külső ping instrukciók
# ============================================
echo ""
echo -e "${BLUE}[4/5]${NC} Külső ping beállítás (FONTOS!)..."

RENDER_URL="https://vps-2h0l.onrender.com"

echo -e "${YELLOW}  ⚠️  KRITIKUS: Állíts be KÜLSŐ pinget!${NC}"
echo -e ""
echo -e "${CYAN}  URL: ${RENDER_URL}${NC}"
echo -e ""

# ============================================
# 5) Web Terminal indítása
# ============================================
echo ""
echo -e "${BLUE}[5/5]${NC} Web terminal indítása..."

WEB_USER="${WEB_USER:-admin}"
WEB_PASS="${WEB_PASS:-render-vps-2024}"

echo -e "${GREEN}  ✓ Web terminal aktív${NC}"
echo -e "  ${YELLOW}User: ${WEB_USER} | Pass: ${WEB_PASS}${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  🎉 VPS elindult + Weboldal aktív! 🎉${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

exec ttyd \
    -p "${PORT:-10000}" \
    -W \
    -c "${WEB_USER}:${WEB_PASS}" \
    -t fontSize=15 \
    -t fontFamily="'JetBrains Mono', 'Fira Code', monospace" \
    -t 'theme={"background":"#1a1b26","foreground":"#c0caf5","cursor":"#c0caf5"}' \
    -t drawBoldTextInBrightColors=true \
    /bin/bash --login
