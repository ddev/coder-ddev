# Getting Access

coder.ddev.com is a service of the [DDEV Foundation](https://ddev.com). You sign in with GitHub, and access is limited to members of certain GitHub organizations.

## Who has access

You can use coder.ddev.com if your GitHub account is a member of one of these:

- An organization that [sponsors DDEV](https://ddev.com/support-ddev/) at the $100/month level or above.
- The [`ddev`](https://github.com/ddev) organization.
- The [`coder-ddev-com`](https://github.com/coder-ddev-com) organization, which is how individual contributors get access.

Your membership doesn't have to be public. When you first sign in, GitHub asks you to let coder.ddev.com read your organization memberships (the `read:org` permission); private membership is enough.

!!! tip "Refused even though your organization sponsors DDEV?"
    New sponsor organizations are added to the allow list by the DDEV team, so there can be a short delay. Make sure you have accepted your organization invitation on GitHub. If it still fails, [open an issue](https://github.com/ddev/coder-ddev/issues) or ask in the [DDEV Discord](https://ddev.com/s/discord).

## Request access as an individual

If you don't belong to a sponsoring organization, [open an access request](https://github.com/coder-ddev-com/access-requests/issues/new?template=access-request.yml). Tell us briefly what you want to work on. Once it is approved, you are invited to the `coder-ddev-com` organization. Accept the invitation from GitHub's email or from [github.com/orgs/coder-ddev-com/invitation](https://github.com/orgs/coder-ddev-com/invitation), then sign in.

## Sign in

1. Go to [coder.ddev.com/login](https://coder.ddev.com/login).
2. Choose **Sign in with GitHub** and approve the app.
3. You arrive at your **Workspaces** page. It's empty until you create your first workspace.

If you see an "access denied" page, your GitHub account isn't in one of the organizations above yet.

## Use the CLI (optional)

The [Coder CLI](https://coder.com/docs/install/cli) lets you SSH into workspaces, copy files, and connect desktop editors.

```bash
coder login https://coder.ddev.com
```

This opens your browser to approve the login. See [Editors, SSH and files](../workspaces/editors-and-ssh.md) for what you can do next.
