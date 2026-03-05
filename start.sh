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
echo "║  Web Terminal + SSH Tunnel               ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# 1) SSH szerver indítása
# ============================================
echo -e "${BLUE}[1/3]${NC} SSH szerver indítása..."
service ssh start
echo -e "${GREEN}  ✓ SSH szerver fut (port 22)${NC}"

# ============================================
# 2) tmate SSH tunnel (valódi SSH hozzáférés)
# ============================================
echo -e "${BLUE}[2/3]${NC} SSH tunnel (tmate) indítása..."

# tmate socket
TMATE_SOCK="/tmp/tmate.sock"

# Korábbi session törlése
rm -f "$TMATE_SOCK"

# tmate indítás háttérben ROOT-ként
tmate -S "$TMATE_SOCK" new-session -d -s main 2>/dev/null

# Várunk hogy a tunnel felépüljön
echo -e "  Várakozás a tunnel felépülésére..."
for i in $(seq 1 30); do
    sleep 1
    SSH_CMD=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh}' 2>/dev/null)
    if [ -n "$SSH_CMD" ] && [ "$SSH_CMD" != "" ]; then
        SSH_RO=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh_ro}' 2>/dev/null)
        break
    fi
done

if [ -n "$SSH_CMD" ]; then
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  🔑 SSH KAPCSOLAT (másold ki és használd terminálból!)      ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}Írás+olvasás:${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}$SSH_CMD${NC}"
    echo -e "${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}Csak olvasás:${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}$SSH_RO${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # SSH adatok fájlba mentése
    echo "$SSH_CMD" > /tmp/ssh-connection.txt
    echo "$SSH_RO" >> /tmp/ssh-connection.txt
    echo -e "${GREEN}  ✓ SSH tunnel aktív! Adatok: /tmp/ssh-connection.txt${NC}"
else
    echo -e "${RED}  ✗ tmate tunnel nem sikerült (de a web terminal működik!)${NC}"
fi

# ============================================
# 3) Web terminal (ttyd) indítása
# ============================================
echo ""
echo -e "${BLUE}[3/3]${NC} Web terminal indítása..."

# Jelszó környezeti változóból vagy alapértelmezett
WEB_USER="${WEB_USER:-admin}"
WEB_PASS="${WEB_PASS:-render-vps-2024}"

echo -e "${GREEN}  ✓ Web terminal elérhető a Render URL-en${NC}"
echo -e "  ${YELLOW}Belépés: ${WEB_USER} / ${WEB_PASS}${NC}"
echo ""
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Minden fut! Használd a VPS-t!  🚀${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo ""

# ttyd indítás ROOT-ként (nem sudo-val!)
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
