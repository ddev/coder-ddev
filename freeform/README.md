# Freeform DDEV Template

Coder workspace template for running one or more DDEV projects in a single workspace. Each listed project gets its own subdomain URL and app buttons (site, Mailpit, xhgui); ddev-router (Traefik) inside the workspace dispatches requests by Host header.

**User documentation:** [docs.coder.ddev.com/freeform](https://docs.coder.ddev.com/freeform/) (source: [`docs/content/freeform/`](../docs/content/freeform/)). Keep user-facing explanations there rather than in this file.

## Quick start

```bash
# In a workspace whose "DDEV project names" includes my-site
git clone git@github.com:your-org/my-site.git ~/my-site
cd ~/my-site
ddev config --project-name=my-site
ddev coder-setup     # once per project: installs the routing post-start hook
ddev start
ddev launch          # prints the project's Coder URLs
```

## How it fits together

| Piece                                   | Where                                                                                       |
| --------------------------------------- | ------------------------------------------------------------------------------------------- |
| Per-project `coder_app`s                | `template.tf`: `ddev_web`, `mailpit`, `xhgui`, `adminer` (all `for_each` over `project_names`) |
| Router port and global DDEV config      | `template.tf` startup script (`ddev config global --router-http-port=8080`)                |
| `ddev coder-setup`, `ddev coder-routes` | `image/scripts/.ddev/commands/host/`                                                        |
| `ddev launch` override                  | `image/scripts/.ddev/commands/host/launch`                                                  |
| Integration tests                       | `scripts/test-freeform-*.sh`, run by `.github/workflows/integration-test.yml`              |

URLs follow `https://<project>--<workspace>--<owner>.<coder-domain>` for the site and `mailpit-<project>--…`, `xhgui-<project>--…` for the tools. `ddev coder-routes` (run after every `ddev start` by the hook) reads `~/.ddev/traefik/config/<project>_merged.yaml` and writes `~/.ddev/traefik/custom-global-config/coder-routes-<project>.yaml`.

## Parameters and variables

User-facing parameters (`project_names`, `share_projects`, `vscode_extensions`, and the Claude Code options from the shared modules) are documented in [Creating a freeform workspace](https://docs.coder.ddev.com/freeform/create/). Admin-only template variables (`cpu`, `memory`, `enable_adminer`, registry settings) are listed in [Self-Hosting](https://docs.coder.ddev.com/self-hosting/overview/).
