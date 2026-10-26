# Change: SSH Agent for the Workspace and DDEV Containers

## Why
Only `git` in a workspace can use the Coder-managed SSH key, through `GIT_SSH_COMMAND`. Plain `ssh` has no agent, and DDEV's containers have neither the key nor the user's own keys, so `composer install` with private repositories, `drush` aliases, and `git` in post-start hooks fail inside `web` (#210).

A user's own agent forwarded by VS Code Remote or `coder ssh -A` doesn't reach the containers reliably either: every reconnect creates a new socket and leaves the old one dead, so containers and terminals started before a reconnect lose the agent (#220).

DDEV v1.25.5 adds `ssh_agent_upstream` (ddev/ddev#8861) and resolves symlinked agent sockets (ddev/ddev#8963), which this change builds on. #210 and #220 both set `ssh_agent_upstream` and `SSH_AUTH_SOCK`, so they are done together.

## What Changes
- The image installs `socat`, `fzf` and `zstd`, and ships `/home/coder-files/ssh-agent-relay/connect` and `bashrc.sh`. `VERSION` goes to `v0.6`, which also brings DDEV v1.25.5.
- New shared startup snippet `shared/ssh-agent-setup.sh`, vendored into each template by `make sync-ssh-agent-setup` and included in each template's `startup_script` after Docker is up:
  - Starts `ssh-agent` on `~/.coder-ssh-agent/agent.sock` and loads the Coder key from `/api/v2/workspaceagents/me/gitsshkey`, piped straight into `ssh-add -`.
  - Starts a `socat` relay on `~/.ssh-agent-relay/agent.sock` that runs `connect` for each connection. `connect` uses the first live agent of: the `current` symlink (the forwarded agent of the most recent interactive shell), the newest live `/tmp/auth-agent*/listener.sock`, and the Coder-key agent.
  - Runs `ddev config global --ssh-agent-upstream=~/.ssh-agent-relay/agent.sock`. It never points at `current`, because DDEV resolves symlinks once at project start.
  - Adds one line to `~/.bashrc` that sources `bashrc.sh`. In interactive shells with a live forwarded agent, `bashrc.sh` retargets `current`, and it then sets the shell's `SSH_AUTH_SOCK` to the relay. Both liveness checks use `timeout 2 ssh-add -l`, and only exit codes 0 and 1 count as live.
- Each socket has its own directory, because DDEV bind-mounts the socket's directory into `ddev-ssh-agent`.
- `docs/user/using-workspaces.md` documents the behavior, including that the most recent forwarding session wins for the whole workspace, which matters with workspace sharing.

## Impact
- Affected specs: `workspace-ssh-agent` (new capability)
- Affected code: `image/Dockerfile`, `image/scripts/ssh-agent-relay/`, `shared/ssh-agent-setup.sh` (and vendored copies), `drupal-core/template.tf`, `drupal-contrib/template.tf`, `freeform/template.tf`, their `tests/validate.tftest.hcl`, `Makefile`, `VERSION`, `docs/user/using-workspaces.md`
- Security: any container on a project's DDEV network can ask the relayed agent to sign. That's the same exposure as `ddev auth ssh` with an upstream agent; the Coder key is one the workspace user can already fetch, and agents like 1Password confirm each use.
