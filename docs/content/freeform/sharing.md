# Sharing Your Site

By default, only you can open your workspace's sites. Anyone else who opens the link is asked to sign in to coder.ddev.com and is then refused.

## Make your sites public

1. On the workspace page, open **Settings → Parameters**.
2. Turn on **Public Sharing** and save.
3. Restart the workspace. The change takes effect on the next start.

Now anyone with a project's site URL can open it without signing in. Send them the URL that `ddev launch` shows.

- Public Sharing applies to **every** project listed in **DDEV project names**; you can't share just one.
- **Mailpit and xhgui always stay private**, as do VS Code and the terminal. Other forwarded ports stay private unless you share them yourself from the workspace's **Open ports** menu.
- To stop sharing, turn the switch off and restart the workspace again.

!!! warning "Public means public"
    Anyone who gets the URL can open the site while it is running, including search engines and bots if the link is posted somewhere. Don't share sites that contain real customer data, and use the site's own login for anything that needs protection.

## Sharing the workspace itself

To let a teammate use your workspace (VS Code, terminal and private sites), share it with another coder.ddev.com user. On the workspace page, click **Share**, or use the CLI:

```bash
coder sharing add my-workspace --user their-username:use    # role: use or admin
coder sharing status my-workspace
coder sharing remove my-workspace --user their-username
```

They then see the workspace in their own Coder dashboard. See [Coder's shared workspaces documentation](https://coder.com/docs/user-guides/shared-workspaces) for what each role allows.
