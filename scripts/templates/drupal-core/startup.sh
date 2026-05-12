#!/usr/bin/env bash
# scripts/templates/drupal-core/startup.sh
# Workspace startup script for the drupal-core template.
#
# Required env vars (set on coder_agent.env in drupal-core/template.tf):
#   REGISTRY_MIRROR   - Docker registry mirror URL (from var.docker_registry_mirror).
#                       May be empty; startup auto-detects http://<coder-host>:5000 if reachable.
#   ISSUE_FORK        - Fork URL for issue branch; may be empty (from data.coder_parameter.issue_fork.value).
#   ISSUE_BRANCH      - Issue branch name; may be empty (from data.coder_parameter.issue_branch.value).
#   INSTALL_PROFILE   - Drupal install profile; may be empty (from data.coder_parameter.install_profile.value).
#   DRUPAL_VERSION    - Major Drupal version (from data.coder_parameter.drupal_version.value).
#
# Exit codes:
#   0   - workspace ready
#   1   - generic failure
#
# Idempotency: yes — safe to re-run on workspace restart.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="${SCRIPT_DIR}/../../shared"
# shellcheck source=../../shared/lib.sh
. "${SHARED_DIR}/lib.sh"

# Conditionally source shared helpers when WP06 ships them.
# Pre-WP06 they don't exist; the [ -f ] guard makes this a no-op.
for _helper in start-dockerd hydrate-coder-files install-ddev-config configure-git-ssh; do
  if [ -f "${SHARED_DIR}/${_helper}.sh" ]; then
    # shellcheck source=/dev/null
    . "${SHARED_DIR}/${_helper}.sh"
  fi
done
unset _helper

    #!/bin/bash
    # Don't exit on error - let installation continue even if some steps fail
    set +e

    echo "Startup script started..."
    SCRIPT_START=$SECONDS

    # Define Sudo Command
    if command -v sudo > /dev/null 2>&1; then
      SUDO="sudo"
    else
      SUDO=""
    fi

    # Fix permissions for Host Bind Mount
    # Since we are mounting /home/coder from the host (which might be owned by a different UID),
    # we need to ensure the container user owns it.

    # Standard Home Directory Strategy for Sysbox
    # We mount the persistent volume directly to /home/coder.
    # No need to rewrite /etc/passwd or change HOME environment variable manually.
    
    # Ensure ownership of /home/coder
    # Since the volume comes from the host, it might have host permissions.
    # We fix this on every startup.
    sudo chown coder:coder /home/coder

    # Copy defaults if empty (first run)
    if [ ! -f "/home/coder/.bashrc" ]; then
        echo "Initializing home directory..."
        cp -rT /etc/skel/. /home/coder/
    fi

    cd /home/coder

    echo "=========================================="
    echo "Starting workspace setup..."
    echo "=========================================="
    echo "Workspace Home: $HOME"
    
    
    # Ensure GIT_SSH_COMMAND is set (Coder sets this automatically, but we ensure it's available)
    # The Coder GitSSH wrapper is located in /tmp/coder.*/coder and handles authentication
    if [ -z "$GIT_SSH_COMMAND" ]; then
      # Try to find the Coder GitSSH wrapper
      CODER_GITSSH=$(find /tmp -name "coder" -path "*/coder.*/*" -type f -executable 2>/dev/null | head -1)
      if [ -n "$CODER_GITSSH" ]; then
        export GIT_SSH_COMMAND="$CODER_GITSSH gitssh"
        # DO NOT persist this to .bashrc as the path changes per session!
        echo "✓ Coder GitSSH wrapper found and configured for this session"
      else
        echo "Note: Coder GitSSH wrapper not found. Git operations may require manual SSH key setup."
        echo "Get your public key with: coder publickey"
      fi
    else
      echo "✓ GIT_SSH_COMMAND already set: $GIT_SSH_COMMAND"
    fi
    
    echo "✓ SSH setup completed"


    echo ""

    echo ""
    
    # Copy files from /home/coder-files to /home/coder
    # The volume mount at /home/coder overrides image contents, but /home/coder-files is outside the mount
    echo "Copying files from /home/coder-files to ~/..."
    if [ -d /home/coder-files ]; then
      if [ -d /home/coder-files/.vscode ]; then
        mkdir -p ~/.vscode
        if [ -f /home/coder-files/.vscode/settings.json ]; then
          cp /home/coder-files/.vscode/settings.json ~/.vscode/settings.json
          chown coder:coder ~/.vscode/settings.json 2>/dev/null || true
        fi
      fi
    else
      echo "Warning: /home/coder-files not found in image"
    fi

    # Git configuration: copy defaults on first run, set identity from Coder owner
    if [ ! -f "$HOME/.gitconfig" ] && [ -f /home/coder-files/.gitconfig ]; then
      cp /home/coder-files/.gitconfig "$HOME/.gitconfig"
    fi
    if [ ! -f "$HOME/.gitignore_global" ] && [ -f /home/coder-files/.gitignore_global ]; then
      cp /home/coder-files/.gitignore_global "$HOME/.gitignore_global"
    elif [ -f "$HOME/.gitignore_global" ]; then
      grep -qxF 'config.coder.yaml' "$HOME/.gitignore_global" || \
        echo 'config.coder.yaml' >> "$HOME/.gitignore_global"
    fi
    if [ -n "$CODER_WORKSPACE_OWNER_NAME" ]; then
      git config --global user.name "$CODER_WORKSPACE_OWNER_NAME"
    fi
    if [ -n "$CODER_WORKSPACE_OWNER_EMAIL" ]; then
      git config --global user.email "$CODER_WORKSPACE_OWNER_EMAIL"
    fi

    # Install Docker CLI (Required for DDEV DooD)
    # Docker CLI is now pre-installed in the Docker image (v3.0.29+)
    if ! command -v docker > /dev/null; then
      echo "Error: Docker CLI not found in image. Please update the workspace image."
    fi
        
    # Generate locale to fix "cannot change locale" warnings
    # Locale generation is now handled in the Docker image
    # $SUDO locale-gen en_US.UTF-8

    # Set locale env vars
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    if ! grep -q "LC_ALL=en_US.UTF-8" ~/.bashrc; then
      echo "export LANG=en_US.UTF-8" >> ~/.bashrc
      echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
    fi
    
    # FIX: Remove stale GIT_SSH_COMMAND from .bashrc if present (from older versions)
    sed -i '/export GIT_SSH_COMMAND=/d' ~/.bashrc || true

    # Add git branch to bash prompt
    if ! grep -q "git_prompt()" ~/.bashrc; then
      echo '' >> ~/.bashrc
      echo '# Git branch in prompt' >> ~/.bashrc
      echo 'git_prompt() {' >> ~/.bashrc
      echo '    local branch' >> ~/.bashrc
      echo '    branch="$(git symbolic-ref HEAD 2>/dev/null | cut -d/ -f3-)"' >> ~/.bashrc
      echo '    [ -n "$branch" ] && echo " ($branch)"' >> ~/.bashrc
      echo '}' >> ~/.bashrc
      echo 'PS1='\''\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(git_prompt)\$ '\''' >> ~/.bashrc
    fi

    # Node.js, TypeScript, and DDEV are now pre-installed in the Docker image (v3.0.30+)


    # Configure Docker daemon registry mirror.
    # Priority: explicit Terraform variable, then auto-detect on Coder host:5000 if reachable.
