# Your First Workspace

This walkthrough takes about five minutes. You create a freeform workspace, start a small PHP site in it with DDEV, open it in your browser, and stop the workspace. You only need a browser and a GitHub account with [access](access.md).

## 1. Create the workspace

1. Sign in at [coder.ddev.com](https://coder.ddev.com/login) with GitHub.
2. Open the [freeform template](https://coder.ddev.com/templates/coder/freeform/workspace?mode=manual).
3. Name the workspace `hello`. Leave **DDEV project names** empty, so the workspace has one project, also named `hello`.
4. Click **Create workspace**.

The workspace page shows the startup log. When the workspace is ready, usually in about a minute, the app buttons become active: **VS Code**, **hello**, **Mailpit (hello)** and **xhgui (hello)**.

## 2. Open VS Code

Click **VS Code**. It opens in your browser. Open a terminal with **Terminal → New Terminal** from the menu (☰).

Check that everything is there:

```bash
ddev version
docker ps
```

## 3. Start a site

Paste this into the terminal:

```bash
mkdir -p ~/hello/public && cd ~/hello
echo '<?php echo "Hello from coder.ddev.com"; phpinfo();' > public/index.php
ddev config --project-name=hello --project-type=php --docroot=public
ddev coder-setup
ddev start
```

`ddev coder-setup` connects the project to the workspace's routing; every freeform project needs it once.

## 4. Open the site

Click the **hello** button on the workspace page, or run `ddev launch` in the terminal and open the URL it prints. The address looks like `https://hello--hello--<your-username>.coder.ddev.com`. Only you can open it, unless you turn on [public sharing](../freeform/sharing.md).

Edit `public/index.php` in VS Code and reload the page to see the change.

## 5. Stop the workspace

When you're done, click **Stop** on the workspace page. Your files and database are kept; click **Start** to continue later, then run `ddev start` in the project again.

Workspaces that go unused are deleted after a warning email. See [Workspace lifecycle](../workspaces/lifecycle.md) for what persists and for how long.

## Next steps

- Bring your own project, or run several: [Freeform workspaces](../freeform/index.md).
- Work on a Drupal issue instead: [Drupal quickstart](../drupal/quickstart.md).
- Use SSH, `scp` or desktop editors from your computer: [Using the Coder CLI](../workspaces/coder-cli.md).
- Let Claude Code work in the workspace: [Claude Code](../workspaces/ai-tools.md).
