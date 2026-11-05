# Editors, SSH and Files

## VS Code for Web

Click **VS Code** on the workspace page. It opens in the directory named after the workspace (`~/<workspace>`), with a built-in terminal (**Terminal → New Terminal**). Extensions you install from the Extensions view persist across restarts. The extensions installed by default are chosen with the **VS Code Extensions** setting; see [Creating a workspace](../freeform/create.md#vs-code-extensions).

## SSH from your computer

Install the Coder CLI and run `coder config-ssh` once; then `coder ssh my-workspace` or plain `ssh my-workspace.coder` opens a shell. See [Using the Coder CLI](coder-cli.md) for installation, logging in, and the other commands.

## Desktop editors

- **VS Code**: install the [Coder extension](https://marketplace.visualstudio.com/items?itemName=coder.coder-remote) and run `coder open vscode my-workspace`, or use the Remote - SSH extension and connect to `my-workspace.coder`. See [Coder's VS Code docs](https://coder.com/docs/user-guides/workspace-access/vscode).
- **JetBrains IDEs** (PhpStorm and others): use [JetBrains Toolbox with the Coder plugin](https://coder.com/docs/user-guides/workspace-access/jetbrains), or JetBrains Gateway over SSH to `my-workspace.coder`.
- **Any SSH-capable editor** works the same way, with `my-workspace.coder` as the host.

## Copying files

After `coder config-ssh`, use `scp` or `rsync` with the `.coder` host name:

```bash
# Upload a database dump, then import it
scp ~/Downloads/dump.sql.gz my-workspace.coder:~/my-site/
coder ssh my-workspace -- env -C /home/coder/my-site ddev import-db --file=dump.sql.gz

# Download a file
scp my-workspace.coder:~/my-site/backup.sql.gz .

# Sync a directory
rsync -av ./files/ my-workspace.coder:~/my-site/web/sites/default/files/
```

For small files, you can also drag them into the VS Code for Web file explorer, or right-click a file there and choose **Download**.

## Forwarding ports to your computer

`coder port-forward my-workspace --tcp <local>:<workspace>` makes a port in the workspace available on your computer, for example for a desktop database client. See [Using the Coder CLI](coder-cli.md#forward-ports-to-your-computer) and [Database tools](../freeform/services.md#database-tools).

## Git and SSH keys

Coder creates an SSH key for your account, and Git in every workspace uses it automatically. Add its public key to your Git host once:

1. Copy the public key from [your account's SSH keys page](https://coder.ddev.com/settings/ssh-keys), or run `coder publickey` on your computer.
2. Add it to [GitHub](https://github.com/settings/keys), [GitLab](https://gitlab.com/-/user_settings/ssh_keys), [drupal.org](https://www.drupal.org/user) (**SSH keys** tab on your profile) or any other host.
3. Test it in the workspace: `ssh -T git@github.com`.

Set your Git identity once; it's stored in your home directory and persists:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### SSH keys inside DDEV containers

DDEV's containers can use the same keys, for example for `ddev composer install` with private repositories, or for Drush aliases. Nothing needs setting up and you don't need `ddev auth ssh`:

```bash
ddev exec ssh -T git@github.com
```

The workspace relays DDEV's SSH agent to the best available agent, in this order:

1. **Your own agent, when it is forwarded**: by desktop VS Code, or by `coder ssh -A`. This lets you use keys from your computer or a password manager such as 1Password.
2. **Your Coder key** otherwise.

The most recent terminal or session that forwards an agent wins, for the whole workspace. While an agent is forwarded, any container on the DDEV network can ask it to sign, so an agent that confirms each use is safer.
