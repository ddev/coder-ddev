# User Management Guide

This guide covers user account management, permissions, and access control for the DDEV Coder template.

## Overview

Coder uses a role-based access control (RBAC) system to manage users and their permissions. This guide focuses on template-specific considerations for the DDEV environment.

## User Accounts

### Creating User Accounts

**Via Web UI:**
1. Log into Coder as admin
2. Navigate to **Users** section
3. Click **Create User**
4. Enter username, email, password
5. Assign roles (see Roles section below)
6. Click **Create**

**Via CLI:**
```bash
# Create user
coder users create <username>

# Create user with email
coder users create <username> --email user@example.com

# Set password (user will be prompted)
coder users create <username> --set-password
```

### User Roles

Coder has three built-in roles:

| Role | Permissions | Use Case |
|------|-------------|----------|
| **Owner** | Full system access, manage all workspaces, templates, users | System administrators |
| **Template Admin** | Create/edit templates, manage own workspaces | DevOps, platform team |
| **Member** | Create/manage own workspaces from allowed templates | Developers, users |

**Assigning roles:**
```bash
# Set user roles
coder users edit-roles <username> --roles template-admin

# Set to member (default)
coder users edit-roles <username> --roles member
```

### Template Access

By default, all users can access all templates.

**Organization-based access:**
- Create separate organizations for different teams
- Deploy templates per organization
- Users only see templates in their organization

### User Provisioning

**For organizations with SSO/OIDC:**

Coder supports automatic user provisioning via:
- GitHub OAuth
- Google Workspace
- Okta
- OIDC providers

Users are created on first login and assigned default role (Member).

