# DDEV Coder Template Documentation

Welcome to the DDEV Coder template documentation. This guide helps you deploy, manage, and use cloud-based DDEV development environments.

## Quick Links

- **[Project README](../README.md)** - Quick start and overview
- **[Developer Guide (CLAUDE.md)](../CLAUDE.md)** - For contributors and AI-assisted development
- **[Image Build Instructions](../image/README.md)** - Docker image details

## Documentation by Audience

### For Administrators

System administrators and DevOps teams managing Coder infrastructure and the DDEV template.

- **[Server Setup Guide](./admin/server-setup.md)** - Fresh server installation: Docker, Sysbox, Coder server, adding capacity
- **[Operations Guide](./admin/operations-guide.md)** - Template deployment, Docker image builds, version management, workspace lifecycle
- **[User Management Guide](./admin/user-management.md)** - User accounts, roles, permissions, SSH keys, API tokens, resource quotas
- **[Troubleshooting Guide](./admin/troubleshooting.md)** - Common issues, debugging tools, error messages, emergency recovery

**New installation:** [Server Setup Guide](./admin/server-setup.md)
**Ongoing operations:** [Operations Guide](./admin/operations-guide.md)

### For Users

Developers and users creating and working with DDEV workspaces.

- **[Getting Started Guide](./user/getting-started.md)** - First-time setup, creating your first workspace, basic verification
- **[Using Workspaces](./user/using-workspaces.md)** - Daily workflows, VS Code for Web, DDEV projects, Git, port forwarding

**Start here:** [Getting Started Guide](./user/getting-started.md)

### For DDEV Experts

For teams evaluating this template or users familiar with local DDEV.

- **[Comparison to Local DDEV](./architecture/comparison-to-local.md)** - Architecture differences, feature parity, benefits, tradeoffs, migration

**Start here:** [Comparison to Local DDEV](./architecture/comparison-to-local.md)

## What is This?

The DDEV Coder template provides cloud-based development environments with full DDEV support:

- **Docker-in-Docker** - Each workspace has isolated Docker daemon (via Sysbox runtime)
- **DDEV pre-installed** - Ready to run PHP, Node.js, Python projects
- **VS Code for Web** - Browser-based IDE with full extension support
- **Persistent storage** - Home directory and Docker volumes preserved across sessions
- **Port forwarding** - Access DDEV projects via Coder's secure proxy

### Key Technologies

- **Coder v2+** - Open-source infrastructure for creating remote development environments
- **Sysbox** - Secure nested containers without privileged mode
- **DDEV** - Local development tool for PHP/Node/Python (supports 20+ project types)
- **Ubuntu 24.04** - Base container OS
- **Terraform** - Infrastructure as Code for template definition

## Use Cases

### Team Development

- **Consistent environments** - Everyone uses the same versions, tools, configuration
- **Fast onboarding** - New developers get working environment in minutes
- **No local setup** - No Docker Desktop, no dependency conflicts

### Remote Work

- **Access anywhere** - Work from any device with a browser
- **Cloud resources** - Use powerful cloud machines for heavy workloads
- **Persistent state** - Stop/start workspaces without losing work

### Education and Training

- **Pre-configured environments** - Students don't need to install tools
- **Isolated workspaces** - Each student has separate environment
- **Easy reset** - Instructor can recreate clean environments

## Architecture Overview

