# Creating a Freeform Workspace

## From the web

1. Open [the freeform template](https://coder.ddev.com/templates/coder/freeform/workspace?mode=manual).
2. Give the workspace a **name**. Use lowercase letters, digits and hyphens, for example `client-site`. The name appears in all of the workspace's URLs.
3. Fill in the settings described below, or leave the defaults.
4. Click **Create workspace**. The workspace is usually ready in about a minute; you can watch the startup log on the workspace page.

## Settings

You can change every setting below later. On the workspace page, open **Settings → Parameters**, change the value, then restart the workspace. Changes take effect on the next start.

### DDEV project names

A comma-separated list of the DDEV projects you plan to run, for example `shop,blog`. For each name, the workspace gets:

- an app button for the site, labeled with the project name,
- a **Mailpit (name)** button for captured email,
- an **xhgui (name)** button for profiling.

Leave it empty for a single project with the same name as the workspace.

!!! warning "Names must match exactly"
    The name you list here must be exactly the name of the DDEV project (`name:` in `.ddev/config.yaml`, set with `ddev config --project-name=...`). Use lowercase letters, digits and hyphens. If a project isn't listed, its site has no app button and no working URL. `ddev coder-setup` warns you when this happens.

### Public Sharing

Off by default, so only you can open your sites. Turn it on to let anyone with the link open every listed project's site, without signing in. Mailpit and xhgui always stay private. See [Sharing your site](sharing.md).

### VS Code Extensions

Choose which extensions VS Code for Web installs. You can also install more extensions from the Extensions view at any time; they stay installed across restarts.

### Enable Claude Code remote control

Off by default. Turn it on to control Claude Code running in this workspace from [claude.ai/code](https://claude.ai/code) or the Claude mobile app. **Claude Code: skip permission prompts** passes `--dangerously-skip-permissions`. See [Claude Code](../workspaces/ai-tools.md#claude-code-remote-control).

### Run a Claude Code self-hosted runner

Off by default. Turn it on to have this workspace run sessions you start on claude.ai/code in a self-hosted environment. **Claude Code runner: concurrent sessions** sets how many run at once (1 to 4). This can't be combined with remote control, and the workspace should be used only for the runner. See [Claude Code](../workspaces/ai-tools.md#claude-code-self-hosted-runner).

## From the command line

With the [Coder CLI](../workspaces/coder-cli.md) logged in to coder.ddev.com:

```bash
coder create --template freeform my-workspace
```

The CLI asks for each setting. Because a list of project names contains commas, put it in a file instead of using `--parameter`, which splits values on commas:

```bash
cat > params.yaml <<'YAML'
project_names: "shop,blog"
YAML
coder create --template freeform my-workspace --rich-parameter-file params.yaml --yes
```

## Resources

Each workspace gets the CPU, memory and disk that coder.ddev.com allocates to every workspace. You don't choose them when creating it. If you need more, [open an issue](https://github.com/ddev/coder-ddev/issues) to discuss your use case.
