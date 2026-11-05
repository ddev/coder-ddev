# Getting Started

DDEV Coder Workspaces are cloud development environments hosted at [coder.ddev.com](https://coder.ddev.com). They are built on [Coder](https://coder.com), an open-source platform for remote development environments, and they run [DDEV](https://ddev.com) inside each workspace.

## How it works

1. **[Get access](access.md)** and sign in to coder.ddev.com with your GitHub account.
2. **[Choose a template](choosing-a-template.md)**: Drupal issue, Drupal core or freeform.
3. **Create a workspace.** It's ready in about a minute.
4. **Open it** with the app buttons on the workspace page: **VS Code** for the editor and terminal, and one button for each DDEV site.

## What's in a workspace

- **Docker and DDEV.** Each workspace runs its own Docker daemon, so DDEV works the same way it does on your own computer.
- **VS Code for Web**, opened in your project directory, with a terminal.
- **Git and SSH.** Coder gives each account an SSH key that Git in the workspace uses automatically. Add it to GitHub, GitLab or drupal.org and you can clone and push.
- **Node.js, Composer (through DDEV), Homebrew** and common command-line tools.
- **Passwordless `sudo`**, so you can install anything else you need.
- **Persistent storage.** Your home directory, Docker images and Homebrew packages survive stopping and starting the workspace. See [Workspace lifecycle](../workspaces/lifecycle.md).

## What you need

- A web browser. Everything else is optional.
- A GitHub account that has access. See [Getting access](access.md).
- Optional: the [Coder CLI](https://coder.com/docs/install/cli) if you want to use SSH, `scp` or desktop editors. See [Editors, SSH and files](../workspaces/editors-and-ssh.md).

## Next steps

- New to all of this? Follow [Your first workspace](first-workspace.md).
- Bringing your own project? Go straight to [Freeform workspaces](../freeform/index.md).
- Contributing to Drupal? Use the [Drupal quickstart](../drupal/quickstart.md).
