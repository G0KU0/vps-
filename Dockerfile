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
startup_message off
autodetach on
defscrollback 10000
zombie cr
hardstatus alwayslastline
hardstatus string '%{= kG}[ %{G}%H %{g}][%= %{= kw}%?%-Lw%?%{r}(%{W}%n*%f%t%?(%u)%?%{r})%{w}%?%+Lw%?%?%= %{g}][%{B} %m/%d %{W}%c %{g}]'
defutf8 on
deflog on
logfile /var/log/screen/screenlog.%n.%t
shell -/bin/bash
SCREENRC

# ── Screen konfiguráció (admin) ──
RUN cp /root/.screenrc /home/admin/.screenrc && \
    chown admin:admin /home/admin/.screenrc

# ── Screen log mappa ──
RUN mkdir -p /var/log/screen && chmod 777 /var/log/screen

# ════════════════════════════════════════════════════════
# ── PERSISTENT PROCESS MANAGEMENT (SUPERVISOR ALAPÚ) ──
# ════════════════════════════════════════════════════════

# ── User process config mappa ──
RUN mkdir -p /etc/supervisor/conf.d/user-processes \
             /root/.persistent-cmds \
             /var/log/user-processes \
             /root/.screen-sessions

# ════════════════════════════════════════════════════════
# ── PSTART: Persistent process indítás (JAVÍTOTT!) ──
# ════════════════════════════════════════════════════════
RUN cat > /usr/local/bin/pstart << 'EOF'
#!/bin/bash
# ═══════════════════════════════════════════════════
#  PERSISTENT PROCESS START - Supervisor alapú
#  A folyamat NEM hal meg SSH kilépésnél!
#  Túléli a kapcsolat bontását!
# ═══════════════════════════════════════════════════