# REGISTRY_MIRROR is injected via coder_agent.env
    if [ -z "$REGISTRY_MIRROR" ] && [ -n "$CODER_AGENT_URL" ]; then
      CODER_HOST=$(echo "$CODER_AGENT_URL" | sed -E 's#^https?://([^/:]+).*$#\1#')
      CANDIDATE_MIRROR="http://$CODER_HOST:5000"
      if [ -n "$CODER_HOST" ] && curl -fsS --max-time 2 "$CANDIDATE_MIRROR/v2/" > /dev/null 2>&1; then
        REGISTRY_MIRROR="$CANDIDATE_MIRROR"
        echo "Detected registry mirror on Coder host: $REGISTRY_MIRROR"
      else
        echo "No reachable registry mirror detected on Coder host; continuing without mirror"
      fi
    fi
    if [ -n "$REGISTRY_MIRROR" ]; then
      echo "Configuring Docker registry mirror: $REGISTRY_MIRROR"
      MIRROR_HOST=$(echo "$REGISTRY_MIRROR" | sed 's|https\?://||')
      sudo mkdir -p /etc/docker
      sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": ["$REGISTRY_MIRROR"],
  "insecure-registries": ["$MIRROR_HOST"]
}
EOF
    fi

    # Start Docker Daemon (Sysbox)
    # Since we are not booting with systemd as PID 1, we must start dockerd manually.
    if ! pgrep -x "dockerd" > /dev/null; then
      echo "Starting Docker Daemon..."
      # Use sudo because we are running as coder user
      sudo dockerd > /tmp/dockerd.log 2>&1 &
      
      # Wait for Docker Socket
      echo "Waiting for Docker Socket..."
      for i in $(seq 1 30); do
        if [ -S /var/run/docker.sock ]; then
          echo "Docker Socket found!"
          break
        fi
        sleep 1
      done
      
      # Fix permissions so 'coder' user can access it
      if [ -S /var/run/docker.sock ]; then
        sudo chmod 666 /var/run/docker.sock
      else
        echo "Error: Docker Socket not found after 30s!"
      fi
    else
      echo "Docker Daemon already running."
    fi

    # Create .ddev directory for ddev config (DDEV creates global_config.yaml on first use)
    mkdir -p ~/.ddev

    # Always omit ddev-router — this template uses direct port binding, not the router.
    # Must run every startup because the shared global_config.yaml defaults to omit_containers: []
    echo "Configuring DDEV to omit ddev-router..."
    ddev config global --omit-containers=ddev-router --instrumentation-opt-in=false > /dev/null 2>&1 || true

    # Install mkcert CA to suppress DDEV's "mkcert may not be properly installed" warning
    # DDEV ships its own mkcert binary; this sets up the local CA trust
    mkcert -install 2>/dev/null || true

    # Pre-pull DDEV images (uses registry mirror if configured)
    _t_images=$SECONDS
    echo "Pre-pulling DDEV images..."
    ddev utility download-images || true
    IMAGES_TIME=$((SECONDS - _t_images))
    echo "  ddev utility download-images complete (${IMAGES_TIME}s)"

    # ==========================================
    # DRUPAL CORE AUTOMATIC SETUP
    # ==========================================
    echo ""
    echo "=========================================="
    echo "Drupal Core Automatic Setup"
    echo "=========================================="

    DRUPAL_DIR="/home/coder/drupal-core"
    SETUP_LOG="/tmp/drupal-setup.log"
    SETUP_STATUS="$HOME/SETUP_STATUS.txt"

    # Initialize setup status file
    cat > "$SETUP_STATUS" << 'STATUS_HEADER'
