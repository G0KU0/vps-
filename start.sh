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
# 1) SSH szerver indítása (SFTP támogatással)
# ============================================
echo -e "${BLUE}[1/4]${NC} SSH szerver indítása..."
service ssh start

SSH_PASSWORD="${SSH_PASSWORD:-render2024}"
echo "root:${SSH_PASSWORD}" | chpasswd

echo -e "${GREEN}  ✓ SSH szerver fut (port 22)${NC}"
echo -e "${GREEN}  ✓ SFTP támogatás aktív${NC}"
echo -e "${GREEN}  ✓ Root jelszó: ${SSH_PASSWORD}${NC}"

# ============================================
# 2) bore.pub TCP Tunnel (PuTTY + FileZilla!)
# ============================================
echo ""
echo -e "${BLUE}[2/4]${NC} bore.pub SSH/SFTP tunnel indítása..."
echo -e "  (Ez adja a PuTTY és FileZilla hozzáférést!)"

bore local 22 --to bore.pub > /tmp/bore.log 2>&1 &
BORE_PID=$!

echo -e "  Várakozás a tunnel felépülésére..."
sleep 10

BORE_PORT=""
for i in $(seq 1 10); do
    if [ -f /tmp/bore.log ]; then
        BORE_PORT=$(grep -oP 'bore\.pub:\K[0-9]+' /tmp/bore.log | head -1)
        if [ -n "$BORE_PORT" ]; then
            break
        fi
    fi
    sleep 2
done

if [ -n "$BORE_PORT" ]; then
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  🔐 PUTTY SSH BEÁLLÍTÁSOK                                   ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Host Name: bore.pub${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Port: ${BORE_PORT}${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Connection type: SSH${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}User: root${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Pass: ${SSH_PASSWORD}${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║  📁 FILEZILLA SFTP BEÁLLÍTÁSOK                               ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Protocol: SFTP - SSH File Transfer Protocol${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Host: bore.pub${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Port: ${BORE_PORT}${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}Logon Type: Normal${NC}"
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
║    Host Name: bore.pub
║    Port: ${BORE_PORT}
║    Connection type: SSH
║    User: root
║    Pass: ${SSH_PASSWORD}
║
║  FILEZILLA SFTP:
║    Protocol: SFTP - SSH File Transfer Protocol
║    Host: bore.pub
║    Port: ${BORE_PORT}
║    Logon Type: Normal
║    User: root
║    Pass: ${SSH_PASSWORD}
║
║  TERMINÁLBÓL:
║    ssh -p ${BORE_PORT} root@bore.pub
║    Jelszó: ${SSH_PASSWORD}
║
║  FONTOS MAPPÁK:
║    /root/projects/   → Projektjeid
║    /root/uploads/    → Feltöltések
║    /root/downloads/  → Letöltések
║    /root/scripts/    → Scriptek
║
║  GYORS PARANCSOK:
║    info              → Ez az info
║    neofetch          → Rendszerinfó
║    htop              → Folyamatok
║    free -h           → Memória
║    df -h             → Tárhely
║    ip a              → Hálózat
║    curl ifconfig.me  → Külső IP
║    ll                → Fájllista
║
╚══════════════════════════════════════════════════════╝
EOF
    
    echo -e "${GREEN}  ✓ bore.pub tunnel aktív!${NC}"
    echo -e "${GREEN}  ✓ PuTTY: bore.pub port ${BORE_PORT}${NC}"
    echo -e "${GREEN}  ✓ FileZilla SFTP: bore.pub port ${BORE_PORT}${NC}"
    echo -e "${GREEN}  ✓ Info: ${BLUE}info${NC}"
else
    echo -e "${RED}  ✗ bore.pub tunnel hiba (tmate-vel próbálkozz!)${NC}"
    echo -e "${RED}  Log tartalom:${NC}"
    cat /tmp/bore.log 2>/dev/null
fi

# ============================================
# 3) tmate SSH tunnel (BACKUP)
# ============================================
echo ""
echo -e "${BLUE}[3/4]${NC} tmate SSH tunnel (backup hozzáférés)..."

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
        echo -e "${CYAN}║  🔑 TMATE SSH (backup - ha bore nem megy)                   ║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}Terminálból:${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}${SSH_CMD}${NC}"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}PuTTY:${NC}"
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
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  🎉 Ubuntu VPS kész! Minden szolgáltatás fut! 🎉${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📋 Összefoglaló:${NC}"
echo -e "   ${BLUE}🔐 PuTTY/FileZilla:${NC} bore.pub port ${BORE_PORT:-???}"
echo -e "   ${BLUE}🔑 tmate backup:${NC}    info vagy cat /tmp/tmate-ssh.txt"
echo -e "   ${BLUE}🌐 Web Terminal:${NC}    Render URL-en (${WEB_USER}/${WEB_PASS})"
echo -e "   ${BLUE}📋 Részletek:${NC}       info"
echo ""

exec ttyd \
    -p "${PORT:-10000}" \
    -W \
    -c "${WEB_USER}:${WEB_PASS}" \
    -t fontSize=15 \
    -t fontFamily="'JetBrains Mono', 'Fira Code', monospace" \
    -t 'theme={"background":"#1a1b26","foreground":"#c0caf5","cursor":"#c0caf5","selectionBackground":"#33467C"}' \
    -t drawBoldTextInBrightColors=true \
    /bin/bash --login
