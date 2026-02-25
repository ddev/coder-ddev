FROM ubuntu:24.04

# Install curl and wget (required for Coder agent download)
# Also install passwd package which contains useradd command
# Install sudo so coder user can run privileged commands in startup script
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  apt-transport-https \
  autojump \
  bash-completion \
  build-essential \
  ca-certificates \
  curl \
  direnv \
  git \
  gnupg \
  httpie \
  inetutils-ping \
  less \
  locales \
  lsb-release \
  make \
  nano \
  openssh-client \
  passwd \
  software-properties-common \
  sudo \
  unzip \
  vim \
  wget && \
  # Generate locale
  locale-gen en_US.UTF-8 && \
  rm -rf /var/lib/apt/lists/* && \
  # Configure sudo for coder user (passwordless sudo for all commands)
  # Allow DEBIAN_FRONTEND environment variable
  echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers.d/coder && \
  echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder && \
  chmod 0440 /etc/sudoers.d/coder

# Rename ubuntu user (UID 1000) to coder and update home directory
# Ubuntu base image already has a user with UID 1000, so we rename it
RUN if id -u ubuntu > /dev/null 2>&1; then \
  usermod -l coder -d /home/coder -m ubuntu && \
  groupmod -n coder ubuntu && \
  chown -R coder:coder /home/coder; \
  elif ! id -u coder > /dev/null 2>&1; then \
  useradd -m -u 1000 -s /bin/bash coder; \
  fi

# Install additional utilities
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  python3 \
  jq \
  bzip2 && \
  rm -rf /var/lib/apt/lists/*

# Install Node.js 24.x LTS via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs && \
  rm -rf /var/lib/apt/lists/* && \
  # Verify Node.js installation
  node --version && \
  npm --version


# Create system-wide PATH configuration for non-interactive shells
# This ensures ~/.local/bin is in PATH even for scripts and non-interactive shells
USER root
RUN echo 'export PATH="/home/coder/.local/bin:$PATH"' > /etc/profile.d/coder-path.sh && \
  chmod 644 /etc/profile.d/coder-path.sh && \
  # Also add to /etc/environment for systemd and other services
  (grep -q "/home/coder/.local/bin" /etc/environment || \
  sed -i 's|^PATH=.*|PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/coder/.local/bin"|' /etc/environment || \
  echo 'PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/coder/.local/bin"' >> /etc/environment) && \
  # Ensure PATH is exported in non-interactive shells
  echo 'export PATH="/home/coder/.local/bin:$PATH"' >> /etc/bash.bashrc
USER coder


RUN npm install -g @fission-ai/openspec@latest typescript 2>/dev/null || \
  echo "Warning: npm global installation failed, will be retried in startup script"


# Install Docker CLI (for Docker-in-Docker)
# We install from the official Docker repository
USER root
RUN mkdir -p /etc/apt/keyrings && \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes && \
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  noble stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
  apt-get update && \
  # Install full Docker Daemon (docker-ce) and systemd for Sysbox
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin \
  systemd \
  systemd-sysv && \
  rm -rf /var/lib/apt/lists/* && \
  # Enable Docker service
  systemctl enable docker

# Install DDEV using official package installation method
# https://docs.ddev.com/en/stable/users/install/ddev-installation/#ddev-installation-linux
USER root
RUN curl -fsSL https://pkg.ddev.com/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/ddev.gpg --yes && \
  chmod a+r /etc/apt/keyrings/ddev.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/ddev.gpg] https://pkg.ddev.com/apt/ * *" > /etc/apt/sources.list.d/ddev.list && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ddev && \
  rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/linuxbrew/.linuxbrew && chown -R coder:coder /home/linuxbrew/

USER coder
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
RUN /home/linuxbrew/.linuxbrew/bin/brew tap bats-core/bats-core && \
  /home/linuxbrew/.linuxbrew/bin/brew install \
  bats-core \
  bats-support \
  bats-file \
  bats-assert \
  go \
  golangci-lint \
  yq

USER root
# Symlink brew-installed tools to /usr/local/bin so they're available system-wide
# (brew installs to /home/linuxbrew which is only in PATH for interactive shells)
RUN ln -sf /home/linuxbrew/.linuxbrew/bin/yq /usr/local/bin/yq

# Copy scripts last — changes here are frequent and should not bust the
# expensive layers above (Node, Docker, DDEV, Homebrew).
USER root
COPY --chown=coder:coder scripts /home/coder-files
RUN chmod 644 /home/coder-files/WELCOME.txt && \
  chmod 644 /home/coder-files/.vscode/settings.json && \
  chmod 644 /home/coder-files/.ddev/global_config.yaml && \
  chmod 755 /home/coder-files/.ddev/commands/host/launch && \
  chmod 755 /home/coder-files/.ddev/commands/host/coder-routes

USER coder
RUN ddev --version && \
  docker --version && \
  /home/linuxbrew/.linuxbrew/bin/go version && \
  yq --version