```
┌─────────────────────────────────────────┐
│ Coder Server (Management Plane)        │
│ - User authentication                   │
│ - Template management                   │
│ - Workspace orchestration               │
└─────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ Coder Agent Node (Workspaces)          │
│ ┌─────────────────────────────────────┐ │
│ │ Workspace Container (Sysbox)        │ │
│ │ ┌─────────────────────────────────┐ │ │
│ │ │ Docker Daemon (inside)          │ │ │
│ │ │ ┌─────────────────────────────┐ │ │ │
│ │ │ │ DDEV Containers             │ │ │ │
│ │ │ │ - Web (PHP/Node/Python)     │ │ │ │
│ │ │ │ - Database (MySQL/Postgres) │ │ │ │
│ │ │ │ - Additional services       │ │ │ │
│ │ │ └─────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────┘ │ │
│ │ /home/coder (persistent volume)     │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Key points:**
- Each workspace is an isolated container with its own Docker daemon
- DDEV runs inside the workspace using the nested Docker daemon
- Sysbox provides security without `--privileged` mode
- VS Code for Web connects directly to workspace via Coder agent

## Feature Highlights

### What's Included

✅ **Docker and Docker Compose** - Full Docker CLI and daemon
✅ **DDEV** - Latest stable version with all features
✅ **Node.js LTS** - Version 24.x pre-installed
✅ **VS Code for Web** - Official Coder module with extension support
✅ **Git with SSH** - GitSSH integration for seamless cloning
✅ **System tools** - curl, wget, vim, build-essential, bash-completion
✅ **Passwordless sudo** - Full system access within workspace

### What's NOT Included

❌ **Local Docker Desktop** - Replaced by Docker-in-Docker
❌ **Local DDEV** - Runs in cloud workspace instead
❌ **Direct port binding** - Use Coder's port forwarding
❌ **Host network access** - Isolated workspace networking

### Supported Project Types

DDEV supports 20+ project types out of the box:

- **PHP**: Drupal, WordPress, Laravel, Symfony, Magento, Typo3, Craft CMS, Backdrop
- **Node.js**: Any framework (Next.js, Express, Gatsby, etc.)
- **Python**: Django, Flask, any Python web app
- **Static sites**: HTML, Jekyll, Hugo
- **Generic**: Custom PHP, Go, Rust, and more

## Documentation Conventions

### Command Prompts

```bash
# Commands run on your local machine
coder login https://coder.example.com

# Commands run inside workspace (after 'coder ssh workspace')
ddev start
```

### File Paths

- **Host paths**: `/home/coder/workspaces/<owner>-<workspace>`
- **Workspace paths**: `/home/coder` (inside container)
- **Template paths**: `ddev-user/template.tf` (in this repository)

### Variables

- `<workspace-name>` - Name of your workspace (e.g., `my-project`)
- `<owner>` - Username of workspace owner
- `<org>` - Coder organization name
- `<version>` - Docker image version (e.g., `v0.1`)

## Getting Help

### Community Resources

- **GitHub Issues**: [Report bugs or request features](https://github.com/ddev/coder-ddev/issues)
- **DDEV Documentation**: [Official DDEV docs](https://docs.ddev.com/)
- **Coder Documentation**: [Official Coder docs](https://coder.com/docs)
- **Coder Discord**: [Community chat](https://discord.gg/coder)

### Before Asking for Help

1. Check the [Troubleshooting Guide](./admin/troubleshooting.md)
2. Search [existing GitHub issues](https://github.com/ddev/coder-ddev/issues)
3. Review [DDEV troubleshooting docs](https://docs.ddev.com/users/usage/troubleshooting/)

### Reporting Issues

Include:
- Workspace logs: `coder logs <workspace>`
- Template version: `cat VERSION`
- Coder version: `coder version`
- DDEV version: `coder ssh <workspace> -- ddev version`
- Full error messages

## Contributing

This is an open-source project. Contributions welcome!

- **Report bugs**: [GitHub Issues](https://github.com/ddev/coder-ddev/issues)
- **Contribute code**: Fork, branch, submit PR
- **Documentation**: Suggest improvements or add examples
- **AI-assisted development**: See [CLAUDE.md](../CLAUDE.md) for AI workflow

## License

See [LICENSE](../LICENSE) file for details.

## Version

Current version: See [VERSION](../VERSION) file.

## Next Steps

### For Administrators
1. Read [Server Setup Guide](./admin/server-setup.md) (new installations)
2. Read [Operations Guide](./admin/operations-guide.md)
3. Build Docker image and deploy template
4. Create test workspace

### For Users
1. Read [Getting Started Guide](./user/getting-started.md)
2. Install Coder CLI
3. Create your first workspace
4. Start a DDEV project

### For DDEV Experts
1. Read [Comparison to Local DDEV](./architecture/comparison-to-local.md)
2. Understand architecture differences
3. Evaluate for your team
4. Plan migration strategy