Drupal Core Setup Status
=========================
STATUS_HEADER
    echo "Started: $(date)" >> "$SETUP_STATUS"
    echo "" >> "$SETUP_STATUS"

    # Function to log both to file and stdout
    log_setup() {
      echo "$1" | tee -a "$SETUP_LOG"
    }

    # Function to update status file
    update_status() {
      echo "$1" >> "$SETUP_STATUS"
    }

    # Ensure we're starting from home directory
    cd /home/coder || exit 1

    # Issue fork / install profile parameters (evaluated at template build time)
# ISSUE_FORK is injected via coder_agent.env
    ISSUE_FORK="${ISSUE_FORK#drupal-}"
# ISSUE_BRANCH is injected via coder_agent.env
# INSTALL_PROFILE is injected via coder_agent.env

    # Fetch issue title from drupal.org API (best-effort)
    ISSUE_TITLE=""
    if [ -n "$ISSUE_FORK" ]; then
      ISSUE_TITLE=$(curl -sf "https://www.drupal.org/api-d7/node/${ISSUE_FORK}.json" 2>/dev/null | jq -r '.title // ""' 2>/dev/null || echo "")
    fi

    USING_ISSUE_FORK=false
    SETUP_FAILED=false
    if [ -n "$ISSUE_FORK" ] || [ -n "$ISSUE_BRANCH" ]; then
      USING_ISSUE_FORK=true
      log_setup "Issue fork mode: ISSUE_FORK=$ISSUE_FORK  ISSUE_BRANCH=$ISSUE_BRANCH  INSTALL_PROFILE=$INSTALL_PROFILE"
    fi

    if [ -n "$ISSUE_FORK" ]; then
      log_setup "🔗 Issue: https://www.drupal.org/project/drupal/issues/$ISSUE_FORK"
      if [ -n "$ISSUE_TITLE" ]; then log_setup "   Title: $ISSUE_TITLE"; fi
    fi

    # Drupal version, branch, and DDEV project type — computed early so the git clone
    # section can check out the correct branch before DDEV config runs.
