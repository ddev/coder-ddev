# SSH agent for the workspace and DDEV's containers (#210, #220). Runs after
# Docker is up, because `ddev config global` needs it.
#
# - ~/.coder-ssh-agent/agent.sock: an ssh-agent holding the Coder workspace
#   key, so plain ssh and DDEV's containers have a key even with nothing
#   forwarded (git alone already gets it from GIT_SSH_COMMAND).
# - ~/.ssh-agent-relay/agent.sock: one stable socket that relays each
#   connection to the best live agent (see /home/coder-files/ssh-agent-relay/
#   connect): the user's forwarded agent from VS Code or `coder ssh -A` when
#   there is one, otherwise the Coder-key agent. DDEV's ssh_agent_upstream
#   points here, never at the `current` symlink, since DDEV resolves symlinks
#   once when the project starts.
#
# Each socket gets its own directory because DDEV bind-mounts the socket's
# whole directory into ddev-ssh-agent.
SSH_AGENT_DIR="$HOME/.coder-ssh-agent"
SSH_RELAY_DIR="$HOME/.ssh-agent-relay"
SSH_RELAY_FILES=/home/coder-files/ssh-agent-relay
mkdir -p "$SSH_AGENT_DIR" "$SSH_RELAY_DIR"
chmod 700 "$SSH_AGENT_DIR" "$SSH_RELAY_DIR"

# $HOME persists across restarts and ssh-agent -a refuses an existing socket.
pkill -u "$(id -u)" -f "ssh-agent -a $SSH_AGENT_DIR/agent.sock" 2> /dev/null || true
rm -f "$SSH_AGENT_DIR/agent.sock"
if setsid ssh-agent -a "$SSH_AGENT_DIR/agent.sock" > /dev/null 2>&1 < /dev/null; then
  # The key goes straight from the API into the agent, never to disk.
  if curl -fsS --max-time 10 -H "Coder-Session-Token: ${CODER_AGENT_TOKEN:-}" \
    "${CODER_AGENT_URL%/}/api/v2/workspaceagents/me/gitsshkey" \
    | jq -r .private_key | SSH_AUTH_SOCK="$SSH_AGENT_DIR/agent.sock" ssh-add -q - 2> /dev/null; then
    echo "✓ Coder SSH key loaded into $SSH_AGENT_DIR/agent.sock"
  else
    echo "⚠ Could not load the Coder SSH key into $SSH_AGENT_DIR/agent.sock"
  fi
else
  echo "⚠ Could not start ssh-agent at $SSH_AGENT_DIR/agent.sock"
fi

if command -v socat > /dev/null 2>&1 && [ -x "$SSH_RELAY_FILES/connect" ]; then
  pkill -u "$(id -u)" -f "UNIX-LISTEN:$SSH_RELAY_DIR/agent.sock" 2> /dev/null || true
  nohup setsid socat UNIX-LISTEN:"$SSH_RELAY_DIR/agent.sock",fork,unlink-early,mode=600 \
    EXEC:"$SSH_RELAY_FILES/connect" > /dev/null 2>&1 < /dev/null &
  ddev config global --ssh-agent-upstream="$SSH_RELAY_DIR/agent.sock" > /dev/null 2>&1 || true
  if ! grep -qF "$SSH_RELAY_FILES/bashrc.sh" ~/.bashrc 2> /dev/null; then
    echo "[ -r $SSH_RELAY_FILES/bashrc.sh ] && . $SSH_RELAY_FILES/bashrc.sh" >> ~/.bashrc
  fi
  echo "✓ SSH agent relay at $SSH_RELAY_DIR/agent.sock (ddev ssh_agent_upstream)"
else
  echo "⚠ socat or $SSH_RELAY_FILES/connect missing; SSH agent relay not started"
fi
