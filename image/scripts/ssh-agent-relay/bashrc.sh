# Sourced from ~/.bashrc in interactive shells. If this shell has a working
# forwarded SSH agent (VS Code Remote, `coder ssh -A`), point the workspace
# relay at it, so DDEV's containers get the same keys. Then use the relay for
# this shell's own SSH_AUTH_SOCK, so it keeps working after a reconnect and
# falls back to the Coder key when no agent is forwarded.
# The last shell to start wins: `current` is shared by the whole workspace.

_relay_dir="$HOME/.ssh-agent-relay"

# ssh-add -l exits 0 or 1 when it reaches an agent, 2 when it can't, and
# timeout exits 124 so a hung forwarded socket can't stall the shell.
_ssh_agent_alive() {
  SSH_AUTH_SOCK="$1" timeout 2 ssh-add -l > /dev/null 2>&1
  [ $? -le 1 ]
}

if [ -d "$_relay_dir" ]; then
  if [ -n "${SSH_AUTH_SOCK:-}" ] && [ "$SSH_AUTH_SOCK" != "$_relay_dir/agent.sock" ] \
    && _ssh_agent_alive "$SSH_AUTH_SOCK"; then
    ln -sfn "$(readlink -f "$SSH_AUTH_SOCK")" "$_relay_dir/current"
  fi
  if [ -S "$_relay_dir/agent.sock" ] && _ssh_agent_alive "$_relay_dir/agent.sock"; then
    export SSH_AUTH_SOCK="$_relay_dir/agent.sock"
  fi
fi

unset _relay_dir
unset -f _ssh_agent_alive
