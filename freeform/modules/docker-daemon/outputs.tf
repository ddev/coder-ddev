output "startup_script" {
  description = "Bash snippet for the caller to append to its coder_agent startup_script, after locale/bashrc setup and before any command that needs Docker (ddev config global, image pre-pull, etc)."
  value       = <<-EOT

    # Configure Docker daemon registry mirror.
    # Priority: explicit Terraform variable, then auto-detect on Coder host:5000 if reachable.
    REGISTRY_MIRROR="${var.docker_registry_mirror}"
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

    # Start Docker Daemon (Sysbox). dockerd runs as a bare background
    # process here (no init system inside the container manages it), so
    # when something outside Coder restarts this same container in place
    # -- e.g. the host's docker-ce package being upgraded, which restarts
    # docker.service and, via `restart = unless-stopped`, restarts every
    # workspace container -- dockerd is killed without a chance to clean
    # up (see modules/docker-daemon for the matching graceful-shutdown
    # half of this). That leaves a stale /var/run/docker.pid (and socket
    # file) in the container's writable layer, which makes the next
    # dockerd refuse to start ("process with PID ... is still running")
    # even though nothing is actually running. Clear that leftover state
    # before starting, and confirm the daemon actually answers rather than
    # trusting the socket file alone.
    wait_for_dockerd() {
      for i in $(seq 1 30); do
        sudo docker info > /dev/null 2>&1 && return 0
        sleep 1
      done
      return 1
    }

    if sudo docker info > /dev/null 2>&1; then
      echo "Docker Daemon already running."
    else
      sudo pkill -x dockerd 2>/dev/null || true
      sudo rm -f /var/run/docker.pid /var/run/docker.sock

      echo "Starting Docker Daemon..."
      sudo dockerd > /tmp/dockerd.log 2>&1 &
      if wait_for_dockerd; then
        echo "Docker Daemon ready"
      else
        echo "Docker Daemon not responding after 30s; retrying after cleanup"
        sudo pkill -x dockerd 2>/dev/null || true
        sleep 2
        sudo rm -f /var/run/docker.pid /var/run/docker.sock
        sudo dockerd > /tmp/dockerd.log 2>&1 &
        if wait_for_dockerd; then
          echo "Docker Daemon ready after retry"
        else
          echo "Error: Docker Daemon failed to start after cleanup + retry; see /tmp/dockerd.log"
          tail -n 40 /tmp/dockerd.log || true
        fi
      fi
    fi

    if [ -S /var/run/docker.sock ]; then
      sudo chmod 666 /var/run/docker.sock
    fi
  EOT
}
