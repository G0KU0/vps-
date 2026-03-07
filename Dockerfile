FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=6969
ENV BORE_PORT=48251

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

# ── ttyd (web terminál) ──
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

# ── Felhasználók (jelszó: 2003) ──
RUN echo 'root:2003' | chpasswd && \
    useradd -m -s /bin/bash admin && \
    echo 'admin:2003' | chpasswd && \
    usermod -aG sudo admin && \
    echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# ════════════════════════════════════════════════
# ── SCREEN KÖNYVTÁR ÉS JOGOSULTSÁGOK ──
# ════════════════════════════════════════════════
RUN mkdir -p /var/run/screen && \
    chmod 777 /var/run/screen && \
    chmod +t /var/run/screen

# ── Screen konfiguráció (root) ──
RUN cat > /root/.screenrc << 'SCREENRC'
# Ne jelenjen meg copyright üzenet
startup_message off

# Automatikus detach ha megszakad a kapcsolat
autodetach on

# Scrollback buffer méret (10000 sor)
defscrollback 10000

# Zombie ablak - ne záródjon be ha kilép a program
# 'cr' = c-vel Close, r-vel Resurrect (újraindít)
zombie cr

# Státuszsor alul
hardstatus alwayslastline
hardstatus string '%{= kG}[ %{G}%H %{g}][%= %{= kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B} %m/%d %{W}%c %{g}]'

# UTF-8 támogatás
defutf8 on

# Log bekapcsolása
deflog on
logfile /var/log/screen/screenlog.%n.%t

# Ha a shell kilép, tartsa meg az ablakot
shell -/bin/bash
SCREENRC

# ── Screen konfiguráció (admin) ──
RUN cp /root/.screenrc /home/admin/.screenrc && \
    chown admin:admin /home/admin/.screenrc

# ── Screen log mappa ──
RUN mkdir -p /var/log/screen && chmod 777 /var/log/screen

# ════════════════════════════════════════════════
# ── SCREEN HELPER SCRIPTEK ──
# ════════════════════════════════════════════════

# ── sstart: Indít egy nevesített screen session-t ──
RUN cat > /usr/local/bin/sstart << 'SSTART'
#!/bin/bash
# Használat: sstart <session_név> <parancs>
# Példa:    sstart mybot "python3 bot.py"
#           sstart webserver "node app.js"
#           sstart minecraft "java -jar server.jar"