if [ $# -lt 2 ]; then
    echo "════════════════════════════════════════════"
    echo "  🚀 PERSISTENT PROCESS INDÍTÁS"
    echo "════════════════════════════════════════════"
    echo ""
    echo "  Használat: pstart <név> <parancs>"
    echo ""
    echo "  Példák:"
    echo "    pstart mybot \"cd /root/discord-bot && node index.js\""
    echo "    pstart webserver \"cd /root/app && node server.js\""
    echo "    pstart loop \"bash /root/myscript.sh\""
    echo "    pstart teszt \"python3 -m http.server 8080\""
    echo "    pstart py \"cd /root/bot && python3 main.py\""
    echo ""
    echo "  ⚡ A folyamat supervisord alatt fut!"
    echo "     SSH kilépés NEM állítja le!"
    echo ""
    echo "  Kezelés:"
    echo "    plist              - Futó folyamatok"
    echo "    pstop <név>        - Leállítás"
    echo "    prestart <név>     - Újraindítás"
    echo "    plog <név>         - Log megtekintés"
    echo "    plog <név> -f      - Élő log"
    echo "    plog <név> err     - Error log"
    echo "    pstatus            - Részletes állapot"
    echo "════════════════════════════════════════════"
    exit 1
fi

PROC_NAME="$1"
shift
COMMAND="$*"

# Érvényes név ellenőrzés
if [[ ! "$PROC_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ Érvénytelen név! Csak betűk, számok, _ és - használható."
    exit 1
fi

CONF_FILE="/etc/supervisor/conf.d/user-${PROC_NAME}.conf"
CMD_FILE="/root/.persistent-cmds/${PROC_NAME}.cmd"
WRAPPER="/usr/local/bin/user-proc-${PROC_NAME}.sh"

# Ha már fut, jelezd
if [ -f "$CONF_FILE" ]; then
    echo "⚠️  '${PROC_NAME}' már létezik!"
    echo "   Újraindítás: prestart ${PROC_NAME}"
    echo "   Leállítás:   pstop ${PROC_NAME}"
    echo "   Felülírás:   pstop ${PROC_NAME} && pstart ${PROC_NAME} \"${COMMAND}\""
    exit 1
fi

echo "🚀 '${PROC_NAME}' indítása supervisor alatt..."

# Mentés
mkdir -p /root/.persistent-cmds
echo "$COMMAND" > "$CMD_FILE"

# JAVÍTOTT wrapper script - exec NÉLKÜL!
cat > "$WRAPPER" << WRAPEOF
#!/bin/bash
echo "════════════════════════════════════════"
echo "  🚀 Persistent Process: ${PROC_NAME}"
echo "  🕐 Indítva: \$(date)"
echo "  📌 Parancs: ${COMMAND}"
echo "  ⚡ Supervisor által kezelve"
echo "════════════════════════════════════════"
echo ""
${COMMAND}
WRAPEOF
chmod +x "$WRAPPER"

# Supervisor config létrehozás - JAVÍTOTT: /bin/bash hívja!
cat > "$CONF_FILE" << CONFEOF
[program:user-${PROC_NAME}]
command=/bin/bash ${WRAPPER}
directory=/root
autostart=true
autorestart=true
startsecs=2
startretries=5
stdout_logfile=/var/log/user-processes/${PROC_NAME}.log
stderr_logfile=/var/log/user-processes/${PROC_NAME}.error.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=5MB
stdout_logfile_backups=2
stderr_logfile_backups=2
CONFEOF

# Supervisor frissítés
supervisorctl reread > /dev/null 2>&1
supervisorctl update > /dev/null 2>&1

sleep 2

# Ellenőrzés
STATUS=$(supervisorctl status "user-${PROC_NAME}" 2>/dev/null | awk '{print $2}')

if [ "$STATUS" = "RUNNING" ]; then
    echo "✅ '${PROC_NAME}' sikeresen elindítva!"
    echo ""
    echo "   📌 Parancs: ${COMMAND}"
    echo "   ⚡ Supervisor által kezelve - SSH kilépés NEM állítja le!"
    echo ""
    echo "   Logok:        plog ${PROC_NAME}"
    echo "   Élő log:      plog ${PROC_NAME} -f"
    echo "   Leállítás:    pstop ${PROC_NAME}"
    echo "   Újraindítás:  prestart ${PROC_NAME}"
elif [ "$STATUS" = "STARTING" ]; then
    echo "⏳ '${PROC_NAME}' indulóban..."
    echo "   Várd meg pár másodpercet, aztán: plist"
else
    echo "⚠️  '${PROC_NAME}' állapot: ${STATUS}"
    echo "   Log: plog ${PROC_NAME}"
    echo "   Error log: plog ${PROC_NAME} err"
fi
EOF

# ════════════════════════════════════════════════════════
# ── PSTOP: Persistent process leállítása ──
# ════════════════════════════════════════════════════════
RUN cat > /usr/local/bin/pstop << 'EOF'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: pstop <név>"
    echo "Összes:    pstop all"
    echo ""
    plist
    exit 1
fi

if [ "$1" = "all" ]; then
    echo "🛑 Összes felhasználói process leállítása..."
    for conf in /etc/supervisor/conf.d/user-*.conf; do
        [ -f "$conf" ] || continue
        NAME=$(basename "$conf" .conf | sed 's/^user-//')
        echo "  ⏹️  ${NAME} leállítása..."
        supervisorctl stop "user-${NAME}" > /dev/null 2>&1
        rm -f "$conf"
        rm -f "/usr/local/bin/user-proc-${NAME}.sh"
        rm -f "/root/.persistent-cmds/${NAME}.cmd"
    done
    supervisorctl reread > /dev/null 2>&1
    supervisorctl update > /dev/null 2>&1
    echo "✅ Összes leállítva!"
    exit 0
fi

PROC_NAME="$1"
CONF_FILE="/etc/supervisor/conf.d/user-${PROC_NAME}.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "❌ '${PROC_NAME}' nem található!"
    echo ""
    plist
    exit 1
fi

echo "⏹️  '${PROC_NAME}' leállítása..."
supervisorctl stop "user-${PROC_NAME}" > /dev/null 2>&1
rm -f "$CONF_FILE"
rm -f "/usr/local/bin/user-proc-${PROC_NAME}.sh"
rm -f "/root/.persistent-cmds/${PROC_NAME}.cmd"
supervisorctl reread > /dev/null 2>&1
supervisorctl update > /dev/null 2>&1

echo "✅ '${PROC_NAME}' leállítva és eltávolítva!"
EOF

# ════════════════════════════════════════════════════════
# ── PLIST: Futó persistent processek listája (JAVÍTOTT!)──
# ════════════════════════════════════════════════════════
RUN cat > /usr/local/bin/plist << 'EOF'
#!/bin/bash
echo "════════════════════════════════════════════"
echo "  🚀 PERSISTENT PROCESSEK"
echo "════════════════════════════════════════════"

HAS_PROCS=false

for conf in /etc/supervisor/conf.d/user-*.conf; do
    [ -f "$conf" ] || continue
    HAS_PROCS=true
    
    NAME=$(basename "$conf" .conf | sed 's/^user-//')
    STATUS_LINE=$(supervisorctl status "user-${NAME}" 2>/dev/null)
    STATUS=$(echo "$STATUS_LINE" | awk '{print $2}')
    
    # Parancs
    CMD=""
    if [ -f "/root/.persistent-cmds/${NAME}.cmd" ]; then
        CMD=$(cat "/root/.persistent-cmds/${NAME}.cmd")
    fi
    
    case "$STATUS" in
        RUNNING)
            PID=$(echo "$STATUS_LINE" | grep -oP 'pid \K\d+')
            UPTIME=$(echo "$STATUS_LINE" | grep -oP 'uptime \K.*')
            echo ""
            echo "  🟢 ${NAME}"
            echo "     Állapot: Fut (PID: ${PID})"
            echo "     Uptime:  ${UPTIME}"
            [ -n "$CMD" ] && echo "     Parancs: ${CMD}"
            ;;
        STOPPED)
            echo ""
            echo "  🔴 ${NAME}"
            echo "     Állapot: Leállítva"
            [ -n "$CMD" ] && echo "     Parancs: ${CMD}"
            ;;
        STARTING)
            echo ""
            echo "  🟡 ${NAME}"
            echo "     Állapot: Indulóban..."
            [ -n "$CMD" ] && echo "     Parancs: ${CMD}"
            ;;
        BACKOFF)
            echo ""
            echo "  🔴 ${NAME}"
            echo "     Állapot: HIBA (BACKOFF)"
            [ -n "$CMD" ] && echo "     Parancs: ${CMD}"
            echo "     Error: plog ${NAME} err"
            ;;
        *)
            echo ""
            echo "  ⚪ ${NAME}"
            echo "     Állapot: ${STATUS}"
            [ -n "$CMD" ] && echo "     Parancs: ${CMD}"
            ;;
    esac
