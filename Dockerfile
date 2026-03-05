FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Budapest

# ============================================
# Alap Linux eszközök + neofetch
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
# Locale beállítás
# ============================================
RUN locale-gen en_US.UTF-8 && locale-gen hu_HU.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ============================================
# ttyd (Web Terminal) telepítés
# ============================================
RUN curl -fsSL \
    https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
    -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

# ============================================
# SSH szerver konfiguráció
# ============================================
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A

# ============================================
# Bash beállítások (root userhez)
# ============================================
RUN echo '' >> /root/.bashrc \
    && echo '# Neofetch megjelenítése' >> /root/.bashrc \
    && echo 'neofetch' >> /root/.bashrc \
    && echo '' >> /root/.bashrc \
    && echo '# Szép prompt' >> /root/.bashrc \
    && echo 'export PS1="\[\033[1;31m\]┌──(\[\033[1;34m\]root@render-vps\[\033[1;31m\])-[\[\033[0;37m\]\w\[\033[1;31m\]]\n└─\[\033[1;34m\]#\[\033[0m\] "' >> /root/.bashrc

# ============================================
# Munkamappa
# ============================================
WORKDIR /root

# Startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
