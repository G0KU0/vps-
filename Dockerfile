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

# ── ngrok telepítése (stabilabb mint bore) ──
RUN curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
    tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
    tee /etc/apt/sources.list.d/ngrok.list && \
    apt update && apt install ngrok && \
    rm -rf /var/lib/apt/lists/*

# ── Fallback: bore is telepítve ──
RUN curl -fsSL \
    https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin/ && chmod +x /usr/local/bin/bore || true

# ── SSH szerver beállítása ──
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh

# SSH konfig - engedékenyebb beállítások
RUN echo "Port 22" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "UsePAM yes" >> /etc/ssh/sshd_config && \
    echo "X11Forwarding no" >> /etc/ssh/sshd_config && \
    echo "PrintMotd no" >> /etc/ssh/sshd_config && \
    echo "AcceptEnv LANG LC_*" >> /etc/ssh/sshd_config && \
    echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 120" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 720" >> /etc/ssh/sshd_config && \
    echo "TCPKeepAlive yes" >> /etc/ssh/sshd_config

# SSH kulcsok
RUN ssh-keygen -A

# ── Felhasználók ──
RUN useradd -m -s /bin/bash admin && \
    usermod -aG sudo admin && \
    echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    mkdir -p /home/admin/.ssh && \
    chmod 700 /home/admin/.ssh && \
    chown admin:admin /home/admin/.ssh

# ── Neofetch ──
RUN echo 'neofetch' >> /root/.bashrc && \
    echo 'neofetch' >> /home/admin/.bashrc && \
    echo 'echo "═══════════════════════════════════"' >> /root/.bashrc && \
    echo 'echo "SSH: cat /var/www/html/tunnel.txt"' >> /root/.bashrc && \
    echo 'echo "═══════════════════════════════════"' >> /root/.bashrc

# ── Mappák ──
RUN mkdir -p /var/www/html /root/projects /home/admin/projects && \
    chown -R admin:admin /home/admin/projects

# ── Info oldal ──
RUN echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>SSH Server</title><style>*{margin:0;padding:0;box-sizing:border-box}body{background:#0d1117;color:#c9d1d9;font-family:monospace;padding:20px}.box{max-width:800px;margin:0 auto;background:#161b22;border:1px solid #30363d;border-radius:8px;padding:20px}h1{color:#58a6ff;margin-bottom:20px}pre{background:#0d1117;padding:15px;border-radius:6px;color:#7ee787;overflow-x:auto;white-space:pre-wrap}</style></head><body><div class="box"><h1>🐧 SSH Server</h1><pre id="info">Betöltés...</pre></div><script>function load(){fetch("/tunnel.txt").then(r=>r.text()).then(t=>document.getElementById("info").textContent=t).catch(()=>{})}load();setInterval(load,3000)</script></body></html>' > /var/www/html/index.html

# ── Nginx ──
RUN echo 'server{listen 6969;root /var/www/html;index index.html;location /{try_files $uri $uri/ =404;}location /tunnel.txt{default_type text/plain;add_header Cache-Control "no-cache";}}' > /etc/nginx/sites-available/default

# ── Másolás ──
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6969

CMD ["/start.sh"]