done

if [ "$HAS_PROCS" = false ]; then
    echo ""
    echo "  (nincs persistent process)"
    echo ""
    echo "  Indítás: pstart <név> <parancs>"
fi

echo ""
echo "════════════════════════════════════════════"
echo "  pstart <n> <cmd>  │ pstop <n>  │ prestart <n>"
echo "  plog <n>          │ pstatus    │ pstop all"
echo "════════════════════════════════════════════"
EOF

# ════════════════════════════════════════════════════════
# ── PRESTART: Persistent process újraindítása ──
# ════════════════════════════════════════════════════════
RUN cat > /usr/local/bin/prestart << 'EOF'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: prestart <név>"
    exit 1
fi

PROC_NAME="$1"
CONF_FILE="/etc/supervisor/conf.d/user-${PROC_NAME}.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "❌ '${PROC_NAME}' nem található!"
    plist
    exit 1
fi

echo "🔄 '${PROC_NAME}' újraindítása..."
supervisorctl restart "user-${PROC_NAME}" 2>/dev/null

sleep 1

STATUS=$(supervisorctl status "user-${PROC_NAME}" 2>/dev/null | awk '{print $2}')
if [ "$STATUS" = "RUNNING" ]; then
    echo "✅ '${PROC_NAME}' újraindítva!"