# DRUPAL_VERSION is injected via coder_agent.env
    case "$DRUPAL_VERSION" in
      10) DDEV_PROJECT_TYPE="drupal10"; DRUPAL_BRANCH="10.x" ;;
      11) DDEV_PROJECT_TYPE="drupal11"; DRUPAL_BRANCH="11.x" ;;
      *)  DDEV_PROJECT_TYPE="drupal12"; DRUPAL_BRANCH="main" ;;
    esac

    # Step 1: Clone Drupal core (first run) or verify existing checkout
    CACHE_SEED="/home/coder-cache-seed"
    SETUP_START=$SECONDS
    DRUPAL_SETUP_NEEDED=false

    if [ -d "$DRUPAL_DIR/repos/drupal/.git" ]; then
      # Old joachim-n scaffolding detected — existing workspace, skip clone.
      # Drupal continues to work with the existing setup; recreate the workspace to
      # switch to the new amateescu/ddev-drupal-dev scaffolding.
      log_setup "⚠ Old scaffolding (repos/drupal/) detected — keeping existing setup"
      log_setup "  Recreate this workspace to migrate to the new scaffolding."
      update_status "✓ Setup: Existing old-scaffolding workspace"
    elif [ ! -d "$DRUPAL_DIR/.git" ]; then
      DRUPAL_SETUP_NEEDED=true
      update_status "⏳ Git clone: In progress..."
      _t=$SECONDS
      if [ -d "$CACHE_SEED/.git" ]; then
        log_setup "Cloning Drupal core (with reference from cache seed)..."
        git clone --reference "$CACHE_SEED" https://git.drupalcode.org/project/drupal.git "$DRUPAL_DIR" >> "$SETUP_LOG" 2>&1 || \
          git clone https://git.drupalcode.org/project/drupal.git "$DRUPAL_DIR" >> "$SETUP_LOG" 2>&1
      else
        log_setup "Cloning Drupal core..."
        git clone https://git.drupalcode.org/project/drupal.git "$DRUPAL_DIR" >> "$SETUP_LOG" 2>&1
      fi
      if [ -d "$DRUPAL_DIR/.git" ]; then
        log_setup "✓ Drupal core cloned ($((SECONDS - _t))s)"
        update_status "✓ Git clone: Success"
      else
        log_setup "✗ Failed to clone Drupal core"
        update_status "✗ Git clone: Failed"
        SETUP_FAILED=true
      fi

      # Branch or fork checkout
      if [ "$SETUP_FAILED" != "true" ] && [ "$USING_ISSUE_FORK" = "true" ] && [ -n "$ISSUE_FORK" ]; then
        log_setup "Adding issue fork remote and fetching: $ISSUE_FORK"
        git -C "$DRUPAL_DIR" remote add issue "https://git.drupalcode.org/issue/drupal-${ISSUE_FORK}.git"
        if git -C "$DRUPAL_DIR" fetch issue >> "$SETUP_LOG" 2>&1; then
          log_setup "  ✓ Fetched from issue remote"
          if [ -n "$ISSUE_BRANCH" ]; then
            if git -C "$DRUPAL_DIR" checkout -b "$ISSUE_BRANCH" "issue/$ISSUE_BRANCH" >> "$SETUP_LOG" 2>&1 || \
               git -C "$DRUPAL_DIR" checkout "$ISSUE_BRANCH" >> "$SETUP_LOG" 2>&1; then
              log_setup "  ✓ Checked out branch: $ISSUE_BRANCH"
            else
              log_setup "✗ Failed to check out branch $ISSUE_BRANCH"
              SETUP_FAILED=true
            fi
          fi
        else
          log_setup "✗ Failed to fetch from issue remote $ISSUE_FORK"
          SETUP_FAILED=true
        fi
      elif [ "$SETUP_FAILED" != "true" ] && [ "$DRUPAL_BRANCH" != "main" ]; then
        if [ "$DRUPAL_BRANCH" = "10.x" ]; then
          _r=$(git -C "$DRUPAL_DIR" branch -r 2>/dev/null | grep -oE "10\.[0-9]+\.x" | sort -V | tail -1 || echo "")
          [ -n "$_r" ] && { DRUPAL_BRANCH="$_r"; log_setup "  Resolved Drupal 10 branch → $DRUPAL_BRANCH"; }
        fi
        if git -C "$DRUPAL_DIR" checkout "$DRUPAL_BRANCH" >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Checked out branch: $DRUPAL_BRANCH"
        else
          log_setup "✗ Failed to check out $DRUPAL_BRANCH"
          SETUP_FAILED=true
        fi
      fi
    else
      log_setup "✓ Drupal core already cloned — skipping git clone"
      update_status "✓ Setup: Already present"
      if [ "$USING_ISSUE_FORK" = "false" ]; then
        _t=$SECONDS
        if [ "$DRUPAL_BRANCH" = "10.x" ]; then
          _r=$(git -C "$DRUPAL_DIR" branch -r 2>/dev/null | grep -oE "10\.[0-9]+\.x" | sort -V | tail -1 || echo "")
          [ -n "$_r" ] && DRUPAL_BRANCH="$_r"
        fi
        git -C "$DRUPAL_DIR" fetch --all --prune >> "$SETUP_LOG" 2>&1 || true
        git -C "$DRUPAL_DIR" merge --ff-only "origin/$DRUPAL_BRANCH" >> "$SETUP_LOG" 2>&1 || true
        log_setup "  git fetch+merge $DRUPAL_BRANCH complete ($((SECONDS - _t))s)"
      fi
    fi

    cd "$DRUPAL_DIR" || exit 1

    # Step 2: Configure DDEV (must be done before composer create)
    # Always regenerate .ddev/config.yaml from scratch so DDEV picks its own defaults
    # for the project type (e.g. correct PHP version). Preserving an old config.yaml
    # would leave stale fields like php_version untouched even when project-type changes.
    rm -f .ddev/config.yaml
    log_setup "Configuring DDEV for Drupal $DRUPAL_VERSION ($DDEV_PROJECT_TYPE)..."
    update_status "⏳ DDEV config: In progress..."

    # Detect docroot: old joachim-n scaffolding uses web/ symlink; direct git clone has index.php at root.
    DDEV_DOCROOT_ARG=""
    if [ -d "repos/drupal/.git" ] || [ -L "web" ]; then
      DDEV_DOCROOT_ARG="--docroot=web"
      log_setup "  Detected old scaffolding — using --docroot=web"
    fi

    # Compute Coder domain for use in DDEV configuration
    CODER_DOMAIN=""
    if [ -n "$CODER_WORKSPACE_OWNER_NAME" ] && ([ -n "$VSCODE_PROXY_URI" ] || [ -n "$CODER_AGENT_URL" ]); then
      if [ -n "$VSCODE_PROXY_URI" ]; then
        CODER_DOMAIN=$(echo "$VSCODE_PROXY_URI" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
      else
        CODER_DOMAIN=$(echo "$CODER_AGENT_URL" | sed -E 's|https?://(.+?)(/.*)?$|\1|')
      fi
      export CODER_DOMAIN
    fi

    mkdir -p .ddev
    cat > .ddev/config.coder.yaml << CODER_YAML_EOF
# Auto-generated by workspace startup -- do not edit.
# Sets project_tld so 'ddev describe' shows the Coder domain rather than ddev.site.
#ddev-silent-no-warn
#name: "${CODER_WORKSPACE_NAME}--${CODER_WORKSPACE_OWNER_NAME}"
project_tld: "$CODER_DOMAIN"
use_dns_when_possible: false
host_webserver_port: "80"
# Bind mailpit directly to workspace localhost (ddev-router is omitted in this template).
# Without this, mailpit is only reachable inside the DDEV web container.
host_mailpit_port: "8025"
# Show Coder URLs after every ddev start/restart (appended after DDEV's own message).
hooks:
  post-start:
    - exec-host: 'echo "" && echo "  Site:    https://drupal-site--${CODER_WORKSPACE_NAME}--${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN" && echo "  Mailpit: https://mailpit--${CODER_WORKSPACE_NAME}--${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN" && echo ""'
CODER_YAML_EOF
    log_setup "✓ .ddev/config.coder.yaml written"

    if ddev config --project-type="$DDEV_PROJECT_TYPE" $DDEV_DOCROOT_ARG --project-name="${CODER_WORKSPACE_NAME}--${CODER_WORKSPACE_OWNER_NAME}" >> "$SETUP_LOG" 2>&1; then
      log_setup "✓ DDEV configured (project-type=$DDEV_PROJECT_TYPE)"
      update_status "✓ DDEV config: Success"
    else
      log_setup "✗ Failed to configure DDEV"
      log_setup "Check $SETUP_LOG for details"
      update_status "✗ DDEV config: Failed"
      update_status ""
      update_status "Manual recovery:"
      update_status "  cd $DRUPAL_DIR"
      update_status "  ddev config --project-type=$DDEV_PROJECT_TYPE $DDEV_DOCROOT_ARG"
    fi

    # Configure DDEV global settings (omit router)
    log_setup "Configuring DDEV global settings..."
    update_status "⏳ DDEV global config: In progress..."

    if ddev config global --omit-containers=ddev-router >> "$SETUP_LOG" 2>&1; then
      log_setup "✓ DDEV global config applied (router omitted)"
      update_status "✓ DDEV global config: Success"
    else
      log_setup "⚠ Warning: Failed to set DDEV global config (non-critical)"
      update_status "⚠ DDEV global config: Warning (non-critical)"
    fi

    # Write Coder-specific DDEV config so 'ddev describe' shows usable URLs.
    # Runs every workspace start so the config stays current.
    # project_tld is set to the Coder subdomain suffix so DDEV's primary URL
    # resolves to <project-name>.<workspace>--<owner>.<coder-domain> rather
    # than the default <project-name>.ddev.site.
    # CODER_DOMAIN was already computed earlier in the script
    if [ -n "$CODER_DOMAIN" ]; then
      # Generate docker-compose override that adds Coder URLs and credentials to
      # 'ddev describe' output via x-ddev labels on the web service.
      cat > .ddev/docker-compose.coder-describe.yaml << COMPOSE_EOF
#ddev-silent-no-warn
# Auto-generated by workspace startup -- do not edit.
services:
  web:
    x-ddev:
      describe-url-port: |
        https://drupal-site--${CODER_WORKSPACE_NAME}--${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN
        Mailpit: https://mailpit--${CODER_WORKSPACE_NAME}--${CODER_WORKSPACE_OWNER_NAME}.$CODER_DOMAIN
      describe-info: "Admin: admin / admin"
COMPOSE_EOF
      log_setup "✓ .ddev/docker-compose.coder-describe.yaml written (x-ddev describe labels)"
    fi

    # Step 3: Start DDEV
    # poweroff first — ddev-router can persist in Docker's state across workspace
    # stop/start; `ddev stop` only stops project containers, not ddev-router.
    ddev poweroff 2>&1 | tee -a "$SETUP_LOG" || true

    log_setup "Starting DDEV environment..."
    update_status "⏳ DDEV start: In progress..."

    ddev start 2>&1 | tee -a "$SETUP_LOG"
    DDEV_START_RC=${PIPESTATUS[0]}
    if [ $DDEV_START_RC -eq 0 ]; then
      log_setup "✓ DDEV started successfully"
      update_status "✓ DDEV start: Success"
    else
      log_setup "✗ Failed to start DDEV"
      log_setup "Check $SETUP_LOG and Docker logs for details"
      update_status "✗ DDEV start: Failed"
      update_status ""
      update_status "Manual recovery:"
      update_status "  cd $DRUPAL_DIR && ddev start"
      update_status "  Check: docker ps, docker logs"
    fi

    # Create Drupal-specific welcome message (ISSUE_FORK and ISSUE_TITLE already set above)
    {
      cat << 'WELCOME_STATIC'
Drupal Core Development Workspace
==================================
Admin: admin / admin

Commands:
  ddev launch               # Show site URL and one-time login link
  ddev describe             # Show project details and URLs
  ddev drush status         # Check Drupal status
  ddev logs                 # View container logs
  ddev ssh                  # SSH into web container

  ddev add-module <name>    # Clone a contrib module for development
  ddev phpunit [--db=sqlite|mysql|pgsql] <path>  # Run PHPUnit tests

Add-on docs: https://github.com/amateescu/ddev-drupal-dev
DDEV docs:   https://docs.ddev.com/
WELCOME_STATIC

      if [ -n "$ISSUE_FORK" ]; then
        echo ""
        echo "Issue #${ISSUE_FORK}: ${ISSUE_TITLE}"
        echo "  https://www.drupal.org/project/drupal/issues/${ISSUE_FORK}"
      fi
    } > ~/WELCOME.txt
    chown coder:coder ~/WELCOME.txt 2>/dev/null || true

    # Step 4: Install ddev-drupal-dev add-on, composer install, and drush (first run only)
    if [ "$DRUPAL_SETUP_NEEDED" = "true" ] && [ "$SETUP_FAILED" != "true" ]; then
      log_setup "Installing amateescu/ddev-drupal-dev add-on..."
      update_status "⏳ DDEV add-on install: In progress..."
      _t=$SECONDS
      if ddev add-on get amateescu/ddev-drupal-dev >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ Add-on installed ($((SECONDS - _t))s)"
        update_status "✓ DDEV add-on install: Success"
      else
        log_setup "✗ Failed to install add-on ($((SECONDS - _t))s)"
        update_status "✗ DDEV add-on install: Failed"
        SETUP_FAILED=true
      fi

      if [ "$SETUP_FAILED" != "true" ]; then
        log_setup "Restarting DDEV to activate add-on..."
        ddev restart >> "$SETUP_LOG" 2>&1 || true

        log_setup "Running composer install..."
        update_status "⏳ Composer install: In progress..."
        _t=$SECONDS
        ddev composer install 2>&1 | tee -a "$SETUP_LOG"
        _composer_exit=${PIPESTATUS[0]}
        if [ "$_composer_exit" = "0" ]; then
          log_setup "✓ Composer install complete ($((SECONDS - _t))s)"
          update_status "✓ Composer install: Success"
        else
          log_setup "✗ Composer install failed (exit $_composer_exit, $((SECONDS - _t))s)"
          update_status "✗ Composer install: Failed"
          SETUP_FAILED=true
        fi
      fi

      if [ "$SETUP_FAILED" != "true" ]; then
        log_setup "Adding Drush to composer.local.json..."
        update_status "⏳ Drush install: In progress..."
        if ddev composer require drush/drush >> "$SETUP_LOG" 2>&1; then
          log_setup "✓ Drush installed"
          update_status "✓ Drush install: Success"
        else
          log_setup "⚠ Warning: Failed to install Drush (non-critical)"
          update_status "⚠ Drush install: Warning"
        fi
      fi
    fi

    # Steps 5-6: Drupal install — skipped if an earlier step failed
    if [ "$SETUP_FAILED" = "true" ]; then
      log_setup "⚠ Skipping Drupal install due to earlier failure"
      update_status "⚠ Setup incomplete — see drupal-setup.log for details"
    else

    # Compute site name for drush si
    if [ -n "$ISSUE_FORK" ] && [ -n "$ISSUE_TITLE" ]; then
      SITE_NAME="#${ISSUE_FORK}: ${ISSUE_TITLE}"
    elif [ -n "$ISSUE_FORK" ]; then
      SITE_NAME="Issue #${ISSUE_FORK}"
    else
      SITE_NAME="Drupal Core Development"
    fi

    if ddev drush status 2>/dev/null | grep -q "Drupal bootstrap.*Successful"; then
      log_setup "✓ Drupal already installed"
      update_status "✓ Drupal install: Already present"
    else
      _t=$SECONDS
      if [ "$USING_ISSUE_FORK" = "true" ]; then
        log_setup "Installing Drupal with $INSTALL_PROFILE profile (issue fork)..."
      else
        log_setup "Installing Drupal with $INSTALL_PROFILE profile..."
      fi
      update_status "⏳ Drupal install: In progress..."

      if ddev drush si -y "$INSTALL_PROFILE" --account-pass=admin --site-name="$SITE_NAME" >> "$SETUP_LOG" 2>&1; then
        log_setup "✓ Drupal installed"
        log_setup ""
        log_setup "   Admin Credentials:"
        log_setup "      Username: admin"
        log_setup "      Password: admin"
        log_setup ""
        update_status "✓ Drupal install: Success"
      else
        log_setup "✗ Failed to install Drupal"
        log_setup "Check $SETUP_LOG for details"
        update_status "✗ Drupal install: Failed"
        update_status ""
        update_status "Manual recovery:"
        update_status "  cd $DRUPAL_DIR"
        update_status "  ddev drush si -y $INSTALL_PROFILE --account-pass=admin"
      fi
    fi
    fi # end SETUP_FAILED guard

    # Step 6.5: Cache rebuild — ensures a clean state after any setup path
    log_setup "Running cache rebuild..."
    ddev drush cr >> "$SETUP_LOG" 2>&1 || true

    # Step 6.6: Set up phpunit.xml for running core tests
    if [ ! -f "phpunit.xml" ] && [ -f "phpunit-ddev.xml" ]; then
      cp phpunit-ddev.xml phpunit.xml
      # Replace PROJECT_NAME.ddev.site placeholder with actual workspace URL
      if [ -n "$CODER_WORKSPACE_OWNER_NAME" ] && ([ -n "$VSCODE_PROXY_URI" ] || [ -n "$CODER_AGENT_URL" ]); then
        if [ -n "$VSCODE_PROXY_URI" ]; then
          CODER_DOMAIN=$(echo "$VSCODE_PROXY_URI" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
        else
          CODER_DOMAIN=$(echo "$CODER_AGENT_URL" | sed -E 's|https?://(.+?)(/.*)?$|\1|')
        fi
        SITE_URL="https://80--${CODER_WORKSPACE_NAME}--${CODER_WORKSPACE_OWNER_NAME}.${CODER_DOMAIN}"
        sed -i "s|PROJECT_NAME\.ddev\.site|${SITE_URL#https://}|" phpunit.xml
      fi
      log_setup "✓ phpunit.xml configured (run tests with: ddev exec vendor/bin/phpunit core/tests/...)"
    fi

    # Step 7: Install custom DDEV launch command
    mkdir -p ~/.ddev/commands/host
    cat > ~/.ddev/commands/host/launch << 'LAUNCH_EOF'
#!/usr/bin/env bash

## Description: Show Coder URLs for this Drupal workspace
## Usage: launch [path] [-m|--mailpit]
## Example: "ddev launch" or "ddev launch /admin" or "ddev launch -m"
## Flags: [{"Name":"mailpit","Shorthand":"m","Usage":"ddev launch -m shows the Mailpit URL"}]

# Outside a Coder workspace fall back to a basic URL print (no browser available in DinD)
if [ -z "${CODER_WORKSPACE_NAME:-}" ] || ([ -z "${VSCODE_PROXY_URI:-}" ] && [ -z "${CODER_AGENT_URL:-}" ]); then
  echo "Primary URL: ${DDEV_PRIMARY_URL:-unknown}"
  echo "(Not running in a Coder workspace; cannot open a browser.)"
  exit 0
fi

WORKSPACE="${CODER_WORKSPACE_NAME}"
OWNER="${CODER_WORKSPACE_OWNER_NAME}"
if [ -n "${VSCODE_PROXY_URI:-}" ]; then
  DOMAIN=$(echo "${VSCODE_PROXY_URI}" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')
else
  DOMAIN=$(echo "${CODER_AGENT_URL}" | sed -E 's|https?://(.+?)(/.*)?$|\1|')
fi
MAILPIT=false
PATH_SUFFIX=""

while :; do
  case ${1:-} in
  -m | --mailpit | --mailhog) MAILPIT=true ;;
  --) shift; break ;;
  -?*) printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2 ;;
  *) break ;;
  esac
  shift
