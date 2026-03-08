FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=6969
ENV BORE_PORT=48252

# ── Alapcsomagok ──
RUN apt-get update && apt-get install -y \
    dropbear \
    openssh-sftp-server \
    nginx \
    neofetch \
    curl \
    wget \
    nano \
    vim \
    git \
    htop \
    sudo \
    supervisor \
    net-tools \
    python3 \
    python3-pip \
    nodejs \
    npm \
    unzip \
    zip \
    tmux \
    screen \
    jq \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── ttyd ──
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.x86_64 \
    -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# ── Bore tunnel ──
RUN curl -fsSL \
    https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin/ && chmod +x /usr/local/bin/bore || true

# ── Dropbear SSH kulcsok ──
RUN rm -f /etc/dropbear/dropbear_rsa_host_key \
          /etc/dropbear/dropbear_ecdsa_host_key \
          /etc/dropbear/dropbear_ed25519_host_key && \
    mkdir -p /etc/dropbear && \
    dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key && \
    dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key && \
    dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key

# ── Felhasználók ──
RUN echo 'root:2003' | chpasswd && \
    useradd -m -s /bin/bash admin && \
    echo 'admin:2003' | chpasswd && \
    usermod -aG sudo admin && \
    echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# ── Screen könyvtárak ──
RUN mkdir -p /var/run/screen && chmod 777 /var/run/screen && chmod +t /var/run/screen && \
    mkdir -p /var/log/screen && chmod 777 /var/log/screen && \
    mkdir -p /root/.screen-sessions

# ── Screen konfiguráció ──
RUN cat > /root/.screenrc << 'SCREENRC'
startup_message off
autodetach on
defscrollback 10000
defutf8 on
SCREENRC
RUN cp /root/.screenrc /home/admin/.screenrc && chown admin:admin /home/admin/.screenrc

# ══════════════════════════════════════════════════════
# ── SCREEN PARANCSOK ──
# ══════════════════════════════════════════════════════

