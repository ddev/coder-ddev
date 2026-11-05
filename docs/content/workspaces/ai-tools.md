# Claude Code

Every workspace has [Claude Code](https://claude.com/claude-code) installed, and Claude can use everything in the workspace: DDEV, Docker, Git, Composer and the rest. You can use it in four ways:

| Way                                                          | Where you talk to Claude                         | Setup                                         |
| ------------------------------------------------------------ | ------------------------------------------------ | --------------------------------------------- |
| [In a terminal](#in-a-terminal)                              | A terminal in VS Code for Web, or over SSH       | None                                          |
| [VS Code extension](#in-vs-code)                             | A panel in VS Code for Web or desktop VS Code    | Install the extension once                    |
| [Remote control](#claude-code-remote-control)                | claude.ai/code or the Claude mobile app          | Turn on a workspace setting                   |
| [Self-hosted runner](#claude-code-self-hosted-runner)        | Sessions you start on claude.ai/code             | Turn on a workspace setting, save a secret    |

All of them use the same installation and the same login, both kept in your home directory, so they survive restarts.

## Logging in

The first time you run Claude Code, it asks how to log in:

1. Run `claude` in a terminal and choose to log in with your Claude account.
2. Claude Code prints a link. Open it in your browser, approve the login, and copy the code it shows.
3. Paste the code back into the terminal.

Claude Code works with a Claude Pro, Max, Team or Enterprise subscription, or with an Anthropic API key (set `ANTHROPIC_API_KEY`, for example in `~/.bashrc`). Remote control needs a subscription; API keys don't work for it.

## In a terminal

Open a terminal in the project directory (in VS Code for Web, **Terminal → New Terminal**) and start Claude:

```bash
cd ~/my-site
claude
```

Useful options:

```bash
claude --continue    # continue the last conversation here
claude --resume      # pick an earlier conversation

# one-off question: prints the answer and exits
claude -p "why does ddev start fail?"
```

!!! tip "Keep Claude running when you close the browser"
    A terminal in VS Code for Web ends when you close the tab, and so does a Claude session running in it. Start Claude inside `tmux` to keep it running, and reattach later from any terminal or SSH session:

    ```bash
    tmux new -s claude      # run claude in here; Ctrl-b d detaches
    tmux attach -t claude   # reattach later
    ```

    Or turn on [remote control](#claude-code-remote-control), which does this for you.

From your own computer, you can run Claude in the workspace over SSH with `coder ssh my-site`, then `cd` to the project and run `claude`. See [Using the Coder CLI](coder-cli.md).

## In VS Code

The [Claude Code extension](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code) adds a Claude panel to VS Code, with inline diffs of Claude's proposed changes.

**In VS Code for Web:**

1. Open the Extensions view (++ctrl+shift+x++, or ++cmd+shift+x++ on macOS).
2. Search for **Claude Code** and install the one published by **Anthropic**.
3. Open it with the Claude icon in the editor toolbar or the activity bar, or run **Claude Code: Open** from the Command Palette (++ctrl+shift+p++).

The extension is installed in the workspace, so it stays installed across restarts.

**In desktop VS Code:** connect to the workspace with the [Coder extension](https://marketplace.visualstudio.com/items?itemName=coder.coder-remote) (or `coder open vscode my-site`), then install the Claude Code extension in that remote window. VS Code installs it in the workspace, and Claude runs there, next to DDEV, rather than on your computer.

If you have already logged in from a terminal, the extension uses the same login. See Anthropic's [VS Code documentation](https://code.claude.com/docs/en/vs-code) for everything the extension can do.

## Tips for working with DDEV

- **Tell Claude the project uses DDEV.** Put a `CLAUDE.md` (or `AGENTS.md`) in the project saying to run PHP, Composer, Drush and tests through DDEV, for example `ddev composer install`, `ddev drush cr`, `ddev exec vendor/bin/phpunit`. Otherwise Claude may try to run them directly in the workspace, where the project's PHP version and extensions aren't installed.
- **Let Claude check the site from inside the workspace.** Claude can test its work with `curl`. Inside the workspace, the project's `https://<project>.ddev.site` URL reaches the site directly; the `coder.ddev.com` URLs need your browser login, so Claude can't use them. If `curl` rejects the certificate, run `mkcert -install` once.
- **Projects share one Docker daemon.** `ddev poweroff`, `ddev stop --all` or `docker system prune` affect every project in the workspace. Say so in `CLAUDE.md` if you run several projects.
- **Permission prompts.** By default Claude asks before running commands or editing files. You can allow specific commands as you go. Skipping prompts entirely (`--dangerously-skip-permissions`) lets Claude run anything in the workspace, including deleting databases.

## Keeping Claude Code up to date

Claude Code is installed with Homebrew, which persists across restarts:

```bash
brew upgrade claude-code@latest
claude --version
```

The VS Code extension updates itself from the Marketplace.

## Claude Code remote control

Turn on **Enable Claude Code remote control** in the workspace's settings (all templates offer it) to drive Claude Code in the workspace from [claude.ai/code](https://claude.ai/code) or the Claude mobile app, even when no browser tab or terminal is open.

1. Turn the setting on when creating the workspace, or later in **Settings → Parameters**, then restart.
2. **First use:** click the **Claude Code** app button on the workspace page (or SSH in and run `tmux attach -t <workspace>`) and complete the one-time login and the workspace trust prompt.
3. The session then shows up on claude.ai/code under the workspace's name.

Claude runs in the `tmux` session named after the workspace, starting in your home directory. To work in a particular project, `cd` into it in any terminal and run `claude-here`. That starts a new remote-control session in that directory, named `<workspace>-<directory>`, and the previous session stops appearing in claude.ai/code.

- **Claude Code: skip permission prompts** runs Claude with `--dangerously-skip-permissions`. Only use it if you're comfortable with Claude running any command in the workspace without asking.
- Requires a Claude Pro, Max, Team or Enterprise subscription. API keys, Bedrock, Vertex and custom gateways are not supported.
- Remote sessions disconnect after about 10 minutes offline. The workspace restarts Claude when it starts, or when you click the **Claude Code** app button.

## Claude Code self-hosted runner

**Freeform only.** Turn on **Run a Claude Code self-hosted runner** to make the workspace a self-hosted environment for Claude Code on the web. Sessions you start on claude.ai/code in that environment then run in this workspace, with its Docker and DDEV.

One-time setup:

1. On claude.ai, create a self-hosted environment and copy its environment secret.
2. In the workspace, save it:

    ```bash
    mkdir -p ~/.claude-runner
    # paste the secret, press Enter, then Ctrl-D
    cat > ~/.claude-runner/environment-secret
    chmod 600 ~/.claude-runner/environment-secret
    ```

3. Restart the workspace.

On every start, the runner runs in the `tmux` session `claude-runner` (`tmux attach -t claude-runner`), logging to `/tmp/claude-runner-<n>.log`. Sessions clone their repositories under `~/workspace/runner-<n>`. Run `claude-sessions` to list live sessions with their checkout, branch and number of unpushed commits.

- **Use a workspace only for the runner.** The runner rewrites `~/.gitconfig` and `~/.config/git` before every session. It can't be turned on together with remote control.
- **Concurrent sessions** (1 to 4) sets how many sessions run at once. They share the workspace's Docker daemon and DDEV, and a skill installed in `~/.claude/skills/coder-shared-workspace` tells them how to stay out of each other's way. For full isolation, use several workspaces with one session each; the same environment secret works in all of them.