See [Coder Authentication Docs](https://coder.com/docs/admin/auth) for setup.

## Organizations

Organizations provide multi-tenancy and resource isolation.

### Creating Organizations

```bash
# Create organization
coder organizations create <org-name>

# List organizations
coder organizations list

# Add user to organization
coder organizations members add <org-name> <username>
```

### Template Deployment per Organization

```bash
# Deploy template to specific organization
coder templates push \
  --directory ddev-user \
  --organization <org-name> \
  ddev-user \
  --yes

# Users can only create workspaces from templates in their organization
```

### Use Cases for Organizations

- **Multi-team environments**: Separate orgs for backend, frontend, QA teams
- **Client isolation**: Separate org per client/project
- **Resource quotas**: Set per-org limits on workspace count, resources
- **Billing separation**: Track usage per organization

## SSH Key Management

Users need SSH keys for Git operations inside workspaces.

### User SSH Keys

**Users can add their own keys:**

1. Log into Coder UI
2. Go to **Account** → **SSH Keys**
3. Add public key
4. SSH key is automatically available in all workspaces

**Or via CLI:**
```bash
# Add SSH key
coder publickey add ~/.ssh/id_rsa.pub

# List keys
coder publickey list

# Remove key
coder publickey remove <key-id>
```

### Git SSH Configuration

The DDEV template automatically configures Git SSH via Coder's GitSSH wrapper:

```bash
# In workspace startup script (ddev-user/scripts/startup.sh):
git config --global core.sshCommand "$GIT_SSH_COMMAND"
```

Users can clone repositories using SSH:
```bash
git clone git@github.com:user/repo.git
```

### SSH Access to Workspaces

**Users can SSH into their workspaces:**
```bash
# SSH into workspace
coder ssh my-workspace

# Run command via SSH
coder ssh my-workspace -- ddev describe

# Port forwarding via SSH
coder ssh my-workspace --forward 8080:localhost:8080
```

**Generate SSH config:**
```bash
# Add workspaces to ~/.ssh/config
coder config-ssh

# Then SSH directly
ssh coder.my-workspace
```

## API Tokens

Users need API tokens for CLI access and automation.

### Creating Tokens

**Via Web UI:**
1. Log into Coder
2. Go to **Account** → **Tokens**
3. Click **Create Token**
4. Set expiration (optional)
5. Copy token (shown once)

**Via CLI:**
```bash
# Create token
coder tokens create <token-name>

# List tokens
coder tokens list

# Revoke token
coder tokens revoke <token-id>
```

### Using Tokens

```bash
# Login with token
coder login <coder-url> --token <token>

# Or set environment variable
export CODER_SESSION_TOKEN=<token>
coder list
```

### Token Scopes

Tokens inherit user's role permissions:
- **Member tokens**: Can create/manage own workspaces
- **Admin tokens**: Can manage templates, users, all workspaces

**Security best practices:**
- Set short expiration for automation tokens (30-90 days)
- Use separate tokens per service/CI system
- Rotate tokens regularly
- Revoke unused tokens

## Workspace Permissions

### Ownership

- Users **own** the workspaces they create
- Only the owner (and admins) can:
  - Stop/start workspace
  - Delete workspace
  - SSH into workspace
  - View workspace logs

### Sharing Workspaces

Coder does not support workspace sharing out-of-the-box.

**Workarounds for collaboration:**

**Option 1: VS Code Live Share**
- Install Live Share extension in workspace
- Share session link with team members
- Collaborators need VS Code (desktop or web)

**Option 2: Port Forwarding**
- Expose DDEV project via Coder port forwarding
- Share access URL with team members
- Requires workspace to be running

**Option 3: Shared Workspaces (Manual)**
- Create workspace for shared access
- Share credentials with team (not recommended for production)

**Option 4: Project handoff**
- Commit code to Git repository
- Other user creates their own workspace
- Clone the shared repository

## Resource Quotas

### Workspace Limits

**Template-level defaults:**

Edit `ddev-user/template.tf`:
```hcl
variable "cpu" {
  default     = 4
  validation {
    condition     = var.cpu <= 8
    error_message = "CPU must be 8 or less"
  }
}

variable "memory" {
  default     = 8
  validation {
    condition     = var.memory <= 16
    error_message = "Memory must be 16GB or less"
  }
}
```

### Storage Quotas

**Host-level disk quotas:**

Each workspace uses:
- Home directory: `/home/coder/workspaces/<owner>-<workspace>`
- Docker volume: `coder-<owner>-<workspace>-dind-cache`

**Set filesystem quotas (Linux):**
```bash
# Enable quotas on host filesystem
apt-get install quota
mount -o remount,usrquota,grpquota /home

# Set quota for workspace directories
setquota -u coder 50G 60G 0 0 /home
```

**Monitor disk usage:**
```bash
# Check workspace home directories
du -sh /home/coder/workspaces/*

# Check Docker volumes
docker system df -v | grep coder
```

## Audit and Monitoring

### User Activity

**View workspace activity:**
```bash
# List all workspaces with owners
coder list --all

# Show workspace details
coder show <workspace-name>

# View workspace logs
coder logs <workspace-name>
```

### Resource Usage

**Per-workspace metrics:**
```bash
# Check running workspaces
coder list --all

# SSH into workspace and check resources
coder ssh <workspace> -- docker stats
coder ssh <workspace> -- df -h
```

**Host-level monitoring:**
```bash
# Check all workspace containers
docker ps | grep coder

# Check resource usage
docker stats $(docker ps --filter "name=coder" -q)

# Check disk usage
df -h /home/coder/workspaces/
docker system df
```

## User Offboarding

### Removing Users

```bash
# 1. List user's workspaces
coder list --user <username>

# 2. Delete all user workspaces
coder delete <workspace1> <workspace2> --yes

# 3. Remove user account
coder users delete <username>

# 4. Revoke user tokens
coder tokens list --user <username>
coder tokens revoke <token-id>
```

### Data Retention

When deleting a user:
- Workspaces are **not** automatically deleted
- Admins must manually delete user workspaces
- Workspace data is removed on deletion (home directory + Docker volume)

**Backup before deletion:**
```bash
# Backup user workspace data
tar -czf user-backup.tar.gz /home/coder/workspaces/<username>-*

# Backup Docker volumes
docker volume ls | grep coder-<username>
```

## Access Control Best Practices

### User Provisioning

1. **Use SSO/OIDC** for enterprise environments
2. **Create users via CLI/API** for automation
3. **Assign appropriate roles** based on responsibility
4. **Set password policies** (expiration, complexity)

### Template Access

1. **Restrict sensitive templates** to specific groups
2. **Use organizations** for multi-team isolation
3. **Version templates** for stability (don't auto-update)

### Security

1. **Enable 2FA** for admin accounts
2. **Rotate API tokens** regularly
3. **Monitor workspace activity** for suspicious behavior
4. **Set resource quotas** to prevent abuse
5. **Review user permissions** quarterly

### Onboarding Checklist

For new users:
- [ ] Create user account (or SSO enabled)
- [ ] Assign role (Member by default)
- [ ] Add to organization (if applicable)
- [ ] User installs Coder CLI
- [ ] User creates first workspace
- [ ] Verify workspace access (VS Code Web, SSH)
- [ ] User gets Coder public key (`coder publickey`) and adds to Git host
- [ ] User creates API token (if needed for automation)

### Offboarding Checklist

For departing users:
- [ ] List all user workspaces
- [ ] Backup workspace data (if needed)
- [ ] Delete all workspaces
- [ ] Revoke API tokens
- [ ] Remove Coder public key from Git hosts (GitHub/GitLab/etc)
- [ ] Delete user account
- [ ] Remove from organization
- [ ] Document handoff (if project needs continuation)

## Troubleshooting

### User Can't Create Workspace

**Check:**
- User has "Member" role or higher
- Template is deployed to user's organization
- Template is not restricted to specific users/groups
- User has not exceeded workspace quota

```bash
# Verify user role
coder users show <username>

# Check template access
coder templates list --organization <org>
```

### User Can't SSH into Workspace

**Check:**
- Workspace is running: `coder list`
- User owns workspace (or is admin)
- Coder CLI is authenticated: `coder login <url>`
- SSH key added to Coder account

```bash
# Test SSH
coder ssh <workspace> -- echo "SSH works"

# Check workspace status
coder show <workspace>
```

### Git SSH Not Working

**Check:**
- User has SSH key added to Coder account
- Git host (GitHub, GitLab) has user's public key
- `GIT_SSH_COMMAND` is set in workspace: `echo $GIT_SSH_COMMAND`

```bash
# Test Git SSH
coder ssh my-workspace -- git clone git@github.com:user/repo.git

# Check GitSSH wrapper
coder ssh my-workspace -- which coder
coder ssh my-workspace -- coder gitssh --help
```

### Permission Denied Errors

**Check:**
- User role and permissions: `coder users show <username>`
- Template access restrictions: `coder templates show ddev-user`
- Organization membership: `coder organizations members list <org>`

```bash
# Check user details
coder users show <username>

# Check template permissions (if using Coder Enterprise)
coder templates show ddev-user --json | grep -i allow
```

## Additional Resources

- [Operations Guide](./operations-guide.md) - Template deployment and management
- [Troubleshooting Guide](./troubleshooting.md) - Debugging workspace issues
- [Coder User Management](https://coder.com/docs/admin/users) - Official docs
- [Coder RBAC](https://coder.com/docs/admin/rbac) - Role-based access control
- [Coder Organizations](https://coder.com/docs/admin/organizations) - Multi-tenancy setup
