FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Budapest

# ============================================
# Alap csomagok
# ============================================
RUN apt-get update && apt-get install -y \
    neofetch \
    htop \
    vim \
    nano \
    curl \
    wget \
    net-tools \
    iputils-ping \
    dnsutils \
    traceroute \
    nmap \
    git \
    python3 \
    python3-pip \
    nodejs \
    npm \
    build-essential \
    tmux \
    screen \
    zsh \
    openssh-server \
    tmate \
    sudo \
    unzip \
    zip \
    tar \
    tree \
    jq \
    locales \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Locale
# ============================================
RUN locale-gen en_US.UTF-8 && locale-gen hu_HU.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ============================================
# ttyd (Web Terminal)
# ============================================
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
    -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

# ============================================
# Cloudflared (SSH/SFTP tunnel)
# ============================================
RUN curl -fsSL \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared

# ============================================
# SSH szerver (SFTP támogatással)
# ============================================
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config

# ============================================
# Munkamappák
# ============================================
RUN mkdir -p /root/projects \
    && mkdir -p /root/uploads \
    && mkdir -p /root/downloads \
    && mkdir -p /root/scripts

# ============================================
# Bash beállítások + neofetch
# ============================================
RUN echo '' >> /root/.bashrc \
    && echo '# Neofetch' >> /root/.bashrc \
    && echo 'neofetch' >> /root/.bashrc \
    && echo '' >> /root/.bashrc \
    && echo '# Prompt' >> /root/.bashrc \
    && echo 'export PS1="\[\033[1;31m\]┌──(\[\033[1;34m\]root@render-vps\[\033[1;31m\])-[\[\033[0;37m\]\w\[\033[1;31m\]]\n└─\[\033[1;34m\]#\[\033[0m\] "' >> /root/.bashrc \
    && echo '' >> /root/.bashrc \
    && echo 'export TERM=xterm-256color' >> /root/.bashrc

WORKDIR /root

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
