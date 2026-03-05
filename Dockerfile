FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=10000

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

# Root jelszó beállítása
RUN echo 'root:Linux2024!' | chpasswd

# SSH konfiguráció
RUN sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 120" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config

# SSH kulcsok generálása
RUN ssh-keygen -A

# ── Admin felhasználó létrehozása ──
RUN useradd -m -s /bin/bash admin && \
    echo 'admin:Linux2024!' | chpasswd && \
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
RUN echo '<!DOCTYPE html><html><head><title>Linux Server</title></head><body style="background:#0d1117;color:#58a6ff;font-family:sans-serif;padding:50px;text-align:center;"><h1>🐧 Linux Server Running</h1><p>SSH csatlakozás: Nézd a logokat!</p><pre id="log"></pre><script>fetch("/tunnel.txt").then(r=>r.text()).then(t=>document.getElementById("log").textContent=t);</script></body></html>' > /var/www/html/index.html

# ── Nginx konfiguráció ──
RUN echo 'server { \n\
    listen 10000 default_server; \n\
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

EXPOSE 10000

CMD ["/start.sh"]
