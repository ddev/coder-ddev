# Coder DDEV Base Image

This Docker image is the base image for Coder DDEV workspaces. It provides a complete development environment for DDEV projects with Docker-in-Docker support.

## Contents

**Base System:**
- Ubuntu 24.04 LTS
- Essential build tools (gcc, make, git, curl, wget, vim)
- bash-completion for better shell experience

**User Configuration:**
- `coder` user (UID 1000, GID 1000)
- Passwordless sudo access
- Member of docker group (GID 988)

**Docker:**
- Docker CE (latest stable)
- Docker Compose
- containerd
- Configured for Sysbox runtime (systemd enabled)

**DDEV:**
- DDEV (from official apt repository)
- Supports 20+ project types (PHP, Node.js, Python, static sites)

**Development Tools:**
- Node.js 24.x LTS (via NodeSource)
- npm with global package support
- Python 3 with pip

**Path Configuration:**
- `/home/coder/.local/bin` - User-local binaries
- `/home/coder/.npm-global/bin` - Global npm packages

## Building

### Using Makefile (Recommended)

From the repository root:

```bash
# Build image with cache
make build

# Build without cache (clean build)
make build-no-cache

# Push to Docker Hub
make push

# Build and push in one command
make build-and-push

# Test built image
make test

# Show version information
make info
```

### Manual Build

From this directory:

```bash
# Read version from ../VERSION file
VERSION=$(cat ../VERSION)

# Build image
docker build -t ddev/coder-ddev:$VERSION .

# Tag as latest
docker tag ddev/coder-ddev:$VERSION ddev/coder-ddev:latest

# Test image
docker run --rm ddev/coder-ddev:$VERSION ddev --version
docker run --rm ddev/coder-ddev:$VERSION docker --version
docker run --rm ddev/coder-ddev:$VERSION node --version

# Push to registry
docker push ddev/coder-ddev:$VERSION
docker push ddev/coder-ddev:latest
```

## Customization

### Adding System Packages

Edit the Dockerfile to add packages:

```dockerfile
# Add packages to base layer
RUN apt-get update && apt-get install -y \
    your-package-here \
    another-package \
    && rm -rf /var/lib/apt/lists/*
```

### Changing Node.js Version

Update the NodeSource setup in Dockerfile:

```dockerfile
# For Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# For Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
```

### Adding Global npm Packages

Add to the npm install layer:

```dockerfile
RUN npm install -g \
    @fission-ai/openspec \
    typescript \
    your-package-here
```

### Customizing DDEV Global Config

Edit `scripts/.ddev/global_config.yaml`:

```yaml
# Example customizations
instrumentation_opt_in: false
internet_detection_timeout_ms: 3000
use_hardened_images: true
use_letsencrypt: false
# ... other settings
```

This file is copied to `/home/coder/.ddev/global_config.yaml` during workspace startup.

## Image Layers

The Dockerfile uses a multi-layer strategy for efficient caching:

1. **Base packages** - System tools, build essentials
2. **User setup** - Create coder user, configure sudo
3. **Scripts** - Copy files to `/home/coder-files/` (outside volume mount)
4. **Python/Node** - Install interpreters and package managers
5. **Global npm** - Install global packages
6. **Docker** - Install Docker daemon, CLI, containerd
7. **DDEV** - Install DDEV from official repository

**Layer tips:**
- Frequently changing layers should come last
- Group related operations to reduce layer count
- Clean up package manager caches to reduce image size

## Directory Structure

```
image/
├── Dockerfile           # Image build instructions
├── README.md            # This file
└── scripts/             # Files embedded in image
    ├── .ddev/
    │   └── global_config.yaml  # DDEV global configuration
    └── WELCOME.txt      # Workspace welcome message
```

**Important:** Files in `scripts/` are copied to `/home/coder-files/` in the image. The startup script copies them to `/home/coder/` during workspace initialization (because `/home/coder` volume mount hides image contents).

## Testing the Image

### Basic Tests

```bash
# Test DDEV
docker run --rm ddev/coder-ddev:v0.1 ddev version

# Test Docker CLI
docker run --rm ddev/coder-ddev:v0.1 docker --version

# Test Node.js
docker run --rm ddev/coder-ddev:v0.1 node --version

# Test user configuration
docker run --rm ddev/coder-ddev:v0.1 id
# Should show: uid=1000(coder) gid=1000(coder) groups=1000(coder),988(docker)
```

### Full Sysbox Test

Requires Sysbox installed on host:

```bash
# Run container with Sysbox runtime
docker run --runtime=sysbox-runc -d --name test-ddev \
  ddev/coder-ddev:v0.1 sleep infinity

# Exec into container
docker exec -it test-ddev bash

# Inside container, start Docker daemon
sudo dockerd &
sleep 5

# Test Docker inside container
docker ps
docker run hello-world

# Test DDEV
mkdir -p ~/projects/test-site
cd ~/projects/test-site
ddev config --project-type=php --docroot=.
echo "<?php phpinfo();" > index.php
ddev start
curl localhost:80

# Cleanup
exit
docker stop test-ddev
docker rm test-ddev
```

## Versioning

Image versions are managed via the `VERSION` file in the repository root.

**Version scheme:**
- **v0.x** - Beta versions during development
- **v1.x** - Stable releases
- **latest** - Always points to most recent build

**Releasing a new version:**

1. Update `VERSION` file:
   ```bash
   echo "v0.7" > ../VERSION
   ```

2. Build, push image, and push template (VERSION is synced automatically):
   ```bash
   cd ..  # Back to repository root
   make deploy-ddev-user
   ```

## Troubleshooting

### Build Failures

**Package installation fails:**
```bash
# Try build without cache
docker build --no-cache -t test-image .
```

**Docker daemon won't install:**
- Verify base image is Ubuntu 24.04
- Check Docker apt repository is accessible
- Check for systemd configuration issues

**DDEV installation fails:**
- Verify DDEV apt repository is accessible (pkg.ddev.com)
- Check DDEV version availability

### Image Size Issues

```bash
# Check image size
docker images ddev/coder-ddev

# Analyze layers
docker history ddev/coder-ddev:v0.1

# Common causes:
# - Package manager caches not cleaned
# - Unnecessary build dependencies included
# - Large files in COPY commands
```

**Optimization tips:**
- Combine RUN commands to reduce layers
- Clean apt cache: `rm -rf /var/lib/apt/lists/*`
- Use multi-stage builds for build tools
- Minimize COPY operations

### Runtime Issues

**Docker daemon won't start in container:**
- Ensure host has Sysbox installed
- Check container uses `--runtime=sysbox-runc`
- Verify systemd is enabled in container

**Permission issues:**
- Check coder user has UID 1000
- Verify docker group has GID 988
- Confirm coder user is in docker group

## Additional Resources

- **[Operations Guide](../docs/admin/operations-guide.md)** - Template deployment and management
- **[Troubleshooting Guide](../docs/admin/troubleshooting.md)** - Debugging workspace issues
- **[Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)** - Official Docker docs
- **[Sysbox Documentation](https://github.com/nestybox/sysbox)** - Sysbox runtime details
- **[DDEV Documentation](https://docs.ddev.com/)** - DDEV reference
