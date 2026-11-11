---
name: coder-shared-workspace
description: Rules for sharing this Coder workspace, its Docker daemon and its DDEV install with other Claude sessions that the self-hosted runner runs at the same time. Read before running ddev, docker, or a repository's integration tests, before cleaning up disk, and before working in a checkout another session may be using.
---

# Sharing this workspace with other sessions

This workspace runs a Claude Code self-hosted runner that can host several
sessions at once. They all run as the same Unix user, with the same home
directory, one Docker daemon and one DDEV global configuration. Nothing
isolates them except the rules below.

## See who else is here

```bash
pgrep -af -- '--sdk-url' | grep -o 'sessions/cse_[A-Za-z0-9]*' | sort -u
pgrep -af -- '--sdk-url' | grep -o -- '--add-dir [^ ]*' | sort | uniq -c
```

The first lists active sessions; the second shows which directories they
work in. If you are the only session, the rest of this file still applies,
since another session can start at any time.

## Repositories and checkouts

- Each runner clones into its own directory, `~/workspace/runner-<n>/`, so
  no other session uses your checkout while you work. Never change files,
  branches or git state under another runner's directory.
- A runner keeps its checkouts from one session to the next. After every
  session, `claude-runner-sweep` cleans them: it stashes uncommitted changes
  as `runner-rescue` stashes, removes worktrees, and moves other clones to
  `~/.local/state/claude-runner-rescue/`. See "Leave the checkout clean"
  below.
- Work in the checkout the runner gave you. Do not make a new clone, and
  never make a worktree or clone to get around files an earlier session
  left behind. If a task needs a second checkout, ask the user first.
- Put scratch files in `~/tmp/<your session id>/`, not directly in `~/tmp`.

## Leave the checkout clean

When a session starts in a checkout that is not clean, a hook prints the
changed paths. Untracked files left by another branch can break a build or
change what it generates, such as DDEV's image tags.

- If the hook reports leftovers, they are not yours. Save them, then carry
  on in the same checkout:
  `git stash push --include-untracked -m "leftovers from an earlier session"`.
  Do not commit, delete or restore them.
- The runner can end your session without warning once the user has sent
  nothing for 30 minutes. Before you finish a turn and wait for the user,
  commit your work, and push it if the task includes pushing. What you
  leave uncommitted is stashed when the session ends, and a resumed session
  may run on another runner, in a checkout without it.
- If the hook says this session was released earlier and its changes were
  saved, tell the user what was saved before restoring any of it.
- At the end, delete the branches, worktrees and stashes you created, and
  leave `git status` clean.

## Tools and permission denials

`go`, `make`, `golangci-lint` and the other Homebrew tools are on PATH in
every shell. A login shell is not needed. When a command fails with
"Permission ... has been denied", a permission rule blocked it. The tool is
not missing. Read the repository's `AGENTS.md` and `.claude/settings.json`
for the command to use instead, such as `make` in place of `go build`.

## Docker and DDEV

There is one Docker daemon. A command that affects every container affects
every session.

- **Never** run these unless the user asks for them:
  `ddev poweroff`, `ddev stop --all`, `ddev delete images`,
  `ddev clean`, `docker system prune`, `docker volume prune`,
  `docker rm -f $(docker ps -aq)`, or anything that restarts dockerd.
  Stop, restart or delete only projects you started.
- Give your session its own DDEV global directory with
  [`DDEV_XDG_CONFIG_HOME`](https://docs.ddev.com/en/stable/users/usage/architecture/#global-files),
  seeded from the workspace's, so your project list and global settings
  are yours:

  ```bash
  export DDEV_XDG_CONFIG_HOME=~/tmp/<your session id>/config
  mkdir -p "$DDEV_XDG_CONFIG_HOME/ddev"
  cp -r ~/.ddev/global_config.yaml ~/.ddev/commands "$DDEV_XDG_CONFIG_HOME/ddev/"
  ```

  Shell state does not carry over between your commands, so export the
  variable in every command that runs `ddev`, including test runs. Keep the
  router settings copied from `~/.ddev` unchanged: the router and
  `ddev-ssh-agent` containers are shared by every session. Never edit
  `~/.ddev/global_config.yaml` itself.
- Project names are still global, because Docker container names are.
  Give throwaway projects names no other session will pick, such as
  `<purpose>-<first 8 characters of your session id>`, and delete them with
  `ddev delete -Oy <name>` when done. The names registered in the workspace
  (`$CODER_PROJECT_NAMES`) are the only ones reachable from a browser. Each
  session's `ddev list` shows only its own projects, so list every running
  one with `docker ps --format '{{.Label "com.ddev.site-name"}}' | grep . | sort -u`,
  and ask before taking a name another session is using.
- Do not set fixed host ports (`host_https_port`, `host_webserver_port`,
  `host_db_port`) in a project. Let DDEV choose, so two projects never
  collide. Pick free ports for any other server you run.
- A project you started may be stopped by another session's tests (see
  below). If it is, `ddev start` it again.

## Tests that take over Docker

Some test suites start and power off DDEV projects on their own, for
example the integration tests of `ddev/ddev` (`make testpkg`, `make testcmd`,
`go test ./pkg/ddevapp/...`), which run `ddev poweroff`. Run those only
while holding the workspace-wide Docker lock, so two of them never run at
the same time:

```bash
flock --exclusive ~/.cache/coder-docker.lock make testpkg TESTARGS="-run TestName"
```

`flock` waits until the lock is free. Tell the user when you have been
waiting more than a few minutes, rather than waiting silently. Code that
only compiles or runs unit tests that do not touch Docker needs no lock.

## Disk

The disk is shared. When it fills up, stop what you started and delete
only what you created (build output, your worktrees, your `~/tmp`
directory, your test projects). Never delete another session's files, and
never prune Docker images or volumes another session may use.

## Pushing over SSH

`SSH_AUTH_SOCK` points at the workspace SSH agent relay,
`~/.ssh-agent-relay/agent.sock`. The relay uses the user's own agent when
one is forwarded (VS Code, `coder ssh -A`). Otherwise it uses the Coder
workspace key, which GitHub accepts once the user adds it to their account
(`coder publickey` prints it).

- When you add a remote, such as the user's fork, use its SSH URL:
  `git remote add <name> git@github.com:<owner>/<repo>`. HTTPS pushes go
  through the session's git proxy, which reaches only the repositories
  attached to the session.
- Leave `origin` as the runner cloned it.
- `ssh -T git@github.com` greets the user by name when SSH works.
- On `Permission denied (publickey)`, ask the user to forward an agent or
  add the Coder key to GitHub. Never create, copy or print keys.
