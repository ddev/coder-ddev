# Comparison to Local DDEV

This guide is for teams and developers familiar with local DDEV who are evaluating this Coder template or planning migration.

## Executive Summary

**Local DDEV:**
- Runs on your laptop/desktop
- Uses local Docker Desktop or Docker Engine
- Direct filesystem access
- Local port binding (*.ddev.site domains)
- No authentication, single user

**DDEV in Coder:**
- Runs in cloud workspace (remote container)
- Uses Docker-in-Docker via Sysbox runtime
- Remote filesystem (persistent volumes)
- Port forwarding via Coder proxy
- Multi-user, authenticated, team-managed

## Architecture Comparison

### Local DDEV Architecture

```
┌─────────────────────────────────┐
│ Your Local Machine              │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ Docker Desktop / Engine     │ │
│ │ ┌─────────────────────────┐ │ │
│ │ │ DDEV Containers         │ │ │
│ │ │ - Web (PHP/Node)        │ │ │
│ │ │ - Database              │ │ │
│ │ │ - Router (*.ddev.site)  │ │ │
│ │ └─────────────────────────┘ │ │
│ └─────────────────────────────┘ │
│                                 │
│ Local filesystem                │
│ ~/projects/my-site/             │
└─────────────────────────────────┘
```

**Key points:**
- DDEV talks directly to local Docker
- Project files on local filesystem
- `*.ddev.site` domains via ddev-router
- No network latency

### DDEV in Coder Architecture

```
┌─────────────────────────────────────────┐
│ Coder Workspace (Cloud Container)      │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Docker Daemon (Sysbox)              │ │
│ │ ┌─────────────────────────────────┐ │ │
│ │ │ DDEV Containers                 │ │ │
│ │ │ - Web (PHP/Node)                │ │ │
│ │ │ - Database                      │ │ │
│ │ │ (No router, port forward)       │ │ │
│ │ └─────────────────────────────────┘ │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ /home/coder/ (persistent volume)       │
│ └── projects/my-site/                  │
└─────────────────────────────────────────┘
         │
         ▼ (Coder proxy)
┌─────────────────────────────────────────┐
│ Your Browser                            │
│ - VS Code for Web                       │
│ - Forwarded ports (HTTP/HTTPS)          │
└─────────────────────────────────────────┘
```

**Key differences:**
- Nested Docker (Docker-in-Docker via Sysbox)
- Remote filesystem (persistent across sessions)
- Port forwarding instead of *.ddev.site
- Network latency for file operations

## Detailed Differences

### 1. Docker Runtime

**Local DDEV:**
- Uses Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- DDEV talks to Docker socket: `/var/run/docker.sock`
- Privileged operations allowed

**Coder DDEV:**
- Uses Docker-in-Docker via Sysbox runtime
- Each workspace has isolated Docker daemon
- Sysbox provides security without `--privileged`
- Docker data in dedicated volume: `/var/lib/docker`