done

if [ -n "${1:-}" ]; then
  PATH_SUFFIX="/${1#/}"
fi

if [ "${MAILPIT}" = "true" ]; then
  echo "https://mailpit--${WORKSPACE}--${OWNER}.${DOMAIN}"
  exit 0
fi

SITE_URL="https://drupal-site--${WORKSPACE}--${OWNER}.${DOMAIN}"

echo ""
echo "Coder URLs for this Drupal workspace:"
echo "  Site:    ${SITE_URL}${PATH_SUFFIX}"
echo "  Mailpit: https://mailpit--${WORKSPACE}--${OWNER}.${DOMAIN}"
echo ""
echo "Admin login: admin / admin"
ULI=$(ddev drush uli --uri="${SITE_URL}" 2>/dev/null || true)
if [ -n "${ULI}" ]; then
  echo "One-time login: ${ULI}"
else
  echo "One-time login: ddev drush uli  (run when Drupal is installed)"
fi
echo ""
echo "Useful commands (from ddev-drupal-dev add-on):"
echo "  ddev add-module <name>    # Clone a contrib module for development"
echo "  ddev phpunit [--db=sqlite|mysql|pgsql] <path>  # Run PHPUnit tests"
echo "  ddev remove-module <name> # Remove a contrib module"
echo "  See: https://github.com/amateescu/ddev-drupal-dev"
echo ""
LAUNCH_EOF

    chmod +x ~/.ddev/commands/host/launch
    log_setup "✓ Custom DDEV launch command installed"
    update_status "✓ DDEV launch command: Installed"

    # Timing summary
    TOTAL_TIME=$((SECONDS - SCRIPT_START))
    INSTALL_TIME=$((SECONDS - SETUP_START))

    # Collect failure lines for summary (✗-prefixed lines from the setup log)
    FAILURE_SUMMARY=$(grep "✗" "$SETUP_LOG" 2>/dev/null | grep -v "^$" | head -20 || true)

    # Final status and summary
    update_status ""
    update_status "Completed: $(date)"
    update_status ""
    update_status "--- Timing ---"
    update_status "  ddev utility download-images: ${IMAGES_TIME}s"
    update_status "  Install/seed phase:           ${INSTALL_TIME}s"
    update_status "  Total workspace startup:      ${TOTAL_TIME}s"
    update_status ""
    if [ "$SETUP_FAILED" = "true" ]; then
      update_status "=========================================="
      update_status "✗ SETUP FAILED — workspace needs attention"
      update_status "=========================================="
      update_status ""
      update_status "Errors:"
      echo "$FAILURE_SUMMARY" | while IFS= read -r _line; do update_status "  $_line"; done
      update_status ""
      update_status "SSH in and run: cat $SETUP_LOG"
    fi
    update_status ""
    update_status "View full logs: $SETUP_LOG"

    log_setup ""
    log_setup "=========================================="
    if [ "$SETUP_FAILED" = "true" ]; then
      log_setup "✗ SETUP FAILED — see errors below"
    else
      log_setup "✨ Setup Complete!"
    fi
    log_setup "=========================================="
    log_setup ""
    if [ "$SETUP_FAILED" = "true" ]; then
      log_setup "Errors encountered:"
      echo "$FAILURE_SUMMARY" | while IFS= read -r _line; do log_setup "  $_line"; done
      log_setup ""
      log_setup "Full log: cat $SETUP_LOG"
      log_setup "Status:   cat $SETUP_STATUS"
    else
      log_setup "⏱  Timing Summary:"
      log_setup "   ddev utility download-images: ${IMAGES_TIME}s"
      log_setup "   Install/seed phase:           ${INSTALL_TIME}s"
      log_setup "   Total workspace startup:      ${TOTAL_TIME}s"
      log_setup ""
      log_setup "📁 Project Location:"
      log_setup "   $DRUPAL_DIR"
      log_setup ""
      log_setup "🌐 Access Your Site:"
      log_setup "   - Click 'DDEV Web' in Coder dashboard"
      log_setup "   - Or run: ddev launch"
      log_setup ""
      log_setup "🔐 Admin Credentials:"
      log_setup "   Username: admin"
      log_setup "   Password: admin"
      log_setup ""
      log_setup "🛠️  Useful Commands:"
      log_setup "   ddev drush uli          # One-time login link"
      log_setup "   ddev drush status       # Check Drupal status"
      log_setup "   ddev logs               # View logs"
      log_setup "   ddev ssh                # SSH into container"
      log_setup ""
      log_setup "📋 Setup Details:"
      log_setup "   Status: $SETUP_STATUS"
      log_setup "   Logs:   $SETUP_LOG"
    fi
    log_setup ""

    # Create projects directory for additional projects if needed
    mkdir -p ~/projects
    
    
    # Display welcome message
    cat ~/WELCOME.txt
    echo ""
    echo "Welcome message saved to ~/WELCOME.txt"

    # Set workspace ID as environment variable (extracted from container name or Coder env)
    # Container name format: coder-{workspace-id}
    if [ -z "$CODER_WORKSPACE_ID" ]; then
      # Try to extract from container hostname or environment
      CODER_WORKSPACE_ID=$(hostname | sed 's/coder-//' || echo "")
    fi
    if [ -z "$CODER_WORKSPACE_ID" ]; then
      # Fallback: use first 8 characters of hostname or generate from hostname
      CODER_WORKSPACE_ID=$(hostname | cut -c1-8 || echo "workspace")
    fi
    export CODER_WORKSPACE_ID
    
    # Set workspace name as environment variable (for unique ddev project names)
    # Extract from hostname (format: coder-{workspace-id}) or use workspace ID
    # Workspace name is typically the last part before the workspace ID
    if [ -z "$CODER_WORKSPACE_NAME" ]; then
      # Try to get from hostname pattern: coder-{workspace-name}-{id}
      # Or use a sanitized version of workspace ID
      HOSTNAME_PART=$(hostname | sed 's/coder-//' | cut -d'-' -f1)
      if [ -n "$HOSTNAME_PART" ] && [ "$HOSTNAME_PART" != "$CODER_WORKSPACE_ID" ]; then
        CODER_WORKSPACE_NAME="$HOSTNAME_PART"
      else
        # Fallback: use first part of workspace ID or "main"
        CODER_WORKSPACE_NAME=$(echo "$CODER_WORKSPACE_ID" | cut -d'-' -f1 | head -c 10 || echo "main")
      fi
    fi
    export CODER_WORKSPACE_NAME

    # Ensure linuxbrew/homebrew is in PATH
    if ! echo "$PATH" | grep -q "/home/linuxbrew/.linuxbrew/bin"; then
      echo 'export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin"' >> ~/.bashrc
    fi
    
    # Remove any old welcome message entries from .bashrc (if they exist)
    # We use .bash_profile instead to avoid duplicates
    if [ -f ~/.bashrc ]; then
      sed -i '/WELCOME.txt/,/^fi$/d' ~/.bashrc 2>/dev/null || true
    fi
    
    # Add welcome message to .bash_profile for SSH login
    # .bash_profile is executed only for login shells (SSH sessions)
    if [ ! -f ~/.bash_profile ]; then
      # Create .bash_profile and source .bashrc for non-login shells
      cat > ~/.bash_profile << 'BASHPROFILE'
