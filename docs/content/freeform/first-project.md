# Your First Freeform Project

This walkthrough takes you from an empty workspace to a running site. It assumes a workspace named `my-site` created with the default settings, so its one registered project name is also `my-site`.

## 1. Open a terminal

On the workspace page, click **VS Code**. When it opens, choose **Terminal → New Terminal** from the menu (☰). VS Code opens in `~/my-site`, a directory named after the workspace; it may not exist yet, in which case VS Code opens your home directory.

You can also use SSH from your computer. See [Editors, SSH and files](../workspaces/editors-and-ssh.md).

## 2. Get your code

=== "Clone an existing project"

    Your workspace already has an SSH key that Git uses. Add it to your Git host once (see [Git and SSH keys](../workspaces/editors-and-ssh.md#git-and-ssh-keys)), then:

    ```bash
    git clone git@github.com:your-org/your-project.git ~/my-site
    cd ~/my-site
    ```

=== "Start a new project"

    ```bash
    mkdir ~/my-site && cd ~/my-site
    ```

    Then follow one of the [project recipes](recipes.md) for your framework.

## 3. Configure DDEV

If the project already has a `.ddev/` directory, make sure its name matches the registered project name:

```bash
ddev config --project-name=my-site
```

For a project without DDEV configuration, pick a type and docroot (see the [DDEV CMS quickstarts](https://docs.ddev.com/en/stable/users/quickstart/)):

```bash
ddev config --project-name=my-site --project-type=php --docroot=public
```

## 4. Connect the project to the workspace

```bash
ddev coder-setup
```

You only need to do this once per project. It adds a small DDEV hook (`.ddev/config.coder.yaml`) that writes the workspace's routing rules after every `ddev start`, and adds that file to your global Git ignore list so it never ends up in your repository.

## 5. Start the project

```bash
ddev start
```

Now open the site in any of these ways:

- Click the **my-site** app button on the workspace page.
- Run `ddev launch` in the terminal. It prints the URL (in VS Code, Ctrl-click or Cmd-click it).
- Run `ddev describe` to see the URLs of the site, Mailpit and any other services.

The URL looks like `https://my-site--my-site--your-username.coder.ddev.com`.

!!! note "Use the workspace URLs, not `*.ddev.site`"
    URLs like `https://my-site.ddev.site` only work on the machine DDEV runs on. In a workspace, always use the `coder.ddev.com` URLs above. `ddev describe` and `ddev launch` already show the right ones once `ddev coder-setup` has run.

## 6. Install dependencies and import data

Use DDEV's tools exactly as you would locally:

```bash
ddev composer install
ddev npm install
ddev import-db --file=dump.sql.gz
ddev import-files --source=files.tar.gz
```

To get a database dump or files into the workspace, drag them into the VS Code file explorer, or use `scp` from your computer. See [Editors, SSH and files](../workspaces/editors-and-ssh.md#copying-files).

## Next steps

- Add a second project: [Multiple projects](multiple-projects.md).
- Have the project start automatically when the workspace starts: [Running things on workspace start](../workspaces/lifecycle.md#running-things-automatically-on-start).
- Show it to someone: [Sharing your site](sharing.md).
