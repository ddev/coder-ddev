output "enabled" {
  description = "Whether the Claude Code self-hosted runner is enabled"
  value       = local.enabled
}

output "startup_script" {
  description = "Bash snippet for the caller to append to its coder_agent startup_script, after the claude-remote-control snippet and before the ~/.coder-startup.sh user hook."
  value       = <<-EOT

    # Claude Code self-hosted runner, in tmux session "claude-runner".
    CLAUDE_RUNNER_ENABLED="${local.enabled}"
    CLAUDE_REMOTE_CONTROL_ENABLED="${var.remote_control_enabled}"
    # ~/WELCOME.txt persists across restarts in freeform, so drop the status
    # line an earlier start left there; only the current one is shown below.
    if [ -f ~/WELCOME.txt ]; then
      sed -i '/Claude Code self-hosted runner/d' ~/WELCOME.txt
    fi
    if [ "$CLAUDE_RUNNER_ENABLED" = "true" ]; then
      # Created before the checks below, so the secret has an obvious home.
      mkdir -p ~/.claude-runner
      chmod 700 ~/.claude-runner
      echo '${base64encode(file("${path.module}/files/README.md"))}' | base64 -d > ~/.claude-runner/README.md
      # Read-only gh with the owner's Coder GitHub login, for repositories
      # outside the session's own; /etc/claude-code/CLAUDE.md tells sessions
      # about it. Neither needs the environment secret.
      mkdir -p ~/.local/bin
      echo '${base64encode(file("${path.module}/files/gh-read"))}' | base64 -d > ~/.local/bin/gh-read
      chmod +x ~/.local/bin/gh-read
      sudo mkdir -p /etc/claude-code
      echo '${base64encode(file("${path.module}/files/managed-CLAUDE.md"))}' | base64 -d | sudo tee /etc/claude-code/CLAUDE.md >/dev/null
      if [ "$CLAUDE_REMOTE_CONTROL_ENABLED" = "true" ]; then
        CLAUDE_RUNNER_MSG="✗ Claude Code self-hosted runner NOT started: Claude Code remote control is also enabled, and the runner rewrites ~/.gitconfig before every session. Turn one of them off."
      elif [ ! -s "${local.secret_file}" ]; then
        CLAUDE_RUNNER_MSG="✗ Claude Code self-hosted runner NOT started: save your environment secret as ${local.secret_file} (chmod 600), then restart the workspace. See ~/.claude-runner/README.md."
      else
        # /etc is not persistent, so reinstall the session git config on every start.
        echo '${base64encode(file("${path.module}/files/gitconfig"))}' | base64 -d | sudo tee /etc/gitconfig >/dev/null
        echo '${base64encode(file("${path.module}/files/gitignore"))}' | base64 -d | sudo tee /etc/gitignore-claude-runner >/dev/null
        # The runner copies ~/.claude into each session when it starts.
        mkdir -p ~/.claude/skills/coder-shared-workspace ~/.cache "${var.base_dir}"
        echo '${base64encode(file("${path.module}/files/SKILL.md"))}' | base64 -d > ~/.claude/skills/coder-shared-workspace/SKILL.md
        # Without github.com in known_hosts, SSH pushes from sessions fail with
        # "Host key verification failed". These are GitHub's published keys.
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        if ! ssh-keygen -F github.com >/dev/null 2>&1; then
          echo '${base64encode(file("${path.module}/files/github_known_hosts"))}' | base64 -d >> ~/.ssh/known_hosts
        fi
        mkdir -p ~/.local/bin
        echo '${base64encode(local.loop_script)}' | base64 -d > ~/.local/bin/claude-runner-loop
        chmod +x ~/.local/bin/claude-runner-loop
        echo '${base64encode(file("${path.module}/files/claude-sessions"))}' | base64 -d > ~/.local/bin/claude-sessions
        chmod +x ~/.local/bin/claude-sessions
        echo '${base64encode(file("${path.module}/files/claude-checkout-check"))}' | base64 -d > ~/.local/bin/claude-checkout-check
        chmod +x ~/.local/bin/claude-checkout-check
        echo '${base64encode(file("${path.module}/files/claude-runner-sweep"))}' | base64 -d > ~/.local/bin/claude-runner-sweep
        chmod +x ~/.local/bin/claude-runner-sweep
        echo '${base64encode(file("${path.module}/files/claude-session-identity"))}' | base64 -d > ~/.local/bin/claude-session-identity
        chmod +x ~/.local/bin/claude-session-identity
        sudo mkdir -p /etc/claude-code/managed-settings.d
        echo '${base64encode(local.managed_settings)}' | base64 -d | sudo tee /etc/claude-code/managed-settings.d/coder-runner.json >/dev/null
        mkcert -install >/dev/null 2>&1 || true
        # Anchored on the program name: this script's own bash command line contains the phrase.
        if pgrep -f '^[^ ]*claude self-hosted-runner' >/dev/null || tmux has-session -t claude-runner 2>/dev/null; then
          CLAUDE_RUNNER_MSG="✓ Claude Code self-hosted runners already running (tmux attach -t claude-runner)"
        else
          tmux new-session -d -s claude-runner -n runner-1 "$HOME/.local/bin/claude-runner-loop 1"
          for i in $(seq 2 ${local.capacity}); do
            tmux new-window -t claude-runner -n "runner-$i" "$HOME/.local/bin/claude-runner-loop $i"
          done
          CLAUDE_RUNNER_MSG="✓ ${local.capacity} Claude Code self-hosted runner(s) started (tmux attach -t claude-runner; logs /tmp/claude-runner-*.log)"
        fi
      fi
      echo "$CLAUDE_RUNNER_MSG"
      echo "$CLAUDE_RUNNER_MSG" >> ~/WELCOME.txt
    fi
  EOT
}
