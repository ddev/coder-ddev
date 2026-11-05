# Using the Coder CLI

Everything in a workspace can be done from the browser, but the `coder` command-line tool on your own computer adds SSH, file copying, port forwarding and desktop editors. Coder's own [CLI reference](https://coder.com/docs/reference/cli) documents every command; this page covers the ones you need for coder.ddev.com.

## Install

=== "macOS"

    ```bash
    brew install coder
    ```

=== "Linux"

    ```bash
    curl -L https://coder.com/install.sh | sh
    ```

=== "Windows"

    ```powershell
    winget install Coder.Coder
    ```

See [Coder's installation docs](https://coder.com/docs/install/cli) for other methods. Check that it works with `coder version`.

!!! tip "Keep the CLI up to date"
    The CLI warns you when its version doesn't match the server's. Upgrade it the same way you installed it (for example `brew upgrade coder`).

## Log in

```bash
coder login https://coder.ddev.com
```

This opens your browser, where you approve the login with your coder.ddev.com account; the CLI then stores a session token. `coder whoami` shows who you're logged in as, and `coder logout` removes the token.

## Manage workspaces

```bash
coder list                                   # your workspaces and their status
coder create --template freeform my-site     # create one (asks for each setting)
coder start my-site
coder stop my-site
coder restart my-site
coder delete my-site                         # deletes everything in it
coder show my-site                           # resources, agents and apps
```

`coder start`, `coder stop`, `coder restart` and `coder delete` each take one workspace name.

To give a list of project names, which contain commas, use a parameter file instead of `--parameter`; see [Creating a freeform workspace](../freeform/create.md#from-the-command-line).

### Template updates

When the template gets a new version, the workspace page shows an **Update** button. From the CLI:

```bash
coder update my-site
```

This stops the workspace if it is running, rebuilds it with the new template version and starts it again. Your home directory and databases are kept.

To change a setting from the CLI, use `coder update my-site --always-prompt`, which asks for every setting again. Changing settings in the web UI (**Settings → Parameters**) is usually simpler.

### Schedules

```bash
coder schedule show my-site          # when it stops automatically
coder schedule extend my-site 2h     # keep a running workspace up 2 more hours
```

See [Coder's workspace scheduling docs](https://coder.com/docs/user-guides/workspace-scheduling).

## SSH into a workspace

```bash
coder ssh my-site                 # interactive shell
coder ssh my-site -- ddev list    # run one command

# run a command in a particular directory
coder ssh my-site -- env -C /home/coder/my-site ddev describe
```

Add `-A` (`--forward-agent`) to forward your computer's SSH agent, so Git and DDEV's containers in the workspace can use the keys on your computer or in a password manager such as 1Password. See [Git and SSH keys](editors-and-ssh.md#git-and-ssh-keys).

## Use plain `ssh`, `scp` and `rsync`

```bash
coder config-ssh --yes
```

This adds an entry to `~/.ssh/config` for each of your workspaces, so any SSH-based tool can reach them as `<workspace>.coder`:

```bash
ssh my-site.coder
scp dump.sql.gz my-site.coder:~/my-site/
rsync -av ./files/ my-site.coder:~/my-site/web/sites/default/files/
```

Run `coder config-ssh` again when you create a new workspace. Desktop editors that connect over SSH (VS Code Remote - SSH, JetBrains Gateway, Zed and others) use the same entries. See [Editors, SSH and files](editors-and-ssh.md).

## Forward ports to your computer

```bash
# local port 3306 → workspace port 32789
coder port-forward my-site --tcp 3306:32789

# same port number on both ends
coder port-forward my-site --tcp 5173
```

The forward stays open until you press Ctrl-C. Use it for desktop database clients or for anything else listening in the workspace; see [Database tools](../freeform/services.md#database-tools). For the web-based alternative, see [Coder's port forwarding docs](https://coder.com/docs/user-guides/workspace-access/port-forwarding).

## Open apps and editors

```bash
# desktop VS Code, in the workspace's default directory
coder open vscode my-site

# desktop VS Code, in a specific directory
coder open vscode my-site /home/coder/my-site

# an app by its slug; here, the site of the project my-site
coder open app my-site my-site
```

`coder open vscode` needs desktop VS Code with the [Coder extension](https://marketplace.visualstudio.com/items?itemName=coder.coder-remote).

## Troubleshooting connections

```bash
coder ping my-site        # latency; direct or relayed connection
coder speedtest my-site   # throughput to the workspace
coder netcheck            # network diagnostics
```

## Tokens for scripts

For scripts or CI that need to talk to coder.ddev.com, create a token instead of using your login:

```bash
coder tokens create --name my-script
coder tokens list
coder tokens remove my-script
```

Use it with `CODER_URL=https://coder.ddev.com CODER_SESSION_TOKEN=<token> coder list`. See [Coder's token docs](https://coder.com/docs/admin/users/sessions-tokens).
