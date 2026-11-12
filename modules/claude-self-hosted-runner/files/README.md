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

Sessions reach GitHub over HTTPS and `gh` as the GitHub account connected
to the claude.ai account that started them, under Settings → Connectors on
claude.ai. Every person who starts sessions here needs that connection.
SSH remotes are different: they use this workspace's SSH agent, so they act
as the workspace owner for every session.

Every runner that uses this environment secret takes sessions from anyone
who can start sessions in the environment, and runs them as this
workspace's user, with its SSH agent. Share the environment only with
people you trust with those keys.

## Troubleshooting

- A session fails before Claude starts, and the log shows
  `Repository access validation failed` and `GitHub authentication
  required. Please reconnect your GitHub account.`: the person who started
  the session must reconnect GitHub on claude.ai, then start the session
  again. Until then each runner that picks it up exits and restarts, which
  is expected.
- `gh auth status` in a session says the token in `GH_TOKEN` is invalid:
  expected. Sessions send `gh` through a REST-only proxy with a placeholder
  token. `gh api user --jq .login` shows the account a session uses.

## Stop the runner

Turn the setting off and restart the workspace. To stop it until the next
start, run `tmux kill-session -t claude-runner`.

More: <https://docs.coder.ddev.com/workspaces/ai-tools/#claude-code-self-hosted-runner>
