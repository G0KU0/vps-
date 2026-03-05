#!/bin/bash

# Színek
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════╗"
echo "║     📻 Render VPS + Rádió Szerver 📻    ║"
echo "╠══════════════════════════════════════════╣"
echo "║  SSH/SFTP + Web Terminal + Icecast2      ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# 1) SSH szerver indítása (SFTP támogatással!)
# ============================================
echo -e "${BLUE}[1/6]${NC} SSH szerver indítása (SFTP)..."
service ssh start

# ROOT jelszó beállítása
SSH_PASSWORD="${SSH_PASSWORD:-render2024}"
echo "root:${SSH_PASSWORD}" | chpasswd

echo -e "${GREEN}  ✓ SSH szerver fut (port 22)${NC}"
echo -e "${GREEN}  ✓ SFTP támogatás aktív${NC}"
echo -e "${GREEN}  ✓ Root jelszó: ${SSH_PASSWORD}${NC}"

# ============================================
# 2) Cloudflare Tunnel #1 (SSH/SFTP)
# ============================================
echo ""
echo -e "${BLUE}[2/6]${NC} Cloudflare SSH Tunnel (PuTTY + FileZilla)..."

cloudflared tunnel --url ssh://localhost:22 --no-autoupdate > /tmp/cloudflared-ssh.log 2>&1 &
CF_SSH_PID=$!

sleep 8

if [ -f /tmp/cloudflared-ssh.log ]; then
    CF_SSH_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cloudflared-ssh.log | head -1)
    
    if [ -n "$CF_SSH_URL" ]; then
        CF_SSH_HOST=$(echo "$CF_SSH_URL" | sed 's|https://||')
        
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  🔐 PUTTY / FILEZILLA BEÁLLÍTÁSOK                           ║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}PuTTY SSH:${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Host: ${CF_SSH_HOST}${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Port: 22${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}User: root${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Pass: ${SSH_PASSWORD}${NC}"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}FileZilla SFTP:${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Protocol: SFTP${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Host: ${CF_SSH_HOST}${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Port: 22${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}User: root${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Pass: ${SSH_PASSWORD}${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Mentés fájlba
        cat > /tmp/ssh-sftp-info.txt << EOF
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
║    /root/website/    → Weboldalak
║    /root/radio/      → Rádió fájlok
║    /root/uploads/    → Feltöltések
║    /root/downloads/  → Letöltések
║
╚══════════════════════════════════════════════════════╝
EOF
        
        echo -e "${GREEN}  ✓ SSH/SFTP tunnel aktív!${NC}"
        echo -e "${GREEN}  ✓ Info: /tmp/ssh-sftp-info.txt${NC}"
    else
        echo -e "${RED}  ✗ Cloudflare SSH tunnel hiba${NC}"
    fi
else
    echo -e "${RED}  ✗ Cloudflared SSH log nincs${NC}"
fi

# ============================================
# 3) Icecast2 rádió szerver
# ============================================
echo ""
echo -e "${BLUE}[3/6]${NC} Icecast2 rádió szerver indítása..."

icecast2 -c /etc/icecast2/icecast.xml > /var/log/icecast2/icecast.log 2>&1 &
ICECAST_PID=$!

sleep 2

if ps -p $ICECAST_PID > /dev/null; then
    echo -e "${GREEN}  ✓ Icecast2 fut (port 8000)${NC}"
else
    echo -e "${RED}  ✗ Icecast2 hiba${NC}"
fi

# ============================================
# 4) Cloudflare Tunnel #2 (Rádió szerver)
# ============================================
echo ""
echo -e "${BLUE}[4/6]${NC} Cloudflare Tunnel (Rádió weboldal)..."

cloudflared tunnel --url http://localhost:8000 --no-autoupdate > /tmp/cloudflared-radio.log 2>&1 &
CF_RADIO_PID=$!

sleep 8

if [ -f /tmp/cloudflared-radio.log ]; then
    CF_RADIO_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cloudflared-radio.log | head -1)
    
    if [ -n "$CF_RADIO_URL" ]; then
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  📻 RÁDIÓ SZERVER                                           ║${NC}"
        echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}Admin:${NC} ${BLUE}${CF_RADIO_URL}/admin/${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}User:${NC} admin ${GREEN}| Pass:${NC} hackme"
        echo -e "${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}Stream:${NC} ${BLUE}${CF_RADIO_URL}/radio.mp3${NC}"
        echo -e "${YELLOW}║${NC}"
        echo -e "${YELLOW}║${NC}  ${GREEN}Státusz:${NC} ${BLUE}${CF_RADIO_URL}/${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        cat > /tmp/radio-info.txt << EOF
📻 RÁDIÓ SZERVER INFO

Admin: ${CF_RADIO_URL}/admin/
  User: admin
  Pass: hackme

Stream: ${CF_RADIO_URL}/radio.mp3

Zene feltöltés FileZilla-val:
  1. Csatlakozz SFTP-n
  2. Menj: /root/radio/music/
  3. Töltsd fel az MP3 fájlokat
  4. Indítsd a streamet (lásd README)
EOF
        
        echo -e "${GREEN}  ✓ Rádió tunnel aktív!${NC}"
    fi
fi

# ============================================
# 5) tmate SSH (alternatív)
# ============================================
echo ""
echo -e "${BLUE}[5/6]${NC} tmate SSH tunnel (alternatív)..."

TMATE_SOCK="/tmp/tmate.sock"
rm -f "$TMATE_SOCK"
tmate -S "$TMATE_SOCK" new-session -d -s main 2>/dev/null

sleep 3
SSH_CMD=$(tmate -S "$TMATE_SOCK" display -p '#{tmate_ssh}' 2>/dev/null)

if [ -n "$SSH_CMD" ]; then
    echo -e "${GREEN}  ✓ tmate: ${SSH_CMD}${NC}"
    echo "$SSH_CMD" > /tmp/tmate-ssh.txt
fi

# ============================================
# 6) Web Terminal (ttyd)
# ============================================
echo ""
echo -e "${BLUE}[6/6]${NC} Web terminal indítása..."

WEB_USER="${WEB_USER:-admin}"
WEB_PASS="${WEB_PASS:-render-vps-2024}"

echo -e "${GREEN}  ✓ Web terminal aktív${NC}"
echo -e "  ${YELLOW}User: ${WEB_USER} | Pass: ${WEB_PASS}${NC}"
echo ""
echo -e "${PURPLE}══════════════════════════════════════════${NC}"
echo -e "${PURPLE}  🎉 Minden szolgáltatás fut! 🎉${NC}"
echo -e "${PURPLE}══════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}📋 Gyors parancsok:${NC}"
echo -e "   ${BLUE}cat /tmp/ssh-sftp-info.txt${NC}    (SSH/SFTP)"
echo -e "   ${BLUE}cat /tmp/radio-info.txt${NC}       (Rádió)"
echo -e "   ${BLUE}ls /root/${NC}                     (Fájlok)"
echo ""

# ttyd indítás
exec ttyd \
    -p "${PORT:-10000}" \
    -W \
    -c "${WEB_USER}:${WEB_PASS}" \
    -t fontSize=15 \
    -t fontFamily="'JetBrains Mono', monospace" \
    -t 'theme={"background":"#1a1b26","foreground":"#c0caf5","cursor":"#c0caf5"}' \
    /bin/bash --login
