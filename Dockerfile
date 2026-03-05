FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Budapest

# ============================================
# Alap csomagok (TELJES LISTA)
# ============================================
RUN apt-get update && apt-get install -y \
    # Rendszer monitoring
    neofetch \
    htop \
    procps \
    psmisc \
    lsof \
    # Szerkesztők
    vim \
    nano \
    # Hálózat
    curl \
    wget \
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    traceroute \
    nmap \
    # Fejlesztés
    git \
    python3 \
    python3-pip \
    nodejs \
    npm \
    build-essential \
    # Terminál
    tmux \
    screen \
    zsh \
    # SSH/SFTP
    openssh-server \
    tmate \
    # Egyéb
    sudo \
    unzip \
    zip \
    tar \
    tree \
    jq \
    locales \
    software-properties-common \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Locale beállítás
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
# bore (TCP tunnel - PuTTY/FileZilla SSH/SFTP)
# ============================================
RUN curl -fsSL https://github.com/ekzhang/bore/releases/download/v0.5.2/bore-v0.5.2-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/bore

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
# Bash beállítások
# ============================================
RUN echo '' >> /root/.bashrc \
    && echo 'neofetch' >> /root/.bashrc \
    && echo '' >> /root/.bashrc \
    && echo 'export PS1="\[\033[1;31m\]┌──(\[\033[1;34m\]root@render-vps\[\033[1;31m\])-[\[\033[0;37m\]\w\[\033[1;31m\]]\n└─\[\033[1;34m\]#\[\033[0m\] "' >> /root/.bashrc \
    && echo 'export TERM=xterm-256color' >> /root/.bashrc \
    && echo 'alias ll="ls -lah"' >> /root/.bashrc \
    && echo 'alias info="cat /tmp/ssh-info.txt"' >> /root/.bashrc

WORKDIR /root

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
