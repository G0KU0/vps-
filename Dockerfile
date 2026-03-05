FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PORT=6969
ENV SSH_PASSWORD="2003"

# ── Alapcsomagok ──
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
    python3 \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ── Bore tunnel (egyszerűbb mint ngrok) ──
RUN curl -fsSL \
    https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin/ && chmod +x /usr/local/bin/bore || true

# ── SSH mappa ──
RUN mkdir -p /var/run/sshd /root/.ssh && chmod 700 /root/.ssh

# ── MINIMÁLIS SSH konfig (csak a szükséges) ──
RUN cat > /etc/ssh/sshd_config << 'EOF'
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
UsePAM no
PrintMotd no
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# ── SSH kulcsok ──
RUN ssh-keygen -A

# ── PAM kikapcsolása SSH-hoz (hogy ne crasheljen) ──
RUN echo "# SSH without PAM" > /etc/pam.d/sshd

# ── Admin felhasználó ──
RUN useradd -m -s /bin/bash admin && \
    usermod -aG sudo admin && \
    echo 'admin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# ── TISZTA .bashrc (semmi fancy, ami crashelhetne) ──
RUN echo 'export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' > /root/.bashrc && \
    echo 'alias ls="ls --color=auto"' >> /root/.bashrc && \
    echo 'alias ll="ls -lah"' >> /root/.bashrc && \
    echo '' >> /root/.bashrc && \
    echo '# Neofetch csak ha terminál van' >> /root/.bashrc && \
    echo 'if [ -t 1 ]; then' >> /root/.bashrc && \
    echo '    command -v neofetch >/dev/null 2>&1 && neofetch' >> /root/.bashrc && \
    echo 'fi' >> /root/.bashrc

RUN cp /root/.bashrc /home/admin/.bashrc && \
    chown admin:admin /home/admin/.bashrc

# ── Munkamappák ──
RUN mkdir -p /var/www/html /root/projects /home/admin/projects && \
    chown -R admin:admin /home/admin

# ── Egyszerű weboldal ──
RUN cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>SSH Server</title>
<style>
body{background:#0d1117;color:#7ee787;font-family:monospace;padding:30px;margin:0}
.box{max-width:800px;margin:0 auto;background:#161b22;padding:20px;border-radius:8px;border:1px solid #30363d}
h1{color:#58a6ff;text-align:center;margin:0 0 20px 0}
pre{background:#0d1117;padding:15px;border-radius:6px;overflow-x:auto;white-space:pre-wrap;line-height:1.6}
</style></head><body>
<div class="box">
<h1>🐧 SSH Server</h1>
<pre id="info">Betöltés...</pre>
</div>
<script>
function load(){fetch('/tunnel.txt').then(r=>r.text()).then(t=>document.getElementById('info').textContent=t)}
load();setInterval(load,3000);
</script>
</body></html>
HTML

# ── Nginx ──
RUN echo 'server{listen 6969;root /var/www/html;index index.html;location /{try_files $uri $uri/ =404;}location /tunnel.txt{default_type text/plain;add_header Cache-Control no-cache;}}' > /etc/nginx/sites-available/default

# ── Fájlok ──
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6969
CMD ["/start.sh"]
