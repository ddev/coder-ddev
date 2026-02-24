# Troubleshooting Guide

This guide covers common issues with the DDEV Coder template and their solutions.

## Table of Contents

- [Template Deployment Issues](#template-deployment-issues)
- [Workspace Startup Failures](#workspace-startup-failures)
- [Docker Daemon Issues](#docker-daemon-issues)
- [DDEV Container Issues](#ddev-container-issues)
- [Permission and File Ownership](#permission-and-file-ownership)
- [Networking and Port Forwarding](#networking-and-port-forwarding)
- [VS Code for Web Issues](#vs-code-for-web-issues)
- [Performance Problems](#performance-problems)
- [Debugging Tools](#debugging-tools)

## Template Deployment Issues

### Template Push Fails

**Symptom:** `coder templates push` fails with validation error

**Check:**
```bash
# Validate Terraform syntax
cd ddev-user
terraform init
terraform validate

# Check for syntax errors
terraform fmt -check
```

**Common causes:**
- Invalid HCL syntax in `template.tf`
- Missing required variables
- Invalid Docker image reference
- Registry authentication issues

**Solution:**
```bash
# Fix syntax errors
terraform fmt ddev-user/template.tf

# Test locally
cd ddev-user
terraform init
terraform plan

# Push with verbose output
coder templates push --directory ddev-user ddev-user --yes --verbose
```

### Template Not Visible to Users

**Symptom:** Users don't see template in Coder UI

**Check:**
```bash
# List templates
coder templates list

# Check template organization
coder templates show ddev-user --json | grep organization

# Check user's organization
coder users show <username> --json | grep organization
```

**Solution:**
- Ensure template is deployed to user's organization
- Verify user has "Member" role or higher
- Check template access restrictions (Enterprise only)

### Docker Image Pull Fails

**Symptom:** Workspace creation fails with "image pull error"

**Check:**
```bash
# Test image pull locally
docker pull ddev/coder-ddev:v0.1

# Check registry authentication
docker login

# Check template image reference
grep workspace_image_registry ddev-user/template.tf
```

**Solution:**
```bash
# For private registries, configure template variables:
coder create --template ddev-user my-workspace \
  --parameter registry_username=myuser \
  --parameter registry_password=mypass \
  --yes

# Or set default credentials in template.tf
```

## Workspace Startup Failures

### Workspace Stuck in "Starting" State

**Symptom:** Workspace creation hangs, never reaches "Running"

**Check:**
```bash
# View workspace logs
coder logs my-workspace

# Check Coder agent logs
docker logs coder-<workspace-id>

# SSH into workspace (if agent started)
coder ssh my-workspace -- journalctl -u coder-agent -f
```

**Common causes:**
1. **Startup script failure** - Check Coder agent logs: `coder logs my-workspace`
2. **Docker daemon not starting** - Check `/tmp/dockerd.log`
3. **Sysbox runtime missing** - Verify host has Sysbox installed
4. **Resource exhaustion** - Check host has available CPU/RAM

**Solution:**
```bash
# Check startup logs (output goes to Coder agent logs)
coder logs my-workspace

# Check Docker daemon logs
coder ssh my-workspace -- cat /tmp/dockerd.log

# Check Sysbox on host
sysbox-runc --version

# Check resource availability
docker stats
df -h /home/coder/workspaces/
```

### Startup Script Errors

**Symptom:** Startup script fails with permission or command errors

**Check startup script:** `ddev-user/scripts/startup.sh`

**Common issues:**

**Issue 1: chown fails**
```bash
# Error: chown: cannot access '/home/coder': Permission denied
```
**Solution:** Check volume mount in `template.tf`:
```hcl
volume {
  container_path = "/home/coder"
  host_path     = "/home/coder/workspaces/${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
}
```

**Issue 2: Docker daemon won't start**
```bash
# Error: failed to start dockerd
```
**Solution:** Check Sysbox runtime and security options:
```hcl
runtime = "sysbox-runc"
security_opt = ["apparmor:unconfined", "seccomp:unconfined"]
```

**Issue 3: DDEV not found**
```bash
# Error: ddev: command not found
```
**Solution:** Rebuild Docker image with DDEV installed:
```bash
cd image
docker build --no-cache -t ddev/coder-ddev:v0.1 .
docker push ddev/coder-ddev:v0.1
```

### Workspace Won't Start After Stop

**Symptom:** Previously working workspace fails to restart

**Check:**
```bash
# Check workspace status
coder show my-workspace

# View logs
coder logs my-workspace

# Check for stale Docker processes
docker ps -a | grep coder
```

**Solution:**
```bash
# Delete and recreate workspace
coder delete my-workspace --yes
coder create --template ddev-user my-workspace --yes

# Or force restart
docker restart coder-<workspace-id>
```

## Docker Daemon Issues

### Docker Daemon Not Starting

**Symptom:** `docker ps` fails inside workspace with "Cannot connect to Docker daemon"

**Check:**
```bash
# Inside workspace
coder ssh my-workspace

# Check dockerd process
ps aux | grep dockerd

# Check Docker socket
ls -la /var/run/docker.sock

# Check dockerd logs
cat /tmp/dockerd.log

# Check systemd service
systemctl status docker
```

**Common causes:**

**Cause 1: Sysbox not installed on host**
```bash
# On Coder host
sysbox-runc --version

# Install if missing (no apt repo; download .deb from releases page)
# https://github.com/nestybox/sysbox/releases
SYSBOX_VERSION=0.6.7
wget https://downloads.nestybox.com/sysbox/releases/v${SYSBOX_VERSION}/sysbox-ce_${SYSBOX_VERSION}-0.linux_amd64.deb
apt-get install -y jq ./sysbox-ce_${SYSBOX_VERSION}-0.linux_amd64.deb
# Note: installer automatically restarts Docker
```

**Cause 2: Container not using Sysbox runtime**
```bash
# Check template.tf
grep runtime ddev-user/template.tf
# Should be: runtime = "sysbox-runc"
```

**Cause 3: Missing security profiles**
```bash
# Check template.tf
grep security_opt ddev-user/template.tf
# Should include:
# security_opt = ["apparmor:unconfined", "seccomp:unconfined"]
```

**Cause 4: Docker volume not mounted**
```bash
# Check volume mount
docker inspect coder-<workspace-id> | grep "Destination.*docker"
# Should show: /var/lib/docker mounted

# Check volume exists
docker volume ls | grep dind-cache
```

**Solution:**
```bash
# Fix template.tf and redeploy
coder templates push --directory ddev-user ddev-user --yes

# Recreate workspace
coder delete my-workspace --yes
coder create --template ddev-user my-workspace --yes
```

### Docker Daemon Crashes

**Symptom:** Docker works initially but stops responding

**Check:**
```bash
# Inside workspace
journalctl -u docker -f

# Check disk space
df -h /var/lib/docker

# Check for OOM kills
dmesg | grep oom

# Check Docker daemon logs
cat /tmp/dockerd.log
```

**Solution:**
```bash
# To increase resources, delete and recreate workspace with higher memory
# (Back up data first: coder ssh my-workspace -- tar -czf ~/backup.tar.gz ~/projects)
coder delete my-workspace --yes
coder create --template ddev-user my-workspace --parameter memory=16 --yes

# Clean up Docker resources
docker system prune -a --volumes -f

# Restart Docker daemon
sudo systemctl restart docker
```

### Docker Permission Errors

**Symptom:** `permission denied while trying to connect to Docker daemon`

**Check:**
```bash
# Inside workspace
groups  # Should include "docker"
ls -la /var/run/docker.sock
getent group docker  # Check GID
```

**Solution:**
```bash
# Check docker_gid in template.tf matches host
# Default is 988

# Add user to docker group (should be done in startup script)
sudo usermod -aG docker $USER

# Or check group_add in template.tf:
# group_add = ["988"]
```

## DDEV Container Issues

### DDEV Containers Won't Start

**Symptom:** `ddev start` fails or containers exit immediately

**Check:**
```bash
# Inside workspace
ddev start --debug

# Check Docker daemon
docker ps
docker info

# Check DDEV version
ddev version

# Check for port conflicts
docker ps -a | grep ddev
```

**Common causes:**

**Cause 1: Docker daemon not running**
```bash
docker ps
# If fails: systemctl status docker
```

**Cause 2: Insufficient resources**
```bash
docker stats
free -h
# Increase workspace memory/CPU if needed
```

**Cause 3: Port conflicts**
```bash
ddev describe
# Check for conflicting projects
ddev list
ddev stop --all
```

**Cause 4: Corrupt DDEV project**
```bash
ddev delete --omit-snapshot
rm -rf .ddev
ddev config --auto
ddev start
```

**Solution:**
```bash
# Clean restart
ddev poweroff
ddev start

# Or rebuild
ddev delete --omit-snapshot
ddev config --auto
ddev start
```

### DDEV Database Import Fails

**Symptom:** `ddev import-db` fails with memory or timeout errors

**Check:**
```bash
# Check workspace resources
docker stats

# Check database container logs
ddev logs db

# Check disk space
df -h
```

**Solution:**
```bash
# To increase memory, delete and recreate workspace with higher memory
# (Back up data first: ddev export-db --file=dump.sql.gz)
coder delete my-workspace --yes
coder create --template ddev-user my-workspace --parameter memory=16 --yes

# Split large imports
gunzip < dump.sql.gz | split -l 50000 - split_
for file in split_*; do ddev import-db --file=$file; done

# Or use mysql directly
ddev mysql < dump.sql
```

### DDEV URLs Not Accessible

**Symptom:** DDEV project URLs don't work

**Check:**
```bash
# Check DDEV status
ddev describe

# Check port forwarding in Coder UI
# Should see ports 80, 443, 8080, 8443, 8025, 8026

# Test locally in workspace
curl localhost:80
```

**Solution:**
- Access via Coder port forwarding UI (not direct URLs)
- Click on port links in Coder dashboard under "Apps"
- DDEV URLs shown by `ddev describe` won't work directly
- Use Coder's proxied URLs instead

## Permission and File Ownership

### File Ownership Issues

**Symptom:** Files owned by root or wrong UID

**Check:**
```bash
# Inside workspace
ls -la /home/coder
id  # Should be UID 1000

# Check volume ownership on host
ls -la /home/coder/workspaces/<owner>-<workspace>
```

**Solution:**
```bash
# Startup script should fix this automatically
# If not, run manually:
sudo chown -R coder:coder /home/coder

# Or on host:
chown -R 1000:1000 /home/coder/workspaces/<owner>-<workspace>
```

### Sudo Doesn't Work

**Symptom:** `sudo: command not found` or permission denied

**Check:**
```bash
# Inside workspace
which sudo
cat /etc/sudoers.d/coder
groups
```

**Solution:**
Rebuild image with sudo configured:
```dockerfile
# In image/Dockerfile
RUN echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder
```

### Can't Write to Home Directory

**Symptom:** Permission denied writing to `/home/coder`

**Check:**
```bash
ls -la /home/coder
df /home/coder  # Check if volume mounted
```

**Solution:**
```bash
# Fix ownership
sudo chown -R coder:coder /home/coder

# Check volume mount in template.tf
# Should have:
# volume {
#   container_path = "/home/coder"
#   host_path      = "/home/coder/workspaces/${...}"
# }
```

## Networking and Port Forwarding

### Can't Access DDEV Project

**Symptom:** Coder port forwarding shows ports but URLs don't work

**Check:**
```bash
# Inside workspace
ddev describe
curl localhost:80
docker ps | grep ddev

# Check Coder port forwarding UI
# Should see forwarded ports
```

**Solution:**
- Use Coder's port forwarding links (not DDEV's URLs)
- Ensure DDEV is configured for Coder environment
- Check `host_webserver_port` in `.ddev/global_config.yaml`

### Port Conflicts

**Symptom:** Port already in use errors

**Check:**
```bash
# Inside workspace
ddev list
docker ps

# Check for conflicting projects
netstat -tlnp | grep :80
```

**Solution:**
```bash
# Stop all DDEV projects
ddev stop --all

# Or configure different ports in .ddev/config.yaml:
router_http_port: "8080"
router_https_port: "8443"
```

### VS Code Port Forwarding Not Working

**Symptom:** VS Code can't forward ports from workspace

**Check:**
```bash
# Verify service is listening
netstat -tlnp | grep <port>

# Test locally
curl localhost:<port>
```

**Solution:**
- Use Coder's port forwarding (not VS Code's)
- Configure ports in `template.tf` `coder_app` resources
- VS Code port forwarding may not work with Docker-in-Docker

## VS Code for Web Issues

### VS Code Won't Load

**Symptom:** VS Code app shows blank page or infinite loading

**Check:**
```bash
# Check workspace is running
coder list

# Check agent is running
coder ssh my-workspace -- echo "Agent OK"

# Check browser console for errors
```

**Solution:**
- Refresh browser
- Clear browser cache and cookies
- Try different browser
- Restart workspace: `coder restart my-workspace`

### VS Code Extensions Won't Install

**Symptom:** Extensions fail to install or don't work

**Check:**
```bash
# Check disk space
coder ssh my-workspace -- df -h

# Check VS Code version
# (View in VS Code: Help → About)
```

**Solution:**
- Some extensions require desktop VS Code
- Use SSH connection with desktop VS Code:
  ```bash
  coder config-ssh
  # Then connect via VS Code Remote-SSH
  ```

### VS Code Terminal Issues

**Symptom:** Terminal in VS Code doesn't work or has wrong shell

**Check:**
```bash
# Inside workspace terminal
echo $SHELL
which bash zsh

# Check VS Code terminal settings
```

**Solution:**
- Default shell is bash
- Change in VS Code settings: `Terminal › Integrated › Default Profile: Linux`
- Restart VS Code

## Performance Problems

### Workspace is Slow

**Check:**
```bash
# Check resource usage
docker stats coder-<workspace-id>

# Inside workspace
top
df -h
docker stats
```

**Causes:**
1. **Insufficient resources** - Increase CPU/memory
2. **Disk I/O** - Check Docker volume performance
3. **Too many DDEV projects running** - Stop unused projects

**Solution:**
```bash
# Increase resources
coder update my-workspace \
  --parameter cpu=8 \
  --parameter memory=16

# Stop unused DDEV projects
ddev stop --all
ddev start  # Only current project

# Clean Docker cache
docker system prune -a -f
```

### Docker Build is Slow

**Symptom:** `docker build` or DDEV builds take very long

**Check:**
```bash
# Check Docker info
docker info | grep "Storage Driver"

# Check disk performance
dd if=/dev/zero of=/tmp/test bs=1M count=1024
rm /tmp/test
```

**Solution:**
- Increase workspace resources
- Use Docker BuildKit: `DOCKER_BUILDKIT=1 docker build ...`
- Use multi-stage builds to reduce layer count
- Host may need SSD for `/var/lib/docker` volumes

### DDEV Performance Issues

**Symptom:** DDEV project is slow (page loads, composer, npm)

**Check:**
```bash
ddev describe
docker stats $(docker ps -q --filter name=ddev)
```

**Solution:**
```bash
# To increase resources, delete and recreate workspace
# (Back up data first: coder ssh my-workspace -- tar -czf ~/backup.tar.gz ~/projects)
coder delete my-workspace --yes
coder create --template ddev-user my-workspace --parameter memory=16 --yes

# Use NFS for file sharing (if Mutagen is slow)
# Edit .ddev/config.yaml:
# nfs_mount_enabled: true

# Disable xdebug when not needed
ddev xdebug off
```

## Debugging Tools

### Viewing Logs

**Workspace agent logs:**
```bash
# Via Coder CLI
coder logs my-workspace

# Via Docker
docker logs coder-<workspace-id>

# Inside workspace
journalctl -u coder-agent -f
```

**Startup script logs** (output goes to Coder agent logs):
```bash
coder logs my-workspace
```

**Docker daemon logs:**
```bash
coder ssh my-workspace -- cat /tmp/dockerd.log
coder ssh my-workspace -- journalctl -u docker -f
```

**DDEV logs:**
```bash
coder ssh my-workspace -- ddev logs
coder ssh my-workspace -- ddev logs db
coder ssh my-workspace -- ddev logs web
```

### Interactive Debugging

**SSH into workspace:**
```bash
# Open shell
coder ssh my-workspace

# Run command
coder ssh my-workspace -- docker ps

# View startup logs (written to Coder agent logs)
coder logs my-workspace
```

**Check workspace state:**
```bash
# Show workspace details
coder show my-workspace

# Check container
docker inspect coder-<workspace-id>

# Check volumes
docker volume ls | grep coder
docker volume inspect coder-<owner>-<workspace>-dind-cache
```

**Test Docker inside workspace:**
```bash
coder ssh my-workspace -- docker ps
coder ssh my-workspace -- docker info
coder ssh my-workspace -- docker run hello-world
```

**Test DDEV:**
```bash
coder ssh my-workspace -- ddev version
coder ssh my-workspace -- ddev list
coder ssh my-workspace -- ddev describe
```

### Common Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| `failed to connect to agent` | Coder agent not running | Check startup script, restart workspace |
| `runtime "sysbox-runc" not found` | Sysbox not installed on host | Install Sysbox on Coder agent nodes |
| `permission denied` (Docker) | User not in docker group | Check `group_add` in template.tf |
| `no space left on device` | Disk full | Clean up Docker: `docker system prune -a` |
| `OOMKilled` | Out of memory | Increase workspace memory parameter |
| `port is already allocated` | Port conflict | Stop conflicting containers or change ports |
| `failed to mount volume` | Volume mount issue | Check volume paths in template.tf |
| `unable to pull image` | Image not found or auth failed | Check registry, credentials, image tag |

### Emergency Recovery

**Workspace completely broken:**
```bash
# 1. Backup data if possible
coder ssh my-workspace -- tar -czf ~/backup.tar.gz ~/projects

# 2. Copy backup to local machine
coder scp my-workspace:~/backup.tar.gz ./

# 3. Delete and recreate workspace
coder delete my-workspace --yes
coder create --template ddev-user my-workspace --yes

# 4. Restore data
coder scp ./backup.tar.gz my-workspace:~/
coder ssh my-workspace -- tar -xzf ~/backup.tar.gz
```

**Docker daemon completely broken:**
```bash
# Inside workspace
sudo systemctl stop docker
sudo rm -rf /var/lib/docker/*
sudo systemctl start docker

# Or restart workspace
exit
coder restart my-workspace
```

**Host out of resources:**
```bash
# On Coder host
docker system prune -a --volumes -f
df -h
du -sh /home/coder/workspaces/* | sort -h
# Delete unused workspaces
```

## Getting Help

### Information to Collect

When reporting issues, provide:

1. **Workspace details:**
   ```bash
   coder show my-workspace
   ```

2. **Logs:**
   ```bash
   coder logs my-workspace > workspace-logs.txt
   ```

3. **Template version:**
   ```bash
   grep image_version ddev-user/template.tf
   cat VERSION
   ```

4. **Environment:**
   - Coder version: `coder version`
   - Docker version (in workspace): `docker --version`
   - DDEV version: `ddev version`
   - Host OS and kernel version

5. **Error messages:**
   - Full error output
   - Browser console errors (for UI issues)

### Additional Resources

- [Operations Guide](./operations-guide.md) - Template deployment
- [User Management](./user-management.md) - User and permission issues
- [Coder Troubleshooting](https://coder.com/docs/guides/troubleshooting) - Official docs
- [Sysbox Troubleshooting](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/troubleshoot.md) - Sysbox-specific issues
- [DDEV Troubleshooting](https://docs.ddev.com/users/usage/troubleshooting/) - DDEV-specific issues
- [GitHub Issues](https://github.com/ddev/coder-ddev/issues) - Report bugs or ask questions
