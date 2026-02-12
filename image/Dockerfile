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

# Copy scripts and configuration files to /home/coder-files (outside volume mount)
# The volume mount at /home/coder overrides image contents, so we copy to coder-files
# Files will be copied to ~/.ddev after ddev installation to prevent ddev from overwriting them
# This ensures ddev doesn't overwrite our custom configuration during installation
COPY --chown=coder:coder scripts /home/coder-files


# Set correct permissions for scripts in init-scripts
RUN chmod 644 /home/coder-files/WELCOME.txt && \
  chmod 644 /home/coder-files/.vscode/settings.json

# Install Python3, pip, and pipx (required for Goose CLI installation)
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  python3 \
  python3-pip \
  python3-venv \
  jq \
  bzip2 \
  libxcb1 \
  pipx && \
  rm -rf /var/lib/apt/lists/*

# Install Node.js (required for task-master-ai and cursor-agent)
# Install Node.js 22.x LTS via NodeSource (supports --use-system-ca option)
# The --use-system-ca option requires Node.js 18.19.0+ or 20.0.0+
# Node.js 22.x is the latest LTS and fully supports this option
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs && \
  rm -rf /var/lib/apt/lists/* && \
  # Verify Node.js installation
  node --version && \
  npm --version

# Install task-master-ai and cursor-agent as coder user
# Configure npm to install global packages in user directory to avoid permission issues
USER coder
RUN mkdir -p /home/coder/.npm-global && \
  npm config set prefix '/home/coder/.npm-global' && \
  echo 'export PATH="/home/coder/.npm-global/bin:$PATH"' >> /home/coder/.bashrc && \
  echo 'export PATH="/home/coder/.npm-global/bin:$PATH"' >> /home/coder/.profile && \
  echo 'export PATH="/home/coder/.npm-global/bin:$PATH"' >> /home/coder/.bash_profile && \
  # Add local bin directory to PATH for Goose
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/coder/.bashrc && \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/coder/.profile && \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/coder/.bash_profile

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


# We do NOT pre-install the old Python version here anymore

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
  golangci-lint

RUN ddev --version && \
  docker --version && \
  go version
