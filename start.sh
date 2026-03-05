#!/bin/bash

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

echo -e "${BLUE}[1/4]${NC} SSH szerver indítása..."
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

echo ""
echo -e "${BLUE}[2/4]${NC} bore.pub SSH/SFTP tunnel indítása..."

if command -v bore >/dev/null 2>&1; then
    bore local 22 --to bore.pub > /tmp/bore.log 2>&1 &
    
    echo -e "  Várakozás a tunnel felépülésére..."
    sleep 8

    BORE_PORT=""
    for i in $(seq 1 10); do
        if [ -f /tmp/bore.log ]; then
            BORE_PORT=$(grep -oP 'listening at bore\.pub:\K[0-9]+' /tmp/bore.log | head -1)
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
        echo -e "${YELLOW}║${NC}  ${BLUE}User: root${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Pass: ${SSH_PASSWORD}${NC}"
        echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${YELLOW}║  📁 FILEZILLA SFTP BEÁLLÍTÁSOK                               ║${NC}"
        echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Protocol: SFTP${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Host: bore.pub${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Port: ${BORE_PORT}${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}User: root${NC}"
        echo -e "${YELLOW}║${NC}  ${BLUE}Pass: ${SSH_PASSWORD}${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        cat > /tmp/ssh-info.txt << EOF
PUTTY SSH:
  Host: bore.pub
  Port: ${BORE_PORT}
  User: root
  Pass: ${SSH_PASSWORD}

FILEZILLA SFTP:
  Protocol: SFTP
  Host: bore.pub
  Port: ${BORE_PORT}
  User: root
  Pass: ${SSH_PASSWORD}
EOF
        echo -e "${GREEN}  ✓ bore.pub tunnel aktív port ${BORE_PORT}${NC}"
    else
        echo -e "${RED}  ✗ bore.pub tunnel hiba${NC}"
        cat /tmp/bore.log 2>/dev/null
    fi
else
    echo -e "${RED}  ✗ bore parancs nincs${NC}"
fi

echo ""
echo -e "${BLUE}[3/4]${NC} tmate SSH tunnel..."

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
        echo -e "${CYAN}║  🔑 TMATE SSH (Alternatív)                                  ║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}${SSH_CMD}${NC}"
        echo -e "${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Host: ${TMATE_HOST}${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Port: 22${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}User: ${TMATE_USER}${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}Pass: (nincs)${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        echo "$SSH_CMD" > /tmp/tmate-ssh.txt
        echo -e "${GREEN}  ✓ tmate SSH aktív!${NC}"
        break
    fi
    sleep 1
done

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
echo -e "${YELLOW}Parancs: ${BLUE}info${NC} → Csatlakozási adatok"
echo ""

exec ttyd \
    -p "${PORT:-10000}" \
    -W \
    -c "${WEB_USER}:${WEB_PASS}" \
    -t fontSize=15 \
    -t fontFamily="monospace" \
    -t 'theme={"background":"#1a1b26","foreground":"#c0caf5"}' \
    /bin/bash --login
