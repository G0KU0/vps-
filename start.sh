#!/bin/bash

# Színek
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║        🐧 Render Linux VPS 🐧           ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Web Terminal + SSH Tunnel (PuTTY OK!)   ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# 1) SSH szerver indítása + jelszó beállítás
# ============================================
echo -e "${BLUE}[1/4]${NC} SSH szerver indítása..."
service ssh start

# ROOT jelszó beállítása (PuTTY-hoz)
SSH_PASSWORD="${SSH_PASSWORD:-render2024}"
echo "root:${SSH_PASSWORD}" | chpasswd

echo -e "${GREEN}  ✓ SSH szerver fut (port 22)${NC}"
echo -e "${GREEN}  ✓ Root user: root${NC}"
echo -e "${GREEN}  ✓ Root jelszó: ${SSH_PASSWORD}${NC}"

# ============================================
# 2) Cloudflare Tunnel (PuTTY SSH)
# ============================================
echo ""
echo -e "${BLUE}[2/4]${NC} Cloudflare SSH tunnel indítása (PuTTY használatra)..."

# Cloudflared indítása háttérben
cloudflared tunnel --url ssh://localhost:22 --no-autoupdate > /tmp/cloudflared.log 2>&1 &
CLOUDFLARED_PID=$!

# Várunk az URL-re
echo -e "  Várakozás a Cloudflare tunnel felépülésére..."
sleep 8

# URL kinyerése a logból
if [ -f /tmp/cloudflared.log ]; then
    CF_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cloudflared.log | head -1)
    
    if [ -n "$CF_URL" ]; then
        # SSH host (https:// nélkül)
        SSH_HOST=$(echo "$CF_URL" | sed 's|https://||')
        
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  🔐 PUTTY SSH BEÁLLÍTÁSOK (Cloudflare Tunnel)               ║${NC}"
        echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}Host Name (or IP address):${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}${SSH_HOST}${NC}"
        echo -e "${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}Port:${NC} ${BLUE}22${NC}"
        echo -e "${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}Connection → Data → Auto-login username:${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}root${NC}"
        echo -e "${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}Jelszó (bejelentkezéskor kéri):${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}${SSH_PASSWORD}${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Adatok fájlba mentése
        cat > /tmp/putty-ssh.txt << EOF
╔══════════════════════════════════════════════╗
║  PUTTY BEÁLLÍTÁSOK (másold ki!)              ║
╠══════════════════════════════════════════════╣
║  Host Name: ${SSH_HOST}
║  Port: 22
║  Connection type: SSH
║
║  Connection → Data → Auto-login username:
║    root
║
║  Jelszó (bejelentkezéskor):
║    ${SSH_PASSWORD}
╚══════════════════════════════════════════════╝

Webes SSH link (böngészőből is működik):
${CF_URL}
EOF
        
        echo -e "${GREEN}  ✓ Cloudflare SSH tunnel aktív!${NC}"
        echo -e "${GREEN}  ✓ PuTTY adatok: /tmp/putty-ssh.txt${NC}"
    else
        echo -e "${RED}  ✗ Cloudflare URL nem található a logban${NC}"
        echo -e "${RED}    Log tartalom:${NC}"
        cat /tmp/cloudflared.log
    fi
else
    echo -e "${RED}  ✗ Cloudflared log fájl nem jött létre${NC}"
fi

# ============================================
# 3) tmate SSH tunnel (alternatív SSH)
# ============================================
echo ""
echo -e "${BLUE}[3/4]${NC} tmate SSH tunnel indítása (alternatív SSH hozzáférés)..."

# tmate socket
TMATE_SOCK="/tmp/tmate.sock"

# Korábbi session törlése
rm -f "$TMATE_SOCK"

# tmate indítás háttérben ROOT-ként
tmate -S "$TMATE_SOCK" new-session -d -s main 2>/dev/null

# Várunk hogy a tunnel felépüljön
echo -e "  Várakozás a tmate tunnel felépülésére..."
for i in $(seq 1 30); do
    sleep 1
    SSH_CMD=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh}' 2>/dev/null)
    if [ -n "$SSH_CMD" ] && [ "$SSH_CMD" != "" ]; then
        SSH_RO=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh_ro}' 2>/dev/null)
        break
    fi
done

if [ -n "$SSH_CMD" ]; then
    # tmate host és user kinyerése
    TMATE_USER=$(echo "$SSH_CMD" | sed 's/ssh //' | cut -d@ -f1)
    TMATE_HOST=$(echo "$SSH_CMD" | sed 's/ssh //' | cut -d@ -f2)
    
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  🔑 TMATE SSH (Terminálból VAGY PuTTY-ból)                  ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}Terminálból (egyszerű):${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}${SSH_CMD}${NC}"
    echo -e "${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}PuTTY-ból:${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Host: ${TMATE_HOST}${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Port: 22${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}User: ${TMATE_USER}${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Pass: (nincs, kulcs alapú)${NC}"
    echo -e "${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}Csak olvasás:${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}${SSH_RO}${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # SSH adatok fájlba mentése
    cat > /tmp/tmate-ssh.txt << EOF
TMATE SSH parancs (terminálból):
${SSH_CMD}

PuTTY beállítások:
  Host: ${TMATE_HOST}
  Port: 22
  User: ${TMATE_USER}
  Pass: NINCS (automatikus kulcs alapú auth)

Csak olvasás:
${SSH_RO}
EOF
    
    echo -e "${GREEN}  ✓ tmate SSH tunnel aktív!${NC}"
    echo -e "${GREEN}  ✓ tmate adatok: /tmp/tmate-ssh.txt${NC}"
else
    echo -e "${RED}  ✗ tmate tunnel nem sikerült${NC}"
fi

# ============================================
# 4) Web terminal (ttyd) indítása
# ============================================
echo ""
echo -e "${BLUE}[4/4]${NC} Web terminal indítása..."

# Jelszó környezeti változóból vagy alapértelmezett
WEB_USER="${WEB_USER:-admin}"
WEB_PASS="${WEB_PASS:-render-vps-2024}"

echo -e "${GREEN}  ✓ Web terminal elérhető a Render URL-en${NC}"
echo -e "  ${YELLOW}Belépés: ${WEB_USER} / ${WEB_PASS}${NC}"
echo ""
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}  🎉 Minden fut! Használd a VPS-t!  🚀${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📋 SSH adatok megtekintése:${NC}"
echo -e "   ${BLUE}cat /tmp/putty-ssh.txt${NC}   (Cloudflare - AJÁNLOTT PuTTY-hoz)"
echo -e "   ${BLUE}cat /tmp/tmate-ssh.txt${NC}   (tmate - alternatív)"
echo ""

# ttyd indítás ROOT-ként
# -W: írható terminál
# -c: basic auth (felhasználó:jelszó)
# -t: téma beállítások
exec ttyd \
    -p "${PORT:-10000}" \
    -W \
    -c "${WEB_USER}:${WEB_PASS}" \
    -t fontSize=15 \
    -t fontFamily="'JetBrains Mono', 'Fira Code', 'Courier New', monospace" \
    -t 'theme={"background":"#1a1b26","foreground":"#c0caf5","cursor":"#c0caf5","selectionBackground":"#33467C"}' \
    -t drawBoldTextInBrightColors=true \
    /bin/bash --login
