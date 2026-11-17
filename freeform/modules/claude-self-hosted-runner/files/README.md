# Claude Code self-hosted runner

The workspace's "Run a Claude Code self-hosted runner" setting created this
directory. The workspace rewrites this README on every start.

## Start the runner

1. On claude.ai, create a self-hosted environment and copy its environment
   secret.
2. Save the secret here:

   ```bash
   # paste the secret, press Enter, then Ctrl-D
   cat > ~/.claude-runner/environment-secret
   chmod 600 ~/.claude-runner/environment-secret
   ```

3. Restart the workspace. The runner starts only when
   `environment-secret` exists and is not empty.

## What is here

- `environment-secret`: the secret you saved. Keep it mode 600.
- `hooks/runner-<n>/post-session`: the hook that cleans runner `<n>`'s
  checkouts after each session. The workspace creates it, so do not edit it.

## Find things

- Runners: `tmux attach -t claude-runner`, logs in
  `/tmp/claude-runner-<n>.log`.
- Live sessions, their checkouts and unpushed commits: `claude-sessions`.
- Checkouts: `~/workspace/runner-<n>/<owner>/<repo>`.
- Work a session left uncommitted: `git stash list | grep runner-rescue` in
  the checkout. Extra clones with unpushed commits are moved to
  `~/.local/state/claude-runner-rescue/`, and its `log` lists every change.
  Both are kept for 30 days.

## GitHub access

Sessions clone, fetch and push to `origin` over HTTPS as the GitHub account
connected to the claude.ai account that started them, under Settings →
Connectors on claude.ai. Every person who starts sessions here needs that
connection. The GitHub MCP tools in a session use the same account. A
session started without a repository gets no clone and no GitHub MCP tools.

`gh` in a session is this workspace's own `/usr/bin/gh`. It isn't logged in,
so it doesn't work, and sessions use the GitHub MCP tools instead. Don't run
`gh auth login` or store a `GH_TOKEN` here: every session, whoever started
it, would then act on GitHub as you.

SSH remotes use this workspace's SSH agent: your forwarded agent, or your
Coder key, which is the same in all your workspaces. SSH pushes act as you
in every session. The workspace adds GitHub's host keys to
`~/.ssh/known_hosts` on start.

This runner is personal. Every runner that uses this environment secret
takes sessions from anyone who can start sessions in the environment, and
runs them as you, with your SSH agent and Coder key. Don't share the
environment with other people.

## Troubleshooting

- A session fails before Claude starts, and the log shows
  `Repository access validation failed` and `GitHub authentication
  required. Please reconnect your GitHub account.`: the person who started
  the session must reconnect GitHub on claude.ai, then start the session
  again. Until then each runner that picks it up exits and restarts, which
  is expected.
- `gh` in a session says it isn't logged in: expected. Sessions use the
  GitHub MCP tools.

## Stop the runner

Turn the setting off and restart the workspace. To stop it until the next
start, run `tmux kill-session -t claude-runner`.

More: <https://docs.coder.ddev.com/workspaces/ai-tools/#claude-code-self-hosted-runner>
