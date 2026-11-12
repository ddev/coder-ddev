# Troubleshooting

## I can't sign in

See [Getting access](../getting-started/access.md). An "access denied" page means your GitHub account isn't in an organization that has access yet.

## The workspace won't start

Open the workspace page and read the build and startup logs. If the build failed, try **Restart**. If it keeps failing, [open an issue](https://github.com/ddev/coder-ddev/issues) with the log output.

## My site's app button shows an error

Work through these in order:

1. **Is the project running?** Run `ddev list`. If not, `ddev start` in the project directory.
2. **Did you run `ddev coder-setup`?** Without it, the workspace has no route to the project. Run it once in the project directory, then `ddev restart`.
3. **Does the name match?** The DDEV project name (`ddev describe` shows it) must be one of the workspace's **DDEV project names**, exactly. `ddev coder-setup` prints a warning when it isn't. Either rename the project (`ddev config --project-name=...`, then `ddev restart`) or add the name to the workspace's settings and restart the workspace.
4. **Did you just add the name?** New app buttons appear only after the workspace restarts.

## `ddev describe` shows `*.ddev.site` URLs

Those URLs only work inside the workspace. Run `ddev coder-setup` in the project and restart it; `ddev start`, `ddev describe`, `ddev list` and `ddev launch` then show the `coder.ddev.com` URLs, including those of add-ons and `web_extra_exposed_ports`. `ddev coder-setup` writes them as `external_url_template` and `external_urls` in `.ddev/config.coder.yaml`. With a DDEV version older than the one that added those settings, only `ddev describe` and `ddev launch` show `coder.ddev.com` URLs, and a newly added add-on's URL appears in `ddev describe` after one more `ddev restart`.

## The site redirects to `*.ddev.site` or `http://`

The application has its own idea of its URL, often stored in its database or configuration. Set its base URL to the one `ddev launch` shows, with `https://`. WordPress is the usual case; see the [WordPress recipe](../freeform/recipes.md#wordpress).

## Docker or DDEV doesn't respond

```bash
docker ps                    # does Docker answer?
tail -50 /tmp/dockerd.log    # Docker daemon log
```

If Docker isn't running, restart the workspace. If DDEV containers fail to start, try `ddev poweroff` and then `ddev start`.

## The disk is full

See [Disk space](lifecycle.md#disk-space).

## Git asks for a password or is refused

Add your Coder SSH key to your Git host (see [Git and SSH keys](editors-and-ssh.md#git-and-ssh-keys)) and use the `git@...` SSH clone URL rather than the `https://` one.

## Still stuck?

Ask in the [DDEV Discord](https://ddev.com/s/discord) or **#ddev** on Drupal Slack, or [open an issue](https://github.com/ddev/coder-ddev/issues). Include the workspace name, what you ran, and the full error message.
