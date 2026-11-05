# Multiple Projects

A freeform workspace can run several DDEV projects at once. Each project gets its own URL and app buttons, and they can all be running at the same time.

## How it works

Every project's site is served through DDEV's router inside the workspace. Coder sends each request to the router with the original hostname, and the router passes it to the right project based on that hostname. `ddev coder-setup` installs a hook so that every `ddev start` writes the routing rules for that project.

Each project's URLs follow the same pattern:

| What        | URL                                                                |
| ----------- | ------------------------------------------------------------------ |
| Site        | `https://<project>--<workspace>--<username>.coder.ddev.com`         |
| Mailpit     | `https://mailpit-<project>--<workspace>--<username>.coder.ddev.com` |
| xhgui       | `https://xhgui-<project>--<workspace>--<username>.coder.ddev.com`   |

For example, the project `blog` in workspace `agency` owned by `jdoe` is at `https://blog--agency--jdoe.coder.ddev.com`.

## Add a project

1. **Register the name.** On the workspace page, open **Settings → Parameters** and add the name to **DDEV project names**, for example change `shop` to `shop,blog`. Save, then restart the workspace when prompted. This creates the new app buttons.
2. **Set up the project** in the workspace:

    ```bash
    git clone git@github.com:your-org/blog.git ~/blog
    cd ~/blog
    ddev config --project-name=blog
    ddev coder-setup
    ddev start
    ```

3. Click the new **blog** app button, or run `ddev launch`.

!!! tip "Register all the names up front"
    Restarting the workspace stops your running DDEV projects. If you know you'll want several projects, list them all when you create the workspace. Listing a name you don't use yet does no harm; its button just shows an error until that project is running.

## Remove a project

```bash
cd ~/blog
ddev delete --omit-snapshot   # removes the project's containers and database
```

Then remove its name from **DDEV project names** and restart the workspace to remove its buttons. Delete the directory too if you no longer need the code.

## Working with several projects

```bash
ddev list                 # all projects and their status
ddev start --all          # start every project
ddev stop blog            # stop one project from anywhere
ddev poweroff             # stop everything
```

All projects share the workspace's CPU, memory and disk. If the workspace feels slow, stop projects you aren't using. See [Workspace lifecycle](../workspaces/lifecycle.md#disk-space).

## Projects with several hostnames

DDEV's `additional_hostnames` and `additional_fqdns` (used for example by Drupal multisite or WordPress multisite) don't get their own workspace URLs. Each project has exactly one site URL per registered name. For multisite development, give each site its own DDEV project, or switch sites by path rather than hostname.
