# Stops the nested Docker daemon (Sysbox) cleanly on workspace stop. It runs
# as a bare background process in the caller's startup script (see
# outputs.tf) -- no init system inside the container manages it -- so
# nothing else sends it a graceful shutdown before the container itself is
# torn down. That matters beyond a normal workspace stop: when something
# outside Coder restarts the container in place (e.g. the host's docker-ce
# package being upgraded, which restarts docker.service and, via `restart =
# unless-stopped`, restarts every workspace container), an unclean kill here
# leaves a stale /var/run/docker.pid behind that blocks the next dockerd
# from starting until the workspace is rebuilt.
resource "coder_script" "ddev_shutdown" {
  agent_id     = var.agent_id
  display_name = "Stop DDEV Projects"
  icon         = "/icon/docker.svg"
  run_on_stop  = true
  script       = <<-EOT
    #!/bin/bash
    export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin"
    # Wait for Docker socket — it should already be up, but guard against
    # race conditions during workspace stop/update.
    for i in $(seq 1 10); do
      [ -S /var/run/docker.sock ] && break
      sleep 1
    done
    if [ -S /var/run/docker.sock ]; then
      echo "Running ddev poweroff..."
      ddev poweroff || true
      echo "ddev poweroff complete"
    else
      echo "Docker socket not available; skipping ddev poweroff"
    fi

    DOCKERD_PID=$(pgrep -x dockerd || true)
    if [ -n "$DOCKERD_PID" ]; then
      echo "Stopping Docker daemon (pid $DOCKERD_PID)..."
      sudo kill -TERM "$DOCKERD_PID" 2>/dev/null || true
      for i in $(seq 1 30); do
        kill -0 "$DOCKERD_PID" 2>/dev/null || break
        sleep 1
      done
      if kill -0 "$DOCKERD_PID" 2>/dev/null; then
        echo "Docker daemon did not stop in time; forcing"
        sudo kill -KILL "$DOCKERD_PID" 2>/dev/null || true
      else
        echo "Docker daemon stopped cleanly"
      fi
    fi
  EOT
}
