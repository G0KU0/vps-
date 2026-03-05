#!/bin/bash

# Színek
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║        🐧 Render Ubuntu VPS 🐧          ║"
echo "╠══════════════════════════════════════════╣"
echo "║  SSH/SFTP + Web Terminal                 ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# 1) SSH szerver indítása (SFTP)
# ============================================
echo -e "${BLUE}[1/4]${NC} SSH szerver indítása (SFTP)..."
service ssh start

# ROOT jelszó
SSH_PASSWORD="${SSH_PASSWORD:-render2024}"
echo "root:${SSH_PASSWORD}" | chpasswd

echo -e "${GREEN}  ✓ SSH szerver fut (port 22)${NC}"
echo -e "${GREEN}  ✓ SFTP támogatás aktív${NC}"
echo -e "${GREEN}  ✓ Root jelszó: ${SSH_PASSWORD}${NC}"

# ============================================
# 2) Cloudflare SSH/SFTP Tunnel
# ============================================
echo ""
echo -e "${BLUE}[2/4]${NC} Cloudflare SSH/SFTP Tunnel indítása..."

cloudflared tunnel --url ssh://localhost:22 --no-autoupdate > /tmp/cloudflared-ssh.log 2>&1 &
CF_SSH_PID=$!

sleep 8

if [ -f /tmp/cloudflared-ssh.log ]; then
    CF_SSH_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cloudflared-ssh.log | head -1)
    
    if [ -n "$CF_SSH_URL" ]; then
        CF_SSH_HOST=$(echo "$CF_SSH_URL" | sed 's|https://||')
        
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  🔐 PUTTY / FILEZILLA HOZZÁFÉRÉS                            ║${NC}"
        echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}PuTTY SSH:${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Host: ${CF_SSH_HOST}${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Port: 22${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}User: root${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Pass: ${SSH_PASSWORD}${NC}"
        echo -e "${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}FileZilla SFTP:${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Protocol: SFTP${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Host: ${CF_SSH_HOST}${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Port: 22${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}User: root${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Pass: ${SSH_PASSWORD}${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Info fájl mentése
        cat > /tmp/ssh-info.txt << EOF
╔══════════════════════════════════════════════════════╗
║  🔐 SSH / SFTP HOZZÁFÉRÉS                            ║
╠══════════════════════════════════════════════════════╣
║
║  PUTTY SSH:
║    Host: ${CF_SSH_HOST}
║    Port: 22
║    User: root
║    Pass: ${SSH_PASSWORD}
║
║  FILEZILLA SFTP:
║    Protocol: SFTP - SSH File Transfer Protocol
║    Host: ${CF_SSH_HOST}
║    Port: 22
║    Username: root
║    Password: ${SSH_PASSWORD}
║
║  FONTOS MAPPÁK:
║    /root/projects/   → Projektjeid
║    /root/uploads/    → Feltöltések
║    /root/downloads/  → Letöltések
║    /root/scripts/    → Scriptek
║
║  GYORS PARANCSOK:
║    info              → Ez az info megjelenítése
║    neofetch          → Rendszerinfó
║    htop              → Folyamatok
║    free -h           → Memória
║    df -h             → Tárhely
║    ip a              → Hálózati interfészek
║    curl ifconfig.me  → Külső IP cím
║    ll                → Fájlok listázása (ls -lah)
║
║  SZOLGÁLTATÁSOK INDÍTÁSA:
║    service ssh start         → SSH szerver
║    service nginx start       → Nginx (ha telepíted)
║    service apache2 start     → Apache (ha telepíted)
║
║  NEM MŰKÖDIK (Docker korlátozás):
║    systemctl                 → Használd: service
║
╚══════════════════════════════════════════════════════╝
EOF
        
        echo -e "${GREEN}  ✓ SSH/SFTP tunnel aktív!${NC}"
        echo -e "${GREEN}  ✓ Info: cat /tmp/ssh-info.txt ${NC}${YELLOW}vagy${NC}${GREEN} info${NC}"
    else
        echo -e "${RED}  ✗ Cloudflare URL nem található${NC}"
        echo -e "${RED}    (A tmate SSH még működik!)${NC}"
    fi
else
    echo -e "${RED}  ✗ Cloudflared log nincs${NC}"
fi

# ============================================
# 3) tmate SSH tunnel (alternatív)
# ============================================
echo ""
echo -e "${BLUE}[3/4]${NC} tmate SSH tunnel (alternatív)..."

TMATE_SOCK="/tmp/tmate.sock"
rm -f "$TMATE_SOCK"
tmate -S "$TMATE_SOCK" new-session -d -s main 2>/dev/null

sleep 3
for i in $(seq 1 20); do
    SSH_CMD=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh}' 2>/dev/null)
    if [ -n "$SSH_CMD" ]; then
        TMATE_USER=$(echo "$SSH_CMD" | sed 's/ssh //' | cut -d@ -f1)
        TMATE_HOST=$(echo "$SSH_CMD" | sed 's/ssh //' | cut -d@ -f2)
        
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🔑 TMATE SSH (alternatív hozzáférés)                       ║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}Terminálból:${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}${SSH_CMD}${NC}"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}PuTTY-ból:${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Host: ${TMATE_HOST}${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Port: 22${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}User: ${TMATE_USER}${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Pass: (nincs - automatikus)${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        echo "$SSH_CMD" > /tmp/tmate-ssh.txt
        echo -e "${GREEN}  ✓ tmate SSH aktív!${NC}"
        break
    fi
    sleep 1
done

# ============================================
# 4) Web Terminal (ttyd)
# ============================================
echo ""
echo -e "${BLUE}[4/4]${NC} Web terminal indítása..."

WEB_USER="${WEB_USER:-admin}"
WEB_PASS="${WEB_PASS:-render-vps-2024}"

echo -e "${GREEN}  ✓ Web terminal aktív${NC}"
echo -e "  ${YELLOW}User: ${WEB_USER} | Pass: ${WEB_PASS}${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}  🎉 Ubuntu VPS kész! 🎉${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📋 Gyors parancsok:${NC}"
echo -e "   ${BLUE}info${NC}                       (SSH/SFTP adatok)"
echo -e "   ${BLUE}neofetch${NC}                   (Rendszerinfó)"
echo -e "   ${BLUE}htop${NC}                       (Folyamatok)"
echo -e "   ${BLUE}free -h${NC}                    (Memória)"
echo -e "   ${BLUE}df -h${NC}                      (Tárhely)"
echo -e "   ${BLUE}ip a${NC}                       (Hálózat)"
echo -e "   ${BLUE}curl ifconfig.me${NC}           (Külső IP)"
echo ""

# ttyd indítás
exec ttyd \
    -p "${PORT:-10000}" \
    -W \
    -c "${WEB_USER}:${WEB_PASS}" \
    -t fontSize=15 \
    -t fontFamily="'JetBrains Mono', 'Fira Code', monospace" \
    -t 'theme={"background":"#1a1b26","foreground":"#c0caf5","cursor":"#c0caf5","selectionBackground":"#33467C"}' \
    -t drawBoldTextInBrightColors=true \
    /bin/bash --login