# ── sstart: Session indítás ──
RUN cat > /usr/local/bin/sstart << 'SSTART'
#!/bin/bash
if [ $# -lt 2 ]; then
    echo "════════════════════════════════════════════"
    echo "  📺 SCREEN SESSION INDÍTÁS"
    echo "════════════════════════════════════════════"
    echo ""
    echo "  Használat: sstart <név> <parancs>"
    echo ""
    echo "  Példák:"
    echo "    sstart mybot \"python3 bot.py\""
    echo "    sstart web \"node app.js\""
    echo ""
    echo "  ✅ Amíg a fájlok megmaradnak, a screen is!"
    echo ""
    echo "  Kezelés:"
    echo "    slist          - Lista"
    echo "    sattach <név>  - Csatlakozás (Ctrl+A,D kilép)"
    echo "    sstop <név>    - Leállítás"
    echo "════════════════════════════════════════════"
    exit 1
fi

SESSION_NAME="$1"
shift
COMMAND="$*"

if screen -list 2>/dev/null | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    echo "⚠️  '${SESSION_NAME}' már fut!"
    echo "   Csatlakozás: sattach ${SESSION_NAME}"
    exit 1
fi

# Mentés
mkdir -p /root/.screen-sessions
echo "$COMMAND" > "/root/.screen-sessions/${SESSION_NAME}.cmd"

# Runner script
cat > "/root/.screen-sessions/${SESSION_NAME}.sh" << EOF
#!/bin/bash
export SCREEN_CHILD=1
export TERM=xterm-256color
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
echo "════════════════════════════════════════"
echo "  📺 ${SESSION_NAME}"
echo "  🕐 \$(date)"
echo "  📌 ${COMMAND}"
echo "  💡 Leválás: Ctrl+A, D"
echo "════════════════════════════════════════"
echo ""
while true; do
    ${COMMAND}
    echo ""
    echo "⚠️  Leállt, újraindítás 5mp múlva..."
    sleep 5
done
EOF
chmod +x "/root/.screen-sessions/${SESSION_NAME}.sh"

screen -dmS "$SESSION_NAME" bash --norc --noprofile "/root/.screen-sessions/${SESSION_NAME}.sh"
sleep 1

if screen -list 2>/dev/null | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    echo "✅ '${SESSION_NAME}' elindítva!"
    echo "   Parancs: ${COMMAND}"
    echo "   Csatlakozás: sattach ${SESSION_NAME}"
    echo ""
    echo "   ✅ Amíg a fájlok megvannak, ez is megmarad!"
else
    echo "❌ Hiba!"
fi
SSTART
RUN chmod +x /usr/local/bin/sstart

# ── slist ──
RUN cat > /usr/local/bin/slist << 'SLIST'
#!/bin/bash
echo "════════════════════════════════════════════"
echo "  📺 SCREEN SESSION-ÖK"
echo "════════════════════════════════════════════"

# Futó session-ök
RUNNING=$(screen -list 2>/dev/null | grep -E '\t')
if [ -n "$RUNNING" ]; then
    echo ""
    echo "  🟢 FUTÓ:"
    echo "$RUNNING" | while read line; do
        NAME=$(echo "$line" | awk '{print $1}' | cut -d. -f2-)
        CMD=""
        [ -f "/root/.screen-sessions/${NAME}.cmd" ] && CMD=" │ $(cat /root/.screen-sessions/${NAME}.cmd)"
        echo "     ${NAME}${CMD}"
    done
fi

# Mentett session-ök
echo ""
echo "  📁 MENTETT:"
FOUND=0
for f in /root/.screen-sessions/*.cmd 2>/dev/null; do
    [ -f "$f" ] || continue
    FOUND=1
    NAME=$(basename "$f" .cmd)
    CMD=$(cat "$f")
    if screen -list 2>/dev/null | grep -q "\.${NAME}[[:space:]]"; then
        echo "     🟢 ${NAME}: ${CMD}"
    else
        echo "     ⚪ ${NAME}: ${CMD} (watchdog újraindítja)"
    fi
done
[ "$FOUND" -eq 0 ] && echo "     (nincs)"

echo ""
echo "  sattach <név>  - Csatlakozás"
echo "  sstop <név>    - Leállítás"
echo "════════════════════════════════════════════"
SLIST
RUN chmod +x /usr/local/bin/slist

# ── sattach ──
RUN cat > /usr/local/bin/sattach << 'SATTACH'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: sattach <név>"
    slist
    exit 1
fi

SESSION_NAME="$1"

if screen -list 2>/dev/null | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    echo "📺 Csatlakozás: ${SESSION_NAME}"
    echo "💡 Leválás: Ctrl+A, D"
    echo ""
    screen -r "$SESSION_NAME"
else
    echo "❌ '${SESSION_NAME}' nem fut!"
    echo ""
    if [ -f "/root/.screen-sessions/${SESSION_NAME}.cmd" ]; then
        echo "📁 De mentve van! Indítás..."
        CMD=$(cat "/root/.screen-sessions/${SESSION_NAME}.cmd")
        sstart "$SESSION_NAME" "$CMD"
    else
        slist
    fi
fi
SATTACH
RUN chmod +x /usr/local/bin/sattach

# ── sstop ──
RUN cat > /usr/local/bin/sstop << 'SSTOP'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: sstop <név>"
    echo "Összes:    sstop all"
    slist
    exit 1
fi

if [ "$1" = "all" ]; then
    echo "🛑 Összes session leállítása..."
    for f in /root/.screen-sessions/*.cmd 2>/dev/null; do
        [ -f "$f" ] || continue
        NAME=$(basename "$f" .cmd)
        screen -S "$NAME" -X quit 2>/dev/null
        rm -f "/root/.screen-sessions/${NAME}.cmd" 2>/dev/null
        rm -f "/root/.screen-sessions/${NAME}.sh" 2>/dev/null
        echo "  ⏹️  ${NAME}"
    done
    echo "✅ Kész!"
    exit 0
fi

SESSION_NAME="$1"

screen -S "$SESSION_NAME" -X quit 2>/dev/null
rm -f "/root/.screen-sessions/${SESSION_NAME}.cmd" 2>/dev/null
rm -f "/root/.screen-sessions/${SESSION_NAME}.sh" 2>/dev/null

echo "⏹️  '${SESSION_NAME}' leállítva és törölve!"
SSTOP
RUN chmod +x /usr/local/bin/sstop

# ══════════════════════════════════════════════════════
# ── SCREEN WATCHDOG ──
# ══════════════════════════════════════════════════════
RUN cat > /usr/local/bin/screen-watchdog.sh << 'WATCHDOG'
#!/bin/bash
echo "[WATCHDOG] Indítás - figyeli a mentett session-öket"

while true; do
    sleep 10
    
    # Screen könyvtár fix
    if [ ! -d /var/run/screen ]; then
        mkdir -p /var/run/screen
        chmod 777 /var/run/screen
        chmod +t /var/run/screen
    fi
    
    # Minden mentett session ellenőrzése
    for cmd_file in /root/.screen-sessions/*.cmd 2>/dev/null; do
        [ -f "$cmd_file" ] || continue
        
        NAME=$(basename "$cmd_file" .cmd)
        RUNNER="/root/.screen-sessions/${NAME}.sh"
        
        # Ha nem fut ÉS van runner script → indítás
        if ! screen -list 2>/dev/null | grep -q "\.${NAME}[[:space:]]"; then
            if [ -f "$RUNNER" ]; then
                echo "[WATCHDOG] $(date '+%H:%M:%S') '${NAME}' nem fut → indítás"
                screen -dmS "$NAME" bash --norc --noprofile "$RUNNER"
                sleep 2
            fi
        fi
    done
done
WATCHDOG
RUN chmod +x /usr/local/bin/screen-watchdog.sh

# ── Shell ──
RUN cat > /root/.bashrc << 'BASHRC'
export PS1='\[\033[01;32m\]\u@Szaby\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TERM=xterm-256color
alias ls='ls --color=auto'
alias ll='ls -lah'
alias sl='slist'
alias cls='clear'

if [ -t 1 ] && [ -z "$STY" ] && [ -z "$SCREEN_CHILD" ] && [ ! -f /tmp/.neo ]; then
    touch /tmp/.neo
    clear
    neofetch 2>/dev/null
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  🔑 Jelszó: 2003"
    echo "  📺 Screen: sstart / slist / sattach / sstop"
    echo "  ✅ Amíg a fájlok megvannak, a screen is!"
    echo "═══════════════════════════════════════════════"
    
    SAVED=$(ls /root/.screen-sessions/*.cmd 2>/dev/null | wc -l)
    RUNNING=$(screen -list 2>/dev/null | grep -c "\..*(" || echo 0)
    
    if [ "$SAVED" -gt 0 ] 2>/dev/null; then
        echo ""
        echo "  📺 Session-ök: ${RUNNING} fut / ${SAVED} mentve"
        for f in /root/.screen-sessions/*.cmd 2>/dev/null; do
            [ -f "$f" ] || continue
            NAME=$(basename "$f" .cmd)
            if screen -list 2>/dev/null | grep -q "\.${NAME}[[:space:]]"; then
                echo "     🟢 ${NAME}"
            else
                echo "     ⏳ ${NAME} (indítás...)"
            fi
        done
    fi
    echo ""
fi
BASHRC
RUN cp /root/.bashrc /home/admin/.bashrc && chown admin:admin /home/admin/.bashrc

# ── Cleanup ──
RUN cat > /usr/local/bin/cleanup.sh << 'CLEANUP'
#!/bin/bash
apt-get clean 2>/dev/null
journalctl --vacuum-size=50M 2>/dev/null
find /tmp -type f -mtime +1 -delete 2>/dev/null
pip3 cache purge 2>/dev/null
npm cache clean --force 2>/dev/null
find /var/log -type f -size +50M -exec truncate -s 10M {} \; 2>/dev/null
echo "✅ Cleanup kész"
CLEANUP
RUN chmod +x /usr/local/bin/cleanup.sh

# ── Mappák ──
RUN mkdir -p /var/www/html /root/projects /home/admin/projects && chown -R admin:admin /home/admin

# ── Weboldal ──
RUN cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Linux Server</title>
<style>
body{background:#0d1117;color:#c9d1d9;font-family:sans-serif;padding:20px;max-width:900px;margin:0 auto}
h1{color:#58a6ff;text-align:center}
.card{background:#161b22;border:1px solid #30363d;border-radius:10px;padding:20px;margin:15px 0}
pre{background:#0d1117;padding:15px;border-radius:6px;color:#7ee787}
.btn{display:block;text-align:center;padding:14px;background:#238636;color:#fff;text-decoration:none;border-radius:8px;margin:10px 0}
.status{text-align:center;padding:15px;border-radius:8px;margin:15px 0}
.ok{background:#0d2818;border:1px solid #238636;color:#7ee787}
</style></head><body>
<h1>🐧 Linux Server</h1>
<div class="status ok" id="s">🔄</div>
<div class="card"><h2>🔐 SSH</h2><pre id="ssh">Loading...</pre></div>
<div class="card"><a href="/terminal" class="btn">🖥️ Web Terminál</a></div>
<div class="card"><h2>📺 Screen</h2><pre>sstart mybot "python3 bot.py"   # Indítás
slist                            # Lista
sattach mybot                    # Csatlakozás
  → Ctrl+A, D                   # Leválás (fut tovább!)
sstop mybot                      # Leállítás

✅ Amíg a fájlok megvannak, a screen is megmarad!</pre></div>
<script>
setInterval(()=>fetch('/sftp.txt').then(r=>r.text()).then(t=>{
if(t.includes('AKTIV')){document.getElementById('s').innerHTML='✅ Aktív';
let h='',p='';t.split('\n').forEach(l=>{if(l.includes('Host:'))h=l.split(':')[1].trim();if(l.includes('Port:')&&!l.includes('Protocol'))p=l.split(':')[1].trim()});
if(h&&p)document.getElementById('ssh').textContent='ssh root@'+h+' -p '+p+'\nJelszó: 2003';}
}).catch(()=>{}),3000);
</script></body></html>
HTML

# ── Nginx ──
RUN cat > /etc/nginx/sites-available/default << 'NGINX'
server {
    listen 6969 default_server;
    root /var/www/html;
    location /health { return 200 'OK'; }
    location / { try_files $uri $uri/ =404; }
    location /terminal {
        proxy_pass http://127.0.0.1:7681;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
    location /sftp.txt { default_type text/plain; add_header Cache-Control "no-cache"; }
}
NGINX

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6969
CMD ["/start.sh"]
