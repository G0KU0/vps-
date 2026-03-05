FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=6969
ENV SSH_PASSWORD="2003"

# ── Alapvető csomagok telepítése ──
RUN apt-get update && apt-get install -y \
    openssh-server \
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
    iputils-ping \
    dnsutils \
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
    && rm -rf /var/lib/apt/lists/*

# ── ngrok telepítése ──
RUN curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
    tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
    tee /etc/apt/sources.list.d/ngrok.list && \
    apt update && apt install ngrok && \
    rm -rf /var/lib/apt/lists/*

# ── Bore fallback ──
RUN curl -fsSL \
    https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin/ && chmod +x /usr/local/bin/bore || true

# ── SSH szerver beállítása ──
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh

# ── SSH konfiguráció (FIX: UsePAM no!) ──
RUN cat > /etc/ssh/sshd_config << 'SSHCONF'
# SSH Server Configuration - Render.com optimized
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Logging
SyslogFacility AUTH
LogLevel INFO

# Authentication
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# FIX: PAM kikapcsolása (audit hiba elkerülése)
UsePAM no

# Network
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 120
ClientAliveCountMax 720

# SFTP Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server
SSHCONF

# SSH kulcsok generálása
RUN ssh-keygen -A

# ── PAM konfiguráció módosítása (audit nélkül) ──
RUN if [ -f /etc/pam.d/sshd ]; then \
        sed -i '/pam_loginuid.so/d' /etc/pam.d/sshd; \
        sed -i '/pam_audit.so/d' /etc/pam.d/sshd; \
    fi

# ── Felhasználók létrehozása ──
RUN useradd -m -s /bin/bash admin && \
    usermod -aG sudo admin && \
    echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p /home/admin/.ssh && \
    chmod 700 /home/admin/.ssh && \
    chown admin:admin /home/admin/.ssh

# ── Neofetch bejelentkezéskor ──
RUN echo 'clear' >> /root/.bashrc && \
    echo 'neofetch' >> /root/.bashrc && \
    echo 'echo ""' >> /root/.bashrc && \
    echo 'echo "═══════════════════════════════════════════════"' >> /root/.bashrc && \
    echo 'echo "  ✅ Sikeres bejelentkezés!"' >> /root/.bashrc && \
    echo 'echo "  📂 Weboldal: cd /var/www/html"' >> /root/.bashrc && \
    echo 'echo "  📡 Tunnel: cat /var/www/html/tunnel.txt"' >> /root/.bashrc && \
    echo 'echo "═══════════════════════════════════════════════"' >> /root/.bashrc && \
    echo 'echo ""' >> /root/.bashrc

RUN echo 'clear' >> /home/admin/.bashrc && \
    echo 'neofetch' >> /home/admin/.bashrc && \
    echo 'echo ""' >> /home/admin/.bashrc && \
    echo 'echo "═══════════════════════════════════════════════"' >> /home/admin/.bashrc && \
    echo 'echo "  ✅ Admin felhasználó - teljes sudo jog"' >> /home/admin/.bashrc && \
    echo 'echo "  📂 Weboldal: cd /var/www/html"' >> /home/admin/.bashrc && \
    echo 'echo "═══════════════════════════════════════════════"' >> /home/admin/.bashrc && \
    echo 'echo ""' >> /home/admin/.bashrc

# ── Munkamappák ──
RUN mkdir -p /var/www/html /root/projects /home/admin/projects && \
    chown -R admin:admin /home/admin/projects

# ── Info oldal ──
RUN cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🐧 SSH Server</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: #0d1117;
            color: #c9d1d9;
            font-family: 'Courier New', monospace;
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
        }
        h1 {
            color: #58a6ff;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        .box {
            background: #161b22;
            border: 1px solid #30363d;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
        }
        pre {
            background: #0d1117;
            padding: 15px;
            border-radius: 6px;
            color: #7ee787;
            overflow-x: auto;
            white-space: pre-wrap;
            line-height: 1.5;
            font-size: 14px;
        }
        .status {
            text-align: center;
            color: #ffa657;
            font-size: 1.3em;
            margin-bottom: 15px;
            font-weight: bold;
        }
        .active { color: #7ee787; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐧 Linux SSH Server</h1>
        <div class="status" id="status">🔄 Betöltés...</div>
        <div class="box">
            <pre id="info">Tunnel információ betöltése...</pre>
        </div>
    </div>
    <script>
        function load() {
            fetch('/tunnel.txt')
                .then(r => r.text())
                .then(t => {
                    document.getElementById('info').textContent = t;
                    const statusEl = document.getElementById('status');
                    if (t.includes('✅')) {
                        statusEl.textContent = '✅ SSH Szerver aktív!';
                        statusEl.className = 'status active';
                    } else {
                        statusEl.textContent = '⏳ Tunnel indítása folyamatban...';
                        statusEl.className = 'status';
                    }
                })
                .catch(() => {
                    document.getElementById('info').textContent = '❌ Hiba a betöltéskor!';
                });
        }
        load();
        setInterval(load, 3000);
    </script>
</body>
</html>
HTML

# ── Nginx konfiguráció ──
RUN cat > /etc/nginx/sites-available/default << 'NGINX'
server {
    listen 6969 default_server;
    root /var/www/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /tunnel.txt {
        default_type text/plain;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }
}
NGINX

# ── Fájlok másolása ──
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6969

CMD ["/start.sh"]
