# Claude Code

Every workspace has [Claude Code](https://claude.com/claude-code) installed. You can use it three ways.

## In a terminal

Open a terminal in the workspace and run `claude` in your project directory. The first time, it asks you to log in. Your login is kept in your home directory, so it survives restarts.

## Claude Code remote control

Turn on **Enable Claude Code remote control** in the workspace's settings (all templates offer it) to drive Claude Code in the workspace from [claude.ai/code](https://claude.ai/code) or the Claude mobile app, even when no browser tab or terminal is open.

1. Turn the setting on when creating the workspace, or later in **Settings → Parameters**, then restart.
2. **First use:** click the **Claude Code** app button on the workspace page (or SSH in) and complete the one-time Claude login and the workspace trust prompt.
3. The session then shows up on claude.ai/code under the workspace's name.

To work in a particular project, `cd` into it in any terminal and run `claude-here`. That starts a new remote-control session in that directory, named after it, and the previous session stops appearing in claude.ai/code.

- **Claude Code: skip permission prompts** runs Claude with `--dangerously-skip-permissions`. Only use it if you're comfortable with Claude running any command in the workspace without asking.
- Requires a Claude Pro, Max, Team or Enterprise subscription. API keys, Bedrock, Vertex and custom gateways are not supported.
- Remote sessions disconnect after about 10 minutes offline.

## Claude Code self-hosted runner

**Freeform only.** Turn on **Run a Claude Code self-hosted runner** to make the workspace a self-hosted environment for Claude Code on the web. Sessions you start on claude.ai/code in that environment then run in this workspace, with its Docker and DDEV.

One-time setup:

1. On claude.ai, create a self-hosted environment and copy its environment secret.
2. In the workspace, save it:

    ```bash
    mkdir -p ~/.claude-runner
    cat > ~/.claude-runner/environment-secret   # paste, press Enter, then Ctrl-D
    chmod 600 ~/.claude-runner/environment-secret
    ```

3. Restart the workspace.

On every start, the runner runs in the `tmux` session `claude-runner` (`tmux attach -t claude-runner`), logging to `/tmp/claude-runner-<n>.log`. Sessions clone their repositories under `~/workspace/runner-<n>`. Run `claude-sessions` to list live sessions with their checkout, branch and number of unpushed commits.

- **Use a workspace only for the runner.** The runner rewrites `~/.gitconfig` and `~/.config/git` before every session. It can't be turned on together with remote control.
- **Concurrent sessions** (1 to 4) sets how many sessions run at once. They share the workspace's Docker daemon and DDEV, and a skill installed in `~/.claude/skills/coder-shared-workspace` tells them how to stay out of each other's way. For full isolation, use several workspaces with one session each; the same environment secret works in all of them.
