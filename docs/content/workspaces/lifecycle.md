# Workspace Lifecycle

## Starting, stopping and deleting

Use the buttons on the workspace page, or the [Coder CLI](coder-cli.md):

```bash
coder start my-workspace
coder stop my-workspace
coder restart my-workspace
coder delete my-workspace
```

- **Stopping** shuts down the workspace container. DDEV projects stop with it. Your files and databases are kept.
- **Starting** brings it back in about a minute. Running DDEV projects aren't restarted automatically; run `ddev start` (or `ddev start --all`), or use a [startup hook](#running-things-automatically-on-start).
- **Deleting** removes the workspace and **everything in it**, including your home directory and databases. Push your code and export anything you need first.

A workspace may also be stopped automatically after a period without activity; the workspace page shows its schedule.

## What persists

| Kept when the workspace stops                                  | Lost when the workspace stops                                   |
| -------------------------------------------------------------- | --------------------------------------------------------------- |
| Everything in your home directory, `/home/coder`               | Running processes (DDEV projects, servers, `tmux` sessions)     |
| DDEV databases, Docker images and volumes                      | Files in `/tmp`                                                 |
| Homebrew packages (`brew install`) in `/home/linuxbrew`        | System packages installed with `sudo apt-get install`           |
| VS Code settings and extensions                                | Changes elsewhere on the system, outside your home directory    |

If you need a system package every time, install it with Homebrew, or install it from a [startup hook](#running-things-automatically-on-start).

## Idle workspaces are deleted

To keep disk space available for everyone, coder.ddev.com deletes workspaces that haven't been used for a while:

1. After **7 days** without use, you get an email warning that the workspace will be deleted.
2. If you still haven't used it **7 days** after that email, it is deleted.

Using the workspace (opening VS Code, a terminal, SSH or one of its sites) cancels the pending deletion. **Keep your work in Git** and push it regularly; treat a workspace as something you can recreate.

## Running things automatically on start

If `~/.coder-startup.sh` exists and is executable, the workspace runs it every time it starts, after Docker and DDEV are ready. No terminal needs to be open.

```bash
cat > ~/.coder-startup.sh <<'SCRIPT'
#!/usr/bin/env bash
cd ~/my-site && ddev start
cd ~/blog && ddev start
SCRIPT
chmod +x ~/.coder-startup.sh
```

- It runs in the background, so a slow or failing script doesn't stop the workspace from becoming ready.
- Output goes to `/tmp/coder-startup-user.log`.
- It doesn't load `~/.bashrc`. `PATH` includes `~/.local/bin`, `~/.npm-global/bin` and Homebrew; set anything else inside the script.
- It runs on every start, so make it safe to run more than once.

## Disk space

All of your projects, Docker images and databases share the workspace's disk. To see how much is used and free some up:

```bash
df -h /home/coder /var/lib/docker
docker system df
ddev delete images            # remove old DDEV images
ddev clean --all              # remove DDEV images and ALL projects' snapshots
docker system prune           # remove unused containers, networks and images
```

## Installing more tools

You have passwordless `sudo`, but system packages installed with `apt-get` disappear when the workspace stops. Prefer:

- **Homebrew**: `brew install <package>`. It persists.
- **npm global packages**: `npm install -g <package>`. They go to `~/.npm-global` and persist.
- **Tools inside DDEV**: add them to the project's web container with `webimage_extra_packages` in `.ddev/config.yaml` or a [custom Dockerfile](https://docs.ddev.com/en/stable/users/extend/customizing-images/). This also keeps them with the project for everyone else.