if [ $# -lt 2 ]; then
    echo "════════════════════════════════════════════"
    echo "  📺 SCREEN SESSION INDÍTÁS"
    echo "════════════════════════════════════════════"
    echo ""
    echo "  Használat: sstart <név> <parancs>"
    echo ""
    echo "  Példák:"
    echo "    sstart mybot \"python3 bot.py\""
    echo "    sstart webserver \"node app.js\""
    echo "    sstart teszt \"bash myscript.sh\""
    echo "    sstart loop \"while true; do echo fut; sleep 60; done\""
    echo ""
    echo "  Kezelés:"
    echo "    slist              - Futó session-ök listája"
    echo "    sattach <név>      - Csatlakozás session-höz"
    echo "    sstop <név>        - Session leállítása"
    echo "    sstatus            - Részletes állapot"
    echo "    srestart <név>     - Session újraindítása"
    echo ""
    echo "  Screen-ben:"
    echo "    Ctrl+A, D          - Leválás (fut tovább!)"
    echo "    Ctrl+A, K          - Ablak bezárása"
    echo "════════════════════════════════════════════"
    exit 1
fi

SESSION_NAME="$1"
shift
COMMAND="$*"

# Ellenőrzés: fut-e már?
if screen -list | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    echo "⚠️  '${SESSION_NAME}' már fut!"
    echo "   Csatlakozás: sattach ${SESSION_NAME}"
    echo "   Leállítás:   sstop ${SESSION_NAME}"
    exit 1
fi

# Mentés a persistent fájlba (újraindítás után is megmarad)
mkdir -p /root/.screen-sessions
echo "$COMMAND" > "/root/.screen-sessions/${SESSION_NAME}.cmd"

# Indítás
screen -dmS "$SESSION_NAME" bash -c "
    echo '════════════════════════════════════════'
    echo '  📺 Screen: ${SESSION_NAME}'
    echo '  🕐 Indítva: $(date)'
    echo '  📌 Parancs: ${COMMAND}'
    echo '  💡 Leválás: Ctrl+A, D'
    echo '════════════════════════════════════════'
    echo ''
    ${COMMAND}
    echo ''
    echo '════════════════════════════════════════'
    echo '  ⏹️  Program leállt: $(date)'
    echo '  🔄 Újraindítás: srestart ${SESSION_NAME}'
    echo '════════════════════════════════════════'
    exec bash
"

sleep 0.5

if screen -list | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    echo "✅ '${SESSION_NAME}' elindítva!"
    echo "   Parancs: ${COMMAND}"
    echo "   Csatlakozás: sattach ${SESSION_NAME}"
    echo "   Leválás screen-ben: Ctrl+A, D"
else
    echo "❌ Hiba: '${SESSION_NAME}' nem indult el!"
fi
SSTART

# ── slist: Futó screen session-ök listája ──
RUN cat > /usr/local/bin/slist << 'SLIST'
#!/bin/bash
echo "════════════════════════════════════════════"
echo "  📺 FUTÓ SCREEN SESSION-ÖK"
echo "════════════════════════════════════════════"

SESSIONS=$(screen -list 2>/dev/null | grep -E '\t' | grep -v "^$")

if [ -z "$SESSIONS" ]; then
    echo ""
    echo "  (nincs futó session)"
    echo ""
    echo "  Indítás: sstart <név> <parancs>"
else
    echo ""
    echo "$SESSIONS" | while read line; do
        NAME=$(echo "$line" | awk '{print $1}' | cut -d. -f2-)
        STATE=$(echo "$line" | grep -oP '\((.*?)\)' | tr -d '()')
        
        if [ "$STATE" = "Detached" ]; then
            ICON="🟢"
            STATE_HU="Fut (háttérben)"
        elif [ "$STATE" = "Attached" ]; then
            ICON="🔵"
            STATE_HU="Csatlakozva"
        else
            ICON="🟡"
            STATE_HU="$STATE"
        fi
        
        # Mentett parancs megjelenítése
        CMD=""
        if [ -f "/root/.screen-sessions/${NAME}.cmd" ]; then
            CMD=" │ $(cat /root/.screen-sessions/${NAME}.cmd)"
        fi
        
        echo "  ${ICON} ${NAME} - ${STATE_HU}${CMD}"
    done
    echo ""
    echo "  Csatlakozás: sattach <név>"
    echo "  Leállítás:   sstop <név>"
fi
echo "════════════════════════════════════════════"
SLIST

# ── sattach: Csatlakozás session-höz ──
RUN cat > /usr/local/bin/sattach << 'SATTACH'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: sattach <session_név>"
    echo ""
    slist
    exit 1
fi

SESSION_NAME="$1"

if screen -list | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    echo "📺 Csatlakozás: ${SESSION_NAME}"
    echo "💡 Leválás: Ctrl+A, D (a session fut tovább!)"
    echo ""
    screen -r "$SESSION_NAME"
else
    echo "❌ '${SESSION_NAME}' nem található!"
    echo ""
    slist
fi
SATTACH

# ── sstop: Session leállítása ──
RUN cat > /usr/local/bin/sstop << 'SSTOP'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: sstop <session_név>"
    echo "Összes:    sstop all"
    echo ""
    slist
    exit 1
fi

if [ "$1" = "all" ]; then
    echo "🛑 Összes session leállítása..."
    screen -list | grep -oP '\d+\.\K[^\t]+' | while read name; do
        CLEAN_NAME=$(echo "$name" | awk '{print $1}')
        screen -S "$CLEAN_NAME" -X quit 2>/dev/null
        rm -f "/root/.screen-sessions/${CLEAN_NAME}.cmd" 2>/dev/null
        echo "  ⏹️  ${CLEAN_NAME} leállítva"
    done
    echo "✅ Kész!"
    exit 0
fi

SESSION_NAME="$1"

if screen -list | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    screen -S "$SESSION_NAME" -X quit
    rm -f "/root/.screen-sessions/${SESSION_NAME}.cmd" 2>/dev/null
    echo "⏹️  '${SESSION_NAME}' leállítva!"
else
    echo "❌ '${SESSION_NAME}' nem található!"
    slist
fi
SSTOP

# ── srestart: Session újraindítása ──
RUN cat > /usr/local/bin/srestart << 'SRESTART'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: srestart <session_név>"
    exit 1
fi

SESSION_NAME="$1"
CMD_FILE="/root/.screen-sessions/${SESSION_NAME}.cmd"

if [ ! -f "$CMD_FILE" ]; then
    echo "❌ '${SESSION_NAME}' parancs nem található!"
    echo "   Használd: sstart ${SESSION_NAME} <parancs>"
    exit 1
fi

COMMAND=$(cat "$CMD_FILE")
echo "🔄 '${SESSION_NAME}' újraindítása..."

# Leállítás ha fut
if screen -list | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    screen -S "$SESSION_NAME" -X quit 2>/dev/null
    sleep 1
fi

# Újraindítás
sstart "$SESSION_NAME" "$COMMAND"
SRESTART

# ── sstatus: Részletes állapot ──
RUN cat > /usr/local/bin/sstatus << 'SSTATUS'
#!/bin/bash
echo "════════════════════════════════════════════════"
echo "  📺 SCREEN SESSION-ÖK RÉSZLETES ÁLLAPOT"
echo "════════════════════════════════════════════════"
echo ""

COUNT=$(screen -list 2>/dev/null | grep -c "\..*(" || echo 0)
echo "  Aktív session-ök: ${COUNT}"
echo ""

# Futó session-ök
screen -list 2>/dev/null | grep -E '\t' | while read line; do
    FULL=$(echo "$line" | awk '{print $1}')
    PID=$(echo "$FULL" | cut -d. -f1)
    NAME=$(echo "$FULL" | cut -d. -f2-)
    STATE=$(echo "$line" | grep -oP '\((.*?)\)' | tr -d '()')
    
    echo "  ┌─ 📺 ${NAME}"
    echo "  │  PID: ${PID}"
    echo "  │  Állapot: ${STATE}"
    
    if [ -f "/root/.screen-sessions/${NAME}.cmd" ]; then
        echo "  │  Parancs: $(cat /root/.screen-sessions/${NAME}.cmd)"
    fi
    
    # Log fájl mérete
    LOGFILE="/var/log/screen/screenlog.*.${NAME}"
    if ls $LOGFILE 1>/dev/null 2>&1; then
        SIZE=$(du -sh $LOGFILE 2>/dev/null | awk '{print $1}')
        echo "  │  Log méret: ${SIZE}"
    fi
    
    echo "  └──────────────────────────────"
    echo ""
done

# Mentett (nem futó) session-ök
if [ -d "/root/.screen-sessions" ]; then
    SAVED=$(ls /root/.screen-sessions/*.cmd 2>/dev/null)
    if [ -n "$SAVED" ]; then
        echo "  📁 Mentett parancsok (srestart-hoz):"
        for f in /root/.screen-sessions/*.cmd; do
            NAME=$(basename "$f" .cmd)
            CMD=$(cat "$f")
            if screen -list | grep -q "\.${NAME}[[:space:]]"; then
                echo "    🟢 ${NAME}: ${CMD}"
            else
                echo "    ⚪ ${NAME}: ${CMD} (nem fut)"
            fi
        done
    fi
fi

echo ""
echo "════════════════════════════════════════════════"
SSTATUS

# ── Jogosultságok ──
RUN chmod +x /usr/local/bin/sstart \
             /usr/local/bin/slist \
             /usr/local/bin/sattach \
             /usr/local/bin/sstop \
             /usr/local/bin/srestart \
             /usr/local/bin/sstatus

# ── Screen session watchdog (supervisor fogja futtatni) ──
RUN cat > /usr/local/bin/screen-watchdog.sh << 'WATCHDOG'
#!/bin/bash
# Ez a script figyeli a mentett session-öket
# Ha valami meghal, újraindítja

echo "[SCREEN-WATCHDOG] Indítás..."

while true; do
    sleep 30
    
    # Screen könyvtár ellenőrzés
    if [ ! -d /var/run/screen ]; then
        mkdir -p /var/run/screen
        chmod 777 /var/run/screen
        chmod +t /var/run/screen
    fi
    
    # Mentett session-ök ellenőrzése
    if [ -d /root/.screen-sessions ]; then
        for cmd_file in /root/.screen-sessions/*.cmd 2>/dev/null; do
            [ -f "$cmd_file" ] || continue
            
            NAME=$(basename "$cmd_file" .cmd)
            COMMAND=$(cat "$cmd_file")
            
            # Ha nem fut, újraindítás
            if ! screen -list 2>/dev/null | grep -q "\.${NAME}[[:space:]]"; then
                echo "[SCREEN-WATCHDOG] $(date '+%H:%M:%S') '${NAME}' nem fut, újraindítás..."
                screen -dmS "$NAME" bash -c "
                    echo '🔄 Újraindítva: $(date)'
                    echo 'Parancs: ${COMMAND}'
                    echo ''
                    ${COMMAND}
                    exec bash
                "
                echo "[SCREEN-WATCHDOG] '${NAME}' újraindítva!"
            fi
        done
    fi
done
WATCHDOG

RUN chmod +x /usr/local/bin/screen-watchdog.sh

# ── Shell beállítás ──
RUN cat > /root/.bashrc << 'BASHRC'
export PS1='\[\033[01;32m\]\u@Szaby\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
alias ls='ls --color=auto'
alias ll='ls -lah'
alias cls='clear'
alias neo='neofetch'
alias info='clear && neofetch && echo "" && cat /var/www/html/sftp.txt'
alias cleanup='bash /usr/local/bin/cleanup.sh'
alias mem='free -h && echo "" && df -h /'

# Screen aliasok
alias sl='slist'
alias ss='sstatus'

if [ -t 1 ] && [ ! -f /tmp/.neofetch_shown ]; then
    touch /tmp/.neofetch_shown
    clear
    neofetch 2>/dev/null
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  ✅ Szerver fut! (Keep-Alive aktív)"
    echo "  🔑 Jelszó: 2003"
    echo "  📂 Weboldal: /var/www/html/"
    echo "  📡 SFTP info: cat /var/www/html/sftp.txt"
    echo "═══════════════════════════════════════════════"
    echo "  📺 Screen parancsok:"
    echo "     sstart <név> <parancs>  - Indítás"
    echo "     slist                   - Lista"
    echo "     sattach <név>           - Csatlakozás"
    echo "     sstop <név>             - Leállítás"
    echo "     srestart <név>          - Újraindítás"
    echo "     sstatus                 - Részletes info"
    echo "═══════════════════════════════════════════════"
    echo ""
    
    # Futó screen session-ök megjelenítése
    SCREEN_COUNT=$(screen -list 2>/dev/null | grep -c "\..*(" || echo 0)
    if [ "$SCREEN_COUNT" -gt 0 ]; then
        echo "  📺 Futó screen session-ök: ${SCREEN_COUNT}"
        screen -list 2>/dev/null | grep -E '\t' | while read line; do
            NAME=$(echo "$line" | awk '{print $1}' | cut -d. -f2-)
            echo "     🟢 ${NAME}"
        done
        echo ""
    fi
fi
BASHRC

RUN cp /root/.bashrc /home/admin/.bashrc && \
    chown admin:admin /home/admin/.bashrc

# ── Cleanup script ──
RUN cat > /usr/local/bin/cleanup.sh << 'CLEANUP'
#!/bin/bash
echo "════════════════════════════════════════"
echo "  🧹 MEMÓRIA TISZTÍTÁS"
echo "════════════════════════════════════════"

echo "📊 ELŐTTE:"
free -h | grep Mem
df -h / | grep -v Filesystem

echo ""
echo "🧹 Tisztítás folyamatban..."

echo "  [1/8] Apt cache..."
apt-get clean 2>/dev/null || true
apt-get autoclean 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

echo "  [2/8] Systemd journal..."
journalctl --vacuum-size=50M 2>/dev/null || true
journalctl --vacuum-time=2d 2>/dev/null || true

echo "  [3/8] Tmp fájlok..."
find /tmp -type f -mtime +1 -delete 2>/dev/null || true
find /var/tmp -type f -mtime +1 -delete 2>/dev/null || true

echo "  [4/8] Python cache..."
find /root -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find /home -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
pip3 cache purge 2>/dev/null || true

echo "  [5/8] NPM cache..."
npm cache clean --force 2>/dev/null || true

echo "  [6/8] Régi logok..."
find /var/log -type f -name "*.log.*" -delete 2>/dev/null || true
find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
find /var/log -type f -size +50M -exec truncate -s 10M {} \; 2>/dev/null || true

echo "  [7/8] Supervisor logok..."
truncate -s 0 /var/log/supervisord.log 2>/dev/null || true
truncate -s 0 /var/log/bore.log 2>/dev/null || true
truncate -s 0 /var/log/keepalive.log 2>/dev/null || true

echo "  [8/8] Screen logok (régiek)..."
find /var/log/screen -type f -mtime +3 -delete 2>/dev/null || true

echo ""
echo "✅ KÉSZ!"
echo ""
echo "📊 UTÁNA:"
free -h | grep Mem
df -h / | grep -v Filesystem
echo ""
echo "════════════════════════════════════════"
CLEANUP

RUN chmod +x /usr/local/bin/cleanup.sh

# ── Munkamappák ──
RUN mkdir -p /var/www/html /root/projects /home/admin/projects \
             /root/.screen-sessions && \
    chown -R admin:admin /home/admin

# ── Weboldal ──
RUN cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html lang="hu">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🐧 Linux Server</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{background:#0d1117;color:#c9d1d9;font-family:-apple-system,sans-serif;padding:20px}
        .wrap{max-width:1100px;margin:0 auto}
        h1{color:#58a6ff;text-align:center;font-size:2.5em;margin-bottom:25px}
        .row{display:grid;grid-template-columns:1fr 1fr;gap:15px;margin-bottom:15px}
        .card{background:#161b22;border:1px solid #30363d;border-radius:10px;padding:20px}
        .card h2{color:#7ee787;margin-bottom:12px;font-size:1.2em}
        .full{grid-column:1/-1}
        pre{background:#0d1117;padding:15px;border-radius:6px;color:#7ee787;
            font-family:'Courier New',monospace;font-size:13px;line-height:1.6;
            white-space:pre-wrap;overflow-x:auto}
        .btn{display:block;text-align:center;padding:14px;background:#238636;
            color:#fff;text-decoration:none;border-radius:8px;font-size:16px;
            font-weight:600;margin-top:10px;transition:background .2s}
        .btn:hover{background:#2ea043}
        .status{text-align:center;padding:15px;border-radius:8px;font-size:1.2em;
            font-weight:bold;margin-bottom:15px}
        .active{background:#0d2818;border:1px solid #238636;color:#7ee787}
        .loading{background:#1c1e26;border:1px solid #ffa657;color:#ffa657}
        .keepalive{background:#0d2818;border:1px solid #238636;padding:15px;border-radius:8px;text-align:center;margin-bottom:15px}
        .keepalive h3{color:#7ee787;margin-bottom:5px}
        .keepalive p{color:#8b949e;font-size:13px}
        .info{color:#8b949e;font-size:13px;margin-top:8px}
        @media(max-width:768px){.row{grid-template-columns:1fr}}
    </style>
</head>
<body>
<div class="wrap">
    <h1>🐧 Linux Server</h1>

    <div class="keepalive">
        <h3>⚡ Keep-Alive + Screen AKTÍV</h3>
        <p>Szerver 24/7 fut • Screen session-ök megmaradnak • Automatikus újraindítás</p>
    </div>

    <div class="status" id="status"><span class="loading">🔄 Betöltés...</span></div>

    <div class="row">
        <div class="card">
            <h2>🔐 SSH Csatlakozás</h2>
            <pre id="ssh-info">Betöltés...</pre>
        </div>
        <div class="card">
            <h2>📂 FileZilla (SFTP)</h2>
            <pre id="sftp-info">Betöltés...</pre>
        </div>
    </div>

    <div class="row">
        <div class="card full">
            <h2>🖥️ Web Terminál</h2>
            <a href="/terminal" class="btn" target="_blank">Terminál megnyitása</a>
            <p class="info">Teljes Linux shell - screen session-ök kezelése!</p>
        </div>
    </div>

    <div class="row">
        <div class="card full">
            <h2>🖥️ Beágyazott Terminál</h2>
            <div style="background:#000;border-radius:8px;overflow:hidden;height:500px">
                <iframe src="/terminal" style="width:100%;height:100%;border:none"></iframe>
            </div>
        </div>
    </div>

    <div class="row">
        <div class="card full">
            <h2>📺 Screen Session Kezelés</h2>
            <pre>sstart mybot "python3 bot.py"     # Session indítása
sstart web "node server.js"       # Másik session
slist                              # Futó session-ök
sattach mybot                      # Csatlakozás
  → Ctrl+A, D                     # Leválás (FUT TOVÁBB!)
sstop mybot                        # Leállítás
srestart mybot                     # Újraindítás
sstatus                            # Részletes állapot
sstop all                          # Összes leállítása</pre>
        </div>
    </div>

    <div class="row">
        <div class="card full">
            <h2>📚 Egyéb parancsok</h2>
            <pre>neo               # Neofetch
info              # Rendszer info
mem               # Memória állapot
cleanup           # Memória tisztítás
htop              # Folyamatok</pre>
        </div>
    </div>
</div>

<script>
function load(){
    fetch('/sftp.txt').then(r=>r.text()).then(t=>{
        if(t.includes('AKTIV')){
            document.getElementById('status').innerHTML='<span class="active">✅ Szerver aktív!</span>';
            var lines=t.split('\n');
            var host='',port='';
            lines.forEach(l=>{
                if(l.includes('Host:'))host=l.split('Host:')[1].trim();
                if(l.includes('Port:')&&!l.includes('Protocol'))port=l.split('Port:')[1].trim();
            });
            if(host&&port){
                document.getElementById('ssh-info').textContent=
                    'SSH parancs:\n  ssh root@'+host+' -p '+port+'\n\nJelszó: 2003\n\nPuTTY:\n  Host: '+host+'\n  Port: '+port+'\n  User: root\n  Pass: 2003';
                document.getElementById('sftp-info').textContent=
                    'Protocol: SFTP\nHost: '+host+'\nPort: '+port+'\nUser: root\nPass: 2003\n\nMappa: /var/www/html/';
            }
        } else {
            document.getElementById('status').innerHTML='<span class="loading">⏳ Tunnel indítása...</span>';
            document.getElementById('ssh-info').textContent=t;
            document.getElementById('sftp-info').textContent=t;
        }
    }).catch(()=>{});
}
load();setInterval(load,3000);
</script>
</body>
</html>
HTML

# ── Nginx ──
RUN cat > /etc/nginx/sites-available/default << 'NGINX'
server {
    listen 6969 default_server;
    server_name _;
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /terminal {
        proxy_pass http://127.0.0.1:7681;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_buffering off;
        proxy_cache off;
    }

    location /sftp.txt {
        default_type text/plain;
        add_header Cache-Control "no-cache";
    }
}
NGINX

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6969
CMD ["/start.sh"]