# Source system-wide settings (bash_completion etc.) for login shells
if [ -f /etc/bash.bashrc ]; then
  . /etc/bash.bashrc
fi

# Source user .bashrc
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi

# Display welcome message on SSH login (login shells only)
if [ -f ~/WELCOME.txt ]; then
  cat ~/WELCOME.txt
  echo ""
fi
BASHPROFILE
      chmod 644 ~/.bash_profile
    elif ! grep -q "WELCOME.txt" ~/.bash_profile 2>/dev/null; then
      # Add welcome message to existing .bash_profile
      cat >> ~/.bash_profile << 'BASHPROFILE_WELCOME'
# Display welcome message on SSH login (login shells only)
if [ -f ~/WELCOME.txt ]; then
  cat ~/WELCOME.txt
  echo ""
fi
BASHPROFILE_WELCOME
    fi
    # Ensure /etc/bash.bashrc is sourced for bash_completion in login shells
    if ! grep -q 'etc/bash.bashrc' ~/.bash_profile 2>/dev/null; then
      printf '\n# Source system-wide settings (bash_completion etc.) for login shells\nif [ -f /etc/bash.bashrc ]; then\n  . /etc/bash.bashrc\nfi\n' >> ~/.bash_profile
    fi

    # Ensure bash_completion is loaded for non-login interactive shells (e.g. VS Code terminal)
    # Login shells get it via /etc/profile.d/bash_completion.sh; non-login shells need it in ~/.bashrc
    if ! grep -q 'bash_completion' ~/.bashrc 2>/dev/null; then
      cat >> ~/.bashrc << 'BASHCOMP'