**Implications:**
- ✅ Better isolation (workspaces can't interfere)
- ✅ Multi-user safe (no shared Docker daemon)
- ⚠️ Slightly slower Docker operations (nested overhead)
- ⚠️ Can't access host Docker from workspace

### 2. Networking

**Local DDEV:**
- Uses `ddev-router` container for *.ddev.site domains
- Direct port binding to localhost
- mDNS for .ddev.site resolution
- LAN access possible (optional)

**Coder DDEV:**
- No ddev-router (not needed)
- Port forwarding via Coder proxy
- Access via DDEV Web app URL: `https://ddev-web--workspace--owner.coder.example.com/`
- *.ddev.site URLs don't work

**Migration:**
```yaml
# Local .ddev/config.yaml (not needed in Coder)
router_http_port: "80"
router_https_port: "443"
use_dns_when_possible: true

# Coder .ddev/config.yaml (simplified)
# router_disabled: true  # Optional
```

**Access patterns:**
```bash
# Local DDEV
curl https://my-site.ddev.site

# Coder DDEV
# Use Coder UI port forwarding or:
coder port-forward my-workspace --tcp 80:80
curl http://localhost:80
```

### 3. Filesystem

**Local DDEV:**
- Project files on local filesystem (e.g., `~/projects/my-site`)
- Mounted into containers via Docker bind mounts
- Fast file operations (native filesystem)
- NFS option for macOS (optional)

**Coder DDEV:**
- Project files on remote volume (`/home/coder/projects/my-site`)
- Persistent across workspace restarts
- Mounted into DDEV containers (nested mount)
- Network latency for file operations

**Performance comparison:**
| Operation | Local DDEV | Coder DDEV |
|-----------|------------|------------|
| Read file | ~1ms | ~5-20ms |
| Write file | ~1ms | ~10-50ms |
| Composer install | Fast | Slower |
| npm install | Fast | Slower |
| Database query | Fast | Similar |
| Page render | Fast | Similar |

**Optimization:**
- Use NFS mount in Coder: `nfs_mount_enabled: true` in `.ddev/config.yaml`
- Disable Xdebug when not needed: `ddev xdebug off`
- Use Docker layer caching for builds

### 4. IDE and Development Environment

**Local DDEV:**
- Desktop IDE (VS Code, PHPStorm, Sublime)
- Direct filesystem access
- Local terminal
- Native performance

**Coder DDEV:**
- VS Code for Web (browser-based)
- Remote filesystem (via Coder agent)
- Remote terminal (via SSH or VS Code)
- Network latency for file operations

**Desktop IDE with Coder:**
```bash
# Configure SSH
coder config-ssh

# VS Code Remote-SSH
# Connect to: coder.my-workspace

# PHPStorm
# Tools → Deployment → Add Server
# Type: SFTP, Host: coder.my-workspace (from SSH config)
```

**Tradeoffs:**
| Aspect | Desktop IDE + Local DDEV | VS Code Web + Coder DDEV |
|--------|--------------------------|--------------------------|
| Latency | None | 10-100ms |
| Extensions | All available | Most available |
| GPU features | Full support | Limited |
| Offline work | Yes | No |
| Setup time | Manual Docker install | Zero (pre-configured) |
| Team consistency | Varies | Identical |

### 5. Team Collaboration

**Local DDEV:**
- Each developer has own setup
- Configuration drift possible
- Manual environment setup (documentation)
- No centralized management

**Coder DDEV:**
- Identical environments for all users
- Centralized template management
- Zero-setup onboarding (create workspace)
- Admin controls resources, versions

**Example: Onboarding time**

**Local DDEV:**
1. Install Docker Desktop (5-10 min)
2. Install DDEV (5 min)
3. Install IDE (5-10 min)
4. Clone repository (5 min)
5. Install dependencies (10-30 min)
6. Configure environment (10-30 min)
7. Troubleshoot issues (0-120 min)

**Total: 40 minutes to 3+ hours**

**Coder DDEV:**
1. Get Coder credentials (1 min)
2. Create workspace (2 min)
3. Clone repository (5 min)
4. Start DDEV (2 min)

**Total: 10 minutes**

### 6. Resource Management

**Local DDEV:**
- Uses local machine resources (RAM, CPU, disk)
- Limited by laptop/desktop specs
- Must manage Docker resource limits
- Affects battery life (laptops)

**Coder DDEV:**
- Uses cloud resources (configurable)
- Scalable per project needs
- Doesn't affect local machine
- Can use powerful cloud machines for heavy workloads

**Example configurations:**

**Local laptop:**
- 16GB RAM, 4-core CPU
- Supports 2-3 DDEV projects simultaneously
- Docker Desktop limit: 8GB RAM, 2 cores

**Coder workspace:**
- Default: 8GB RAM, 4 cores
- Configurable: up to 64GB RAM, 32 cores
- Dedicated Docker volume (no local disk impact)
- Stop workspace when not in use (save costs)

### 7. Persistence and Backup

**Local DDEV:**
- Projects on local disk
- Time Machine / manual backups
- Git for code (must push)
- Database snapshots: `ddev snapshot`

**Coder DDEV:**
- Projects on persistent remote volume
- Volume survives workspace stop/restart
- Git for code (must push)
- Database snapshots: `ddev snapshot` (works same)
- Admin can backup volumes (host-level)

**Data loss scenarios:**

**Local DDEV:**
- ❌ Disk failure (no backup)
- ❌ Laptop stolen/lost
- ✅ Git push before failure
- ⚠️ Database not in Git (use snapshots)

**Coder DDEV:**
- ✅ Workspace stop/restart (data preserved)
- ✅ Volume backed up (admin configured)
- ❌ Workspace deletion (permanent)
- ⚠️ Database not in Git (use snapshots)

**Best practices:**
- **Always commit and push code regularly** (both)
- **Use `ddev snapshot` before risky operations** (both)
- **Export databases periodically** (both)
- **Don't store secrets in workspace** (both)

## Benefits of Coder DDEV

### 1. Team Consistency

**Problem with local DDEV:**
- Developer A: macOS, Docker Desktop, DDEV 1.23, PHP 8.1
- Developer B: Windows, Docker Desktop, DDEV 1.24, PHP 8.2
- Developer C: Linux, Docker Engine, DDEV 1.22, PHP 8.1

Result: "It works on my machine" syndrome.

**Solution with Coder:**
- All developers: Ubuntu 24.04, DDEV 1.24.10, PHP 8.1 (same image)
- Update template → everyone gets update
- No configuration drift

### 2. Zero-Setup Onboarding

**Local DDEV onboarding:**
```bash
# Developer's first day
brew install docker  # or download Docker Desktop
# Wait for Docker to install...
# Configure Docker resources...
brew install ddev
ddev config --auto
ddev start
# Troubleshoot Docker networking issues...
# Troubleshoot permissions...
# Troubleshoot port conflicts...
```

**Coder DDEV onboarding:**
```bash
# Developer's first day
coder create --template ddev-user my-workspace --yes
# Done!
```

### 3. Powerful Resources

**Local laptop limitations:**
- Building large Docker images: slow
- Running multiple projects: swapping
- Composer/npm with many packages: slow
- Database imports: slow

**Coder workspace:**
- Configurable resources (8GB, 16GB, 32GB RAM)
- Fast cloud CPUs
- SSD storage
- Run intensive tasks without affecting local machine

### 4. Remote Work Friendly

**Local DDEV on weak laptop:**
- Slow Docker performance
- Limited battery life
- Can't work from tablet/Chromebook

**Coder DDEV:**
- Access from any device with browser
- Work from iPad, Chromebook, hotel computer
- Same performance regardless of device

### 5. Centralized Management

**Admins can:**
- Update DDEV version for all workspaces (rebuild image)
- Set resource limits (prevent abuse)
- Backup all workspaces (host-level)
- Monitor usage and costs
- Enforce security policies

**Not possible with local DDEV.**

## Tradeoffs of Coder DDEV

### 1. Internet Dependency

**Local DDEV:**
- ✅ Works offline (once installed)
- ✅ No network latency

**Coder DDEV:**
- ❌ Requires internet connection
- ⚠️ Network latency (10-100ms)
- ⚠️ Slow/unreliable internet = bad experience

**Mitigation:**
- Use fast internet (50+ Mbps)
- Deploy Coder close to users (low latency)
- Cache Docker images in workspace

### 2. Filesystem Performance

**Local DDEV:**
- Fast file operations (native filesystem)
- `composer install`: 30 seconds

**Coder DDEV:**
- Slower file operations (remote volume)
- `composer install`: 60-90 seconds

**Mitigation:**
- Use NFS: `nfs_mount_enabled: true`
- Use Docker layer caching
- Accept tradeoff for benefits

### 3. IDE Limitations

**Local DDEV:**
- Full desktop IDE (PHPStorm, VS Code, Sublime)
- All extensions available
- Native performance

**Coder DDEV:**
- VS Code for Web (most extensions work)
- Some extensions unavailable (require desktop)
- Network latency

**Mitigation:**
- Use desktop VS Code with Remote-SSH
- Use PHPStorm with SFTP deployment
- Most developers adapt to VS Code for Web

### 4. *.ddev.site URLs Don't Work

**Local DDEV:**
- Access via: `https://my-site.ddev.site`
- Multiple projects: `https://site1.ddev.site`, `https://site2.ddev.site`

**Coder DDEV:**
- Access via port forwarding: `https://coder.example.com/port/12345`
- Multiple projects: different ports

**Mitigation:**
- Use Coder UI to find port links (bookmark them)
- Configure custom domains (admin)
- Accept tradeoff for remote access benefits

### 5. Cost Considerations

**Local DDEV:**
- Free (uses your hardware)
- One-time laptop/desktop cost

**Coder DDEV:**
- Cloud compute costs (per workspace per hour)
- Storage costs (per GB per month)

**Example costs** (AWS us-east-1, 2024):
- 4 vCPU, 8GB RAM: ~$0.15/hour = $110/month (24/7)
- Stop when not in use: ~$30/month (8 hours/day, 5 days/week)
- Storage (50GB): ~$5/month

**Mitigation:**
- Stop workspaces when not in use
- Use smaller workspaces for simple projects
- Savings from reduced onboarding time, consistency, IT support

## Migration Guide

### For Organizations

**1. Evaluate:**
- Try Coder with 2-3 developers
- Test typical workflows
- Measure onboarding time improvement
- Compare costs vs benefits

**2. Plan:**
- Choose cloud provider (AWS, GCP, Azure, on-prem)
- Install Coder server
- Install Sysbox on agent nodes
- Build and deploy ddev-user template

**3. Pilot:**
- Onboard 5-10 developers
- Collect feedback
- Iterate on template configuration
- Document workflows

**4. Rollout:**
- Onboard remaining developers
- Deprecate local DDEV (optional)
- Monitor usage and costs

### For Individual Projects

**1. Clone project:**
```bash
# In Coder workspace
cd ~/projects
git clone git@github.com:org/project.git
cd project
```

**2. Copy DDEV config:**
```bash
# Local machine (if you have custom .ddev/config.yaml)
scp -r .ddev my-workspace:~/projects/project/

# Or commit to Git:
git add .ddev/
git commit -m "Add DDEV config"
git push
```

**3. Adjust config for Coder:**
```yaml
# .ddev/config.yaml

# Remove local-specific settings
# router_http_port: "80"  # Not needed in Coder
# router_https_port: "443"  # Not needed in Coder

# Optional: disable router (saves resources)
# router_disabled: true

# Optional: enable NFS (if file operations slow)
# nfs_mount_enabled: true

# Keep all other settings
```

**4. Start project:**
```bash
ddev start
```

**5. Test:**
- Access via Coder port forwarding
- Run tests: `ddev exec phpunit`
- Check database: `ddev mysql`
- Import production database: `ddev import-db --url=...`

**6. Document differences:**
```markdown
# Project README update

## Local DDEV
Access: https://project.ddev.site

## Coder DDEV
1. Create workspace: `coder create --template ddev-user my-workspace`
2. Clone project: `git clone ...`
3. Start DDEV: `ddev start`
4. Access via Coder UI port forwarding (port 80/443)
```

### Common Migration Issues

**Issue 1: Custom local configuration**
```yaml
# Local .ddev/config.yaml
web_environment:
  - API_KEY=local-secret-key  # Don't commit secrets!

# Solution: Use .ddev/.env (gitignored)
# .ddev/.env
API_KEY=secret-key

# .ddev/config.yaml
web_environment:
  - API_KEY=${API_KEY}
```

**Issue 2: Local file paths**
```php
// Local code
require_once '/Users/john/projects/library/autoload.php';

// Solution: Use relative paths
require_once __DIR__ . '/../library/autoload.php';
```

**Issue 3: *.ddev.site hardcoded**
```javascript
// Local code
const API_URL = 'https://api.ddev.site';

// Solution: Use environment variable
const API_URL = process.env.API_URL || 'https://api.ddev.site';
```

**Issue 4: Performance-sensitive operations**
```bash
# Local: fast
npm install  # 30 seconds

# Coder: slower
ddev npm install  # 60-90 seconds

# Solution: Accept tradeoff or cache node_modules in Docker image
```

## When to Use Which

### Use Local DDEV when:

✅ **Solo developer, personal projects**
- No team coordination needed
- You control your machine
- Offline work required

✅ **Optimal performance critical**
- Heavy file operations
- Real-time compilation watchers
- Can't tolerate network latency

✅ **Very limited budget**
- Cloud costs not acceptable
- Have powerful local machine

✅ **Fully offline work**
- No reliable internet
- Security requires air-gapped dev

### Use Coder DDEV when:

✅ **Team development**
- Multiple developers
- Need consistent environments
- Onboarding time matters

✅ **Remote work**
- Distributed team
- Work from multiple locations/devices
- Weak laptops, tablets

✅ **Centralized management**
- IT wants control
- Compliance/security requirements
- Resource quotas needed

✅ **Fast onboarding**
- High turnover
- Contractors/interns
- Training environments

✅ **Scalable resources**
- Projects need more than laptop can provide
- Heavy builds, large databases

### Hybrid Approach

Some teams use both:

**Developers choose:**
- Local DDEV for daily work (fast)
- Coder DDEV for testing, demos, reviews
- Coder DDEV for onboarding new team members

**Projects decide:**
- Simple projects: local DDEV
- Complex projects: Coder DDEV
- Prototypes: local DDEV
- Production-like environments: Coder DDEV

## Frequently Asked Questions

**Q: Can I use my existing .ddev/config.yaml?**

A: Yes, mostly. Remove local-specific settings like `router_http_port`. Most settings work identically.

**Q: Do all DDEV project types work?**

A: Yes, all 20+ project types work (WordPress, Drupal, Laravel, etc.). DDEV is identical; only access method changes.

**Q: Can I use Xdebug?**

A: Yes, `ddev xdebug on` works. Configure your IDE for remote debugging via SSH.

**Q: What about PHPStorm?**

A: Use PHPStorm with SFTP deployment mode and remote interpreter. Not as seamless as local but works.

**Q: Is it slower?**

A: File operations are slower (network latency). Database queries and page loads are similar. Tradeoff for remote access and team consistency.

**Q: Can I work offline?**

A: No, internet required. Local DDEV better for offline work.

**Q: What if workspace is deleted?**

A: All data lost (like deleting local project). Always commit and push to Git. Admins can backup volumes.

**Q: How much does it cost?**

A: Depends on cloud provider and usage. ~$30-110/month per workspace. Stop when not in use to save costs.

**Q: Can I migrate back to local DDEV?**

A: Yes, easily. Clone Git repo, use same .ddev/config.yaml, run `ddev start`.

## Conclusion

**Coder DDEV is not a replacement for local DDEV in all cases.** It's a different deployment model with different tradeoffs.

**Best for:**
- Teams prioritizing consistency and onboarding speed
- Remote/distributed teams
- Organizations with centralized IT management
- Projects needing more resources than laptops provide

**Local DDEV still best for:**
- Solo developers with good local setup
- Performance-critical workflows
- Offline work requirements
- Budget-constrained personal projects

**Key insight:** Most teams value consistency, onboarding speed, and remote access over filesystem performance. But evaluate based on your specific needs.

## Additional Resources

- [DDEV Documentation](https://docs.ddev.com/) - Official DDEV docs
- [Coder Documentation](https://coder.com/docs) - Official Coder docs
- [Getting Started Guide](../user/getting-started.md) - New to Coder DDEV
- [Operations Guide](../admin/operations-guide.md) - Deployment and management
- [GitHub Issues](https://github.com/ddev/coder-ddev/issues) - Ask questions, report issues