else
    echo "⚠️  Állapot: ${STATUS}"
    echo "   Log: plog ${PROC_NAME}"
fi
EOF

# ════════════════════════════════════════════════════════
# ── PLOG: Persistent process logja ──
# ════════════════════════════════════════════════════════
RUN cat > /usr/local/bin/plog << 'EOF'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: plog <név>        - Utolsó 50 sor"
    echo "           plog <név> -f     - Élő követés"
    echo "           plog <név> err    - Error log"
    exit 1
fi

PROC_NAME="$1"
LOGFILE="/var/log/user-processes/${PROC_NAME}.log"
ERRFILE="/var/log/user-processes/${PROC_NAME}.error.log"

if [ "$2" = "err" ] || [ "$2" = "error" ]; then
    if [ -f "$ERRFILE" ]; then
        echo "═══ ERROR LOG: ${PROC_NAME} ═══"
        tail -50 "$ERRFILE"
    else
        echo "Nincs error log."
    fi
elif [ "$2" = "-f" ] || [ "$2" = "follow" ]; then
    if [ -f "$LOGFILE" ]; then
        echo "═══ ÉLŐ LOG: ${PROC_NAME} (Ctrl+C kilépés) ═══"
        tail -f "$LOGFILE"
    else
        echo "Nincs log fájl még."
    fi
else
    if [ -f "$LOGFILE" ]; then
        echo "═══ LOG: ${PROC_NAME} (utolsó 50 sor) ═══"
        tail -50 "$LOGFILE"
        echo ""
        echo "Élő követés: plog ${PROC_NAME} -f"
        echo "Error log:   plog ${PROC_NAME} err"
    else
        echo "Nincs log fájl még."
    fi
fi
EOF

# ════════════════════════════════════════════════════════
# ── PSTATUS: Részletes állapot ──
# ════════════════════════════════════════════════════════
RUN cat > /usr/local/bin/pstatus << 'EOF'
#!/bin/bash
echo "═══════════════════════════════════════════════════"
echo "  🚀 PERSISTENT PROCESSEK - RÉSZLETES ÁLLAPOT"
echo "═══════════════════════════════════════════════════"
echo ""

# Összes supervisor process
echo "  📊 Supervisor állapot:"
echo "  ─────────────────────────────────────────────"
supervisorctl status 2>/dev/null | while read line; do
    NAME=$(echo "$line" | awk '{print $1}')
    STATUS=$(echo "$line" | awk '{print $2}')
    
    if [[ "$NAME" == user-* ]]; then
        CLEAN_NAME=$(echo "$NAME" | sed 's/^user-//')
        case "$STATUS" in
            RUNNING) ICON="🟢" ;;
            STOPPED) ICON="🔴" ;;
            STARTING) ICON="🟡" ;;
            *) ICON="⚪" ;;
        esac
        echo "    ${ICON} [USER] ${CLEAN_NAME}: ${STATUS}"
    else
        echo "    ⚙️  [SYS]  ${NAME}: ${STATUS}"
    fi
done

