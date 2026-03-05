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
    && rm -rf /var/lib/apt/lists/*

# ── SSH Tunnel eszköz (bore) ──
RUN curl -fsSL \
    https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin/ && chmod +x /usr/local/bin/bore || echo "Bore telepítés kihagyva"

# ── SSH szerver konfigurálása ──
RUN mkdir -p /var/run/sshd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# ── SSH konfiguráció ──
RUN sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 120" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config

# SSH kulcsok generálása
RUN ssh-keygen -A

# ── Admin felhasználó létrehozása ──
RUN useradd -m -s /bin/bash admin && \
    usermod -aG sudo admin && \
    echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p /home/admin/.ssh && \
    chmod 700 /home/admin/.ssh && \
    chown admin:admin /home/admin/.ssh

# ── Neofetch automatikus futtatás bejelentkezéskor ──
RUN echo 'neofetch' >> /root/.bashrc && \
    echo 'neofetch' >> /home/admin/.bashrc && \
    echo 'echo "╔════════════════════════════════════════╗"' >> /root/.bashrc && \
    echo 'echo "║  SSH Tunnel: lásd /var/log/bore.log  ║"' >> /root/.bashrc && \
    echo 'echo "╚════════════════════════════════════════╝"' >> /root/.bashrc

# ── Munkamappák létrehozása ──
RUN mkdir -p /var/www/html && \
    mkdir -p /root/projects && \
    mkdir -p /home/admin/projects && \
    chown -R admin:admin /home/admin/projects

# ── Egyszerű info oldal ──
RUN echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Linux Server</title><style>*{margin:0;padding:0;box-sizing:border-box;}body{background:#0d1117;color:#c9d1d9;font-family:"Segoe UI",sans-serif;min-height:100vh;padding:20px;}.wrap{max-width:900px;margin:0 auto;}h1{text-align:center;color:#58a6ff;margin-bottom:30px;font-size:2.5em;}pre{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:20px;font-family:"Courier New",monospace;font-size:14px;line-height:1.6;color:#7ee787;white-space:pre-wrap;overflow-x:auto;}.info{background:#1c2128;border-left:4px solid #58a6ff;padding:15px 20px;border-radius:0 8px 8px 0;margin-bottom:20px;}.info strong{color:#58a6ff;}.note{background:#1c1e26;border-left:4px solid #ffa657;padding:12px 16px;border-radius:0 6px 6px 0;margin-top:15px;color:#ffa657;font-size:14px;}</style></head><body><div class="wrap"><h1>🐧 Linux Server Dashboard</h1><div class="info"><strong>📡 Port:</strong> 6969 | <strong>🔑 Jelszó:</strong> 2003</div><pre id="log">Betöltés...</pre><div class="note">⚠️ A tunnel port minden újraindításnál változik. Frissítsd az oldalt az aktuális portért!</div></div><script>function load(){fetch("/tunnel.txt").then(r=>r.text()).then(t=>document.getElementById("log").textContent=t||"Várakozás...").catch(()=>{})}load();setInterval(load,5000);</script></body></html>' > /var/www/html/index.html

# ── Nginx konfiguráció ──
RUN echo 'server { \n\
    listen 6969 default_server; \n\
    root /var/www/html; \n\
    index index.html; \n\
    location / { try_files $uri $uri/ =404; } \n\
    location /tunnel.txt { \n\
        default_type text/plain; \n\
        add_header Cache-Control "no-cache"; \n\
    } \n\
}' > /etc/nginx/sites-available/default

# ── Konfigurációs fájlok másolása ──
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6969

CMD ["/start.sh"]
