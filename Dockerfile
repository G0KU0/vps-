FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Budapest

# ============================================
# Alap Linux eszközök + neofetch
# ============================================
RUN apt-get update && apt-get install -y \
    # --- Rendszer info ---
    neofetch \
    htop \
    # --- Szerkesztők ---
    vim \
    nano \
    # --- Hálózat ---
    curl \
    wget \
    net-tools \
    iputils-ping \
    dnsutils \
    traceroute \
    nmap \
    # --- Fejlesztés ---
    git \
    python3 \
    python3-pip \
    nodejs \
    npm \
    build-essential \
    # --- Terminál ---
    tmux \
    screen \
    zsh \
    # --- SSH ---
    openssh-server \
    tmate \
    # --- Egyéb ---
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
# VPS felhasználó létrehozása
# ============================================
RUN useradd -m -s /bin/bash vps \
    && echo "vps:changeme123" | chpasswd \
    && usermod -aG sudo vps \
    && echo "vps ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ============================================
# SSH szerver konfiguráció
# ============================================
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# ============================================
# Felhasználói beállítások
# ============================================
# Neofetch automatikus futtatás belépéskor
RUN echo '' >> /home/vps/.bashrc \
    && echo '# Neofetch megjelenítése' >> /home/vps/.bashrc \
    && echo 'neofetch' >> /home/vps/.bashrc \
    && echo '' >> /home/vps/.bashrc \
    && echo '# Szép prompt' >> /home/vps/.bashrc \
    && echo 'export PS1="\[\033[1;32m\]┌──(\[\033[1;34m\]\u@render-vps\[\033[1;32m\])-[\[\033[0;37m\]\w\[\033[1;32m\]]\n└─\[\033[1;34m\]\$\[\033[0m\] "' >> /home/vps/.bashrc

# Home mappa tulajdonos
RUN chown -R vps:vps /home/vps

# ============================================
# Munkamappa
# ============================================
WORKDIR /home/vps

# Startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
