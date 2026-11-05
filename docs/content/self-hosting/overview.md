# Self-Hosting

The rest of these docs describe the hosted service at coder.ddev.com. This section is for people who run the coder-ddev templates on their own [Coder](https://coder.com) server, and for the people who operate coder.ddev.com.

## What you run

- A **Coder server** (v2.13 or later) with a wildcard domain for workspace app URLs.
- One or more **Docker hosts with [Sysbox](https://github.com/nestybox/sysbox)**, so each workspace can run its own Docker daemon without privileged containers.
- The **workspace image** built from [`image/Dockerfile`](https://github.com/ddev/coder-ddev/tree/main/image) (published as `ddev/coder-ddev` on Docker Hub).
- One or more of the **templates** in the repository: [`freeform`](https://github.com/ddev/coder-ddev/tree/main/freeform), [`drupal-core`](https://github.com/ddev/coder-ddev/tree/main/drupal-core) and [`drupal-contrib`](https://github.com/ddev/coder-ddev/tree/main/drupal-contrib).

```text
Coder server ── authentication, templates, workspace orchestration
     │
     ▼
Docker host (sysbox-runc)
  └─ workspace container (one per workspace)
       ├─ Docker daemon ── DDEV containers (web, db, router, add-ons)
       ├─ VS Code for Web, Coder agent
       └─ /home/coder (persistent)
```

## Guides

- [Server setup](server-setup.md): installing Docker, Sysbox and Coder on a fresh server, and adding capacity.
- [Operations](operations-guide.md): building the image, pushing templates, versions, and workspace lifecycle cleanup.
- [User management](user-management.md): accounts, roles, GitHub organization access, tokens and quotas.
- [Troubleshooting](troubleshooting.md): server-side problems, debugging tools and recovery.

## Template variables

Settings that users can't change are template variables, set when the template is pushed (see the `Makefile`):

| Variable                   | Default                           | Description                                                                         |
| -------------------------- | --------------------------------- | ----------------------------------------------------------------------------------- |
| `workspace_image_registry` | `index.docker.io/ddev/coder-ddev` | Registry and repository of the workspace image                                      |
| `image_version`            | `v0.1`                            | Image tag; the Makefile passes the contents of the root `VERSION` file              |
| `cpu`                      | `4`                               | CPU shares for each workspace                                                       |
| `memory`                   | `8`                               | Memory limit in GB for each workspace                                               |
| `docker_gid`               | `988`                             | GID of the `docker` group                                                           |
| `docker_registry_mirror`   | (auto-detect)                     | Docker registry mirror for the workspaces' Docker daemons                           |
| `enable_adminer`           | `false`                           | `freeform` only: add an **Adminer** app button for each project                      |

## Contributing

Developer and contributor guidance, including for AI agents, lives in the repository's [`AGENTS.md`](https://github.com/ddev/coder-ddev/blob/main/AGENTS.md). Changes are welcome as pull requests to [ddev/coder-ddev](https://github.com/ddev/coder-ddev).