echo ""
echo "  📁 Mentett parancsok:"
echo "  ─────────────────────────────────────────────"
if [ -d /root/.persistent-cmds ] && ls /root/.persistent-cmds/*.cmd 1>/dev/null 2>&1; then
    for f in /root/.persistent-cmds/*.cmd; do
        NAME=$(basename "$f" .cmd)
        CMD=$(cat "$f")
        RUNNING=$(supervisorctl status "user-${NAME}" 2>/dev/null | awk '{print $2}')
        if [ "$RUNNING" = "RUNNING" ]; then
            echo "    🟢 ${NAME}: ${CMD}"
        else
            echo "    ⚪ ${NAME}: ${CMD} (nem fut)"
        fi
    done
else
    echo "    (nincs mentett parancs)"
fi

# Screen session-ök is
echo ""
echo "  📺 Screen session-ök:"
echo "  ─────────────────────────────────────────────"
SCREEN_COUNT=$(screen -list 2>/dev/null | grep -c "\..*(" || echo 0)
if [ "$SCREEN_COUNT" -gt 0 ]; then
    screen -list 2>/dev/null | grep -E '\t' | while read line; do
        NAME=$(echo "$line" | awk '{print $1}' | cut -d. -f2-)
        STATE=$(echo "$line" | grep -oP '\((.*?)\)' | tr -d '()')
        echo "    📺 ${NAME} (${STATE})"
    done
else
    echo "    (nincs screen session)"
fi

echo ""
echo "  💾 Memória:"
echo "  ─────────────────────────────────────────────"
free -h | grep Mem | awk '{printf "    RAM: %s / %s (szabad: %s)\n", $3, $2, $4}'
df -h / | tail -1 | awk '{printf "    Disk: %s / %s (%s)\n", $3, $2, $5}'

echo ""
echo "═══════════════════════════════════════════════════"
EOF

# ════════════════════════════════════════════════
# ── SCREEN HELPER SCRIPTEK (JAVÍTOTT setsid-del)
# ════════════════════════════════════════════════

# ── sstart: Screen session indítás (JAVÍTOTT - setsid!) ──
RUN cat > /usr/local/bin/sstart << 'EOF'
#!/bin/bash
# JAVÍTOTT: setsid-del teljesen leválasztja az SSH session-ről!

if [ $# -lt 2 ]; then
    echo "════════════════════════════════════════════"
    echo "  📺 SCREEN SESSION INDÍTÁS"
    echo "════════════════════════════════════════════"
    echo ""
    echo "  Használat: sstart <név> <parancs>"
    echo ""
    echo "  ⚠️  FONTOS: Ha SSH kilépésnél meghal,"
    echo "     használd inkább: pstart <név> <parancs>"
    echo "     (az supervisor alapú, 100% túléli!)"
    echo ""
    echo "  Példák:"
    echo "    sstart mybot \"python3 bot.py\""
    echo "    pstart mybot \"python3 bot.py\"  ← AJÁNLOTT!"
    echo "════════════════════════════════════════════"
    exit 1
fi

SESSION_NAME="$1"
shift
COMMAND="$*"

if screen -list | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    echo "⚠️  '${SESSION_NAME}' már fut!"
    exit 1
fi

mkdir -p /root/.screen-sessions
echo "$COMMAND" > "/root/.screen-sessions/${SESSION_NAME}.cmd"

# ═══ JAVÍTÁS: setsid + nohup ═══
setsid screen -dmS "$SESSION_NAME" bash -c "
    echo '════════════════════════════════════════'
    echo '  📺 Screen: ${SESSION_NAME}'
    echo '  🕐 Indítva: \$(date)'
    echo '  📌 Parancs: ${COMMAND}'
    echo '════════════════════════════════════════'
    echo ''
    ${COMMAND}
    echo ''
    echo '  ⏹️  Program leállt'
    exec bash
" </dev/null &>/dev/null &
disown

sleep 0.5

if screen -list | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    echo "✅ '${SESSION_NAME}' elindítva! (setsid-del leválasztva)"
    echo "   ⚡ Csatlakozás: sattach ${SESSION_NAME}"
else
    echo "❌ Nem indult el! Próbáld: pstart ${SESSION_NAME} \"${COMMAND}\""
fi
EOF

# ── slist: Futó screen session-ök listája ──
RUN cat > /usr/local/bin/slist << 'EOF'
#!/bin/bash
echo "════════════════════════════════════════════"
echo "  📺 SCREEN SESSION-ÖK"
echo "════════════════════════════════════════════"

SESSIONS=$(screen -list 2>/dev/null | grep -E '\t' | grep -v "^$")

if [ -z "$SESSIONS" ]; then
    echo ""
    echo "  (nincs futó screen session)"
    echo ""
    echo "  💡 Tipp: Használd inkább a pstart-ot!"
    echo "     pstart <név> <parancs> - 100% túléli az SSH kilépést"
else
    echo ""
    echo "$SESSIONS" | while read line; do
        NAME=$(echo "$line" | awk '{print $1}' | cut -d. -f2-)
        STATE=$(echo "$line" | grep -oP '\((.*?)\)' | tr -d '()')
        
        if [ "$STATE" = "Detached" ]; then
            ICON="🟢"
        elif [ "$STATE" = "Attached" ]; then
            ICON="🔵"
        else
            ICON="🟡"
        fi
        
        CMD=""
        if [ -f "/root/.screen-sessions/${NAME}.cmd" ]; then
            CMD=" │ $(cat /root/.screen-sessions/${NAME}.cmd)"
        fi
        
        echo "  ${ICON} ${NAME} - ${STATE}${CMD}"
    done
fi
echo ""
echo "════════════════════════════════════════════"
EOF

# ── sattach: Csatlakozás session-höz ──
RUN cat > /usr/local/bin/sattach << 'EOF'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: sattach <session_név>"
    slist
    exit 1
fi
SESSION_NAME="$1"
if screen -list | grep -q "\.${SESSION_NAME}[[:space:]]"; then
    echo "📺 Csatlakozás: ${SESSION_NAME} (Ctrl+A, D = leválás)"
    screen -r "$SESSION_NAME"
else
    echo "❌ '${SESSION_NAME}' nem található!"
    slist
fi
EOF

# ── sstop: Session leállítása ──
RUN cat > /usr/local/bin/sstop << 'EOF'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: sstop <név> | sstop all"
    slist
    exit 1
fi
if [ "$1" = "all" ]; then
    echo "🛑 Összes screen session leállítása..."
    screen -list | grep -oP '\d+\.\K[^\t]+' | while read name; do
        CLEAN_NAME=$(echo "$name" | awk '{print $1}')
        screen -S "$CLEAN_NAME" -X quit 2>/dev/null
        rm -f "/root/.screen-sessions/${CLEAN_NAME}.cmd" 2>/dev/null
        echo "  ⏹️  ${CLEAN_NAME}"
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
fi
EOF

# ── srestart: Session újraindítása ──
RUN cat > /usr/local/bin/srestart << 'EOF'
#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Használat: srestart <név>"
    exit 1
fi
SESSION_NAME="$1"
CMD_FILE="/root/.screen-sessions/${SESSION_NAME}.cmd"
if [ ! -f "$CMD_FILE" ]; then
    echo "❌ Nincs mentett parancs! Használd: sstart"
    exit 1
fi
COMMAND=$(cat "$CMD_FILE")
echo "🔄 '${SESSION_NAME}' újraindítása..."
screen -S "$SESSION_NAME" -X quit 2>/dev/null
sleep 1
sstart "$SESSION_NAME" "$COMMAND"
EOF

# ── sstatus: Részletes állapot ──
RUN cat > /usr/local/bin/sstatus << 'EOF'
#!/bin/bash
pstatus
EOF

# ── Jogosultságok ──
RUN chmod +x /usr/local/bin/sstart \
             /usr/local/bin/slist \
             /usr/local/bin/sattach \
             /usr/local/bin/sstop \
             /usr/local/bin/srestart \
             /usr/local/bin/sstatus \
             /usr/local/bin/pstart \
             /usr/local/bin/pstop \
             /usr/local/bin/plist \
             /usr/local/bin/prestart \
             /usr/local/bin/plog \
             /usr/local/bin/pstatus

# ════════════════════════════════════════════════════════
# ── Persistent process watchdog ──
# ════════════════════════════════════════════════════════
RUN cat > /usr/local/bin/persistent-watchdog.sh << 'EOF'
#!/bin/bash
echo "[WATCHDOG] Persistent process watchdog indítás..."

# Várj amíg a supervisor teljesen elindul
sleep 10

while true; do
    # Screen könyvtár fix
    if [ ! -d /var/run/screen ]; then
        mkdir -p /var/run/screen
        chmod 777 /var/run/screen
        chmod +t /var/run/screen
    fi
    
    # Ellenőrizd hogy a supervisor conf fájlok szinkronban vannak-e
    for cmd_file in /root/.persistent-cmds/*.cmd; do
        [ -f "$cmd_file" ] || continue
        NAME=$(basename "$cmd_file" .cmd)
        CONF="/etc/supervisor/conf.d/user-${NAME}.conf"
        
        # Ha nincs config, de van mentett parancs, hozd létre
        if [ ! -f "$CONF" ]; then
            COMMAND=$(cat "$cmd_file")
            echo "[WATCHDOG] $(date '+%H:%M:%S') '${NAME}' config hiányzik, újralétrehozás..."
            
            WRAPPER="/usr/local/bin/user-proc-${NAME}.sh"
            cat > "$WRAPPER" << WEOF
#!/bin/bash
echo "🔄 Watchdog által újraindítva: \$(date)"
cd /root
${COMMAND}
WEOF
            chmod +x "$WRAPPER"
            
            cat > "$CONF" << CEOF
[program:user-${NAME}]
command=/bin/bash ${WRAPPER}
directory=/root
autostart=true
autorestart=true
startsecs=2
startretries=5
stdout_logfile=/var/log/user-processes/${NAME}.log
stderr_logfile=/var/log/user-processes/${NAME}.error.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=5MB
CEOF
            
            supervisorctl reread > /dev/null 2>&1
            supervisorctl update > /dev/null 2>&1
            echo "[WATCHDOG] '${NAME}' újraindítva!"
        fi
    done
    
    # Screen session-ök ellenőrzése
    if [ -d /root/.screen-sessions ]; then
        for cmd_file in /root/.screen-sessions/*.cmd; do
            [ -f "$cmd_file" ] || continue
            NAME=$(basename "$cmd_file" .cmd)
            COMMAND=$(cat "$cmd_file")
            
            if ! screen -list 2>/dev/null | grep -q "\.${NAME}[[:space:]]"; then
                echo "[WATCHDOG] $(date '+%H:%M:%S') Screen '${NAME}' nem fut, újraindítás..."
                setsid screen -dmS "$NAME" bash -c "${COMMAND}; exec bash" </dev/null &>/dev/null &
            fi
        done
    fi
    
    sleep 30
done
EOF

RUN chmod +x /usr/local/bin/persistent-watchdog.sh

# ════════════════════════════════════════════════════════
# ── Shell beállítás ──
# ════════════════════════════════════════════════════════
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

# Persistent process aliasok
alias pl='plist'
alias ps2='pstatus'

# Screen aliasok
alias sl='slist'
alias ss='sstatus'

if [ -t 1 ] && [ ! -f /tmp/.neofetch_shown_$$ ]; then
    touch /tmp/.neofetch_shown_$$
    clear
    neofetch 2>/dev/null
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  ✅ Szerver fut! (Keep-Alive aktív)"
    echo "  🔑 Jelszó: 2003"
    echo "═══════════════════════════════════════════════"
    echo "  🚀 PERSISTENT PROCESSEK (AJÁNLOTT!):"
    echo "     pstart <név> <parancs>  - Indítás"
    echo "     plist                   - Lista"
    echo "     pstop <név>             - Leállítás"
    echo "     prestart <név>          - Újraindítás"
    echo "     plog <név>              - Log"
    echo "     plog <név> -f           - Élő log"
    echo "     pstatus                 - Részletes info"
    echo "  ─────────────────────────────────────────────"
    echo "  📺 Screen (alternatíva):"
    echo "     sstart / slist / sattach / sstop"
    echo "═══════════════════════════════════════════════"
    echo ""
    
    # Persistent processek
    PROC_COUNT=$(ls /etc/supervisor/conf.d/user-*.conf 2>/dev/null | wc -l)
    if [ "$PROC_COUNT" -gt 0 ]; then
        echo "  🚀 Persistent processek: ${PROC_COUNT}"
        for conf in /etc/supervisor/conf.d/user-*.conf; do
            [ -f "$conf" ] || continue
            NAME=$(basename "$conf" .conf | sed 's/^user-//')
            STATUS=$(supervisorctl status "user-${NAME}" 2>/dev/null | awk '{print $2}')
            [ "$STATUS" = "RUNNING" ] && ICON="🟢" || ICON="🔴"
            echo "     ${ICON} ${NAME} (${STATUS})"
        done
        echo ""
    fi
    
    # Screen session-ök
    SCREEN_COUNT=$(screen -list 2>/dev/null | grep -c "\..*(" || echo 0)
    if [ "$SCREEN_COUNT" -gt 0 ]; then
        echo "  📺 Screen session-ök: ${SCREEN_COUNT}"
        screen -list 2>/dev/null | grep -E '\t' | while read line; do
            NAME=$(echo "$line" | awk '{print $1}' | cut -d. -f2-)
            echo "     📺 ${NAME}"
        done
        echo ""
    fi
fi
BASHRC

RUN cp /root/.bashrc /home/admin/.bashrc && \
    chown admin:admin /home/admin/.bashrc

# ════════════════════════════════════════════════════════
# ── Cleanup script ──
# ════════════════════════════════════════════════════════
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

echo "  [8/8] Screen és process logok (régiek)..."
find /var/log/screen -type f -mtime +3 -delete 2>/dev/null || true
find /var/log/user-processes -type f -size +50M -exec truncate -s 5M {} \; 2>/dev/null || true

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
             /root/.screen-sessions /root/.persistent-cmds \
             /var/log/user-processes && \
    chown -R admin:admin /home/admin

# ════════════════════════════════════════════════════════
# ── Weboldal ──
# ════════════════════════════════════════════════════════
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
        <h3>⚡ Keep-Alive + Persistent Processes AKTÍV</h3>
        <p>Szerver 24/7 fut • Processek túlélik az SSH kilépést • Automatikus újraindítás</p>
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
            <p class="info">Teljes Linux shell - persistent processek kezelése!</p>
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
            <h2>🚀 Persistent Process Kezelés (AJÁNLOTT!)</h2>
            <pre>pstart mybot "cd /root/bot && node index.js"  # Process indítása
pstart web "cd /root/app && node server.js"    # Másik process
plist                                           # Futó processek
plog mybot                                      # Log megtekintés
plog mybot -f                                   # Élő log követés
plog mybot err                                  # Error log
prestart mybot                                  # Újraindítás
pstop mybot                                     # Leállítás
pstatus                                         # Részletes állapot
pstop all                                       # Összes leállítása

⚡ Supervisor alapú - 100% túléli az SSH kilépést!</pre>
        </div>
    </div>

    <div class="row">
        <div class="card full">
            <h2>📺 Screen Session Kezelés (alternatíva)</h2>
            <pre>sstart mybot "python3 bot.py"     # Session indítása
slist                              # Lista
sattach mybot                      # Csatlakozás
  → Ctrl+A, D                     # Leválás
sstop mybot                        # Leállítás</pre>
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

# ════════════════════════════════════════════════════════
# ── Nginx ──
# ════════════════════════════════════════════════════════
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