# Bash completion (for non-login interactive shells)
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
BASHCOMP
    fi

    # Set up npm global directory in home to persist packages
    mkdir -p ~/.npm-global
    npm config set prefix "~/.npm-global"
    # Always export PATH for current session (required for non-interactive shells)
    export PATH="$HOME/.npm-global/bin:$PATH"
    if ! echo "$PATH" | grep -q "$HOME/.npm-global/bin"; then
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
      echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bash_profile
    fi

    # Create symlink for task-master-ai in /usr/local/bin for system-wide access (if not already present)
    if command -v sudo > /dev/null 2>&1 && sudo -n true 2>/dev/null; then
      if [ -f ~/.npm-global/bin/task-master-ai ] && [ ! -f /usr/local/bin/task-master-ai ]; then
        sudo ln -sf ~/.npm-global/bin/task-master-ai /usr/local/bin/task-master-ai 2>/dev/null || true
      fi
    fi
    


  
    
    
    if [ "$SETUP_FAILED" = "true" ]; then
      # Overwrite WELCOME.txt so SSH login immediately shows the failure
      {
        echo "⚠  WORKSPACE SETUP INCOMPLETE"
        echo "================================"
        echo ""
        echo "Setup encountered errors. Run this for details:"
        echo "  cat $SETUP_LOG"
        echo ""
        echo "Errors:"
        echo "$FAILURE_SUMMARY" | sed 's/^/  /'
        echo ""
        echo "Status file: cat $SETUP_STATUS"
      } > ~/WELCOME.txt

      echo ""
      echo "=========================================="
      echo "✗ SETUP FAILED"
      echo "=========================================="
      echo ""
      echo "Errors:"
      echo "$FAILURE_SUMMARY" | sed 's/^/  /'
      echo ""
      echo "Full log: cat $SETUP_LOG"
      echo ""
    else
      echo "=== Setup Complete ==="
      echo ""
      echo "⏱  Timing: images=${IMAGES_TIME}s  install=${INSTALL_TIME}s  total=${TOTAL_TIME}s"
      echo ""
      echo "📁 Drupal core ready at ~/drupal-core"
      echo "📄 Welcome message saved to ~/WELCOME.txt"
      echo ""
      echo "Next steps:"
      echo "  1. Click 'DDEV Web' app to access your site"
      echo "  2. Log in with admin/admin"
      echo "  3. Run 'ddev drush uli' for one-time login link"
      echo ""
    fi

    # Explicitly exit with success to prevent "Unhealthy" status
    exit 0
