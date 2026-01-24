# DDEV Router Setup for Coder

This guide explains how to configure DDEV to work with Coder's built-in router for proper hostname-based routing.

## Background

**Status: Host headers ARE forwarded** ✓

Coder provides automatic port forwarding with hostname-based routing. When you create a `coder_app` resource with `subdomain = true`, Coder generates URLs following this pattern:

```
https://{app-slug}--{workspace-name}--{owner}--{workspace-id}.{coder-domain}/
```

For example:
```
https://ddev-web--test-fresh--rfay--955tu8k2ih1ck.pit-1.try.coder.app/
```

Where:
- `app-slug`: `ddev-web` (from the Coder template's `coder_app` resource)
- `workspace-name`: `test-fresh` (your workspace name)
- `owner`: `rfay` (your username)
- `workspace-id`: `955tu8k2ih1ck` (unique workspace ID)
- `coder-domain`: `pit-1.try.coder.app` (your Coder instance domain)

The browser sends requests to this URL with a matching `Host:` header, which Coder's router uses to forward traffic to the correct workspace and port.

## DDEV Configuration

For DDEV to work with Coder's routing, it needs to:
1. Use the correct hostname that matches Coder's URL pattern
2. Know the proper TLD (Coder domain) for routing

This is done by creating a `.ddev/config.coder.yaml` file in your DDEV project with:

```yaml
name: ddev-web--{workspace-name}--{owner}--{workspace-id}
project_tld: {coder-domain}
```

## Setup Methods

### Method 1: Manual Script (Recommended for Testing)

Run the configuration script manually in your DDEV project directory:

```bash
cd ~/projects/your-project
bash /path/to/coder-ddev/scripts/configure-ddev-router.sh
```

The script will:
1. Auto-detect Coder environment variables
2. Extract the Coder domain from `CODER_AGENT_URL` or `CODER_URL`
3. Generate `.ddev/config.coder.yaml` with the correct settings
4. Display the expected URL

Then restart DDEV:
```bash
ddev restart
```

### Method 2: DDEV Host Command

Use the DDEV host command (available after workspace restart):

```bash
cd ~/projects/your-project
ddev configure-coder-hostname
ddev restart
```

This command is automatically available in all DDEV projects and can be run anytime.

### Method 3: Automatic Pre-Start Hook (Recommended for Production)

For automatic configuration on every `ddev start`, create a pre-start hook in your DDEV project:

**Create `.ddev/config.hooks.yaml`:**

```yaml
hooks:
  pre-start:
    - exec-host: ddev configure-coder-hostname
```

With this hook, the Coder hostname configuration will run automatically before DDEV starts, ensuring your project is always configured correctly.

### Method 4: Manual Configuration

If you prefer to configure manually, create `.ddev/config.coder.yaml`:

```yaml
# DDEV configuration for Coder.com deployment
name: ddev-web--myworkspace--username--abc123xyz
project_tld: pit-1.try.coder.app

# Use router_http_port and router_https_port from global_config.yaml
# These should be 8080 and 8443 respectively for Coder port forwarding
```

Replace the values with your actual workspace information.

## Environment Variables

The configuration scripts use these Coder environment variables (automatically set by Coder):

- `CODER_WORKSPACE_NAME` - Workspace name (e.g., `test-fresh`)
- `CODER_WORKSPACE_OWNER_NAME` - Username (e.g., `rfay`)
- `CODER_AGENT_URL` - Agent URL containing workspace ID and domain
  - Format: `https://{workspace-id}.{domain}/`
  - Example: `https://955tu8k2ih1ck.pit-1.try.coder.app/`
  - The workspace ID and domain are extracted from this URL

The scripts automatically extract:
- **Workspace ID**: From the subdomain in `CODER_AGENT_URL` (e.g., `955tu8k2ih1ck`)
- **Coder Domain**: From the domain in `CODER_AGENT_URL` (e.g., `pit-1.try.coder.app`)

If auto-detection fails, you can manually set these:

```bash
export CODER_WORKSPACE_NAME=my-workspace
export CODER_WORKSPACE_OWNER_NAME=myusername
export CODER_AGENT_URL=https://abc123xyz.pit-1.try.coder.app/
```

## Accessing Your Site

After configuration and starting DDEV:

1. **Via Coder Dashboard:**
   - Go to your workspace in Coder
   - Click the "Apps" section
   - Click the "DDEV Web" app link

2. **Direct URL:**
   - Use the URL shown by the configuration script
   - Format: `https://ddev-web--{workspace}--{owner}--{id}.{domain}/`

## Troubleshooting

### "Not a DDEV project directory"

You need to initialize DDEV first:
```bash
cd ~/projects/your-project
ddev config --project-type=php --docroot=web
```

### "Missing required information"

The script couldn't detect Coder environment variables. Check:
```bash
echo $CODER_WORKSPACE_NAME
echo $CODER_WORKSPACE_OWNER
echo $CODER_WORKSPACE_ID
echo $CODER_AGENT_URL
```

If missing, you can manually set them or edit `.ddev/config.coder.yaml` directly.

### Site not loading / 404 errors

1. Ensure DDEV is running: `ddev status`
2. Check the "ddev-web" app is healthy in Coder dashboard
3. Verify the URL matches: `ddev describe` should show the correct URL
4. Check DDEV router status: `ddev logs -s ddev-router`

### Wrong hostname in browser

The `.ddev/config.coder.yaml` file overrides the default DDEV hostname. To regenerate:
```bash
rm .ddev/config.coder.yaml
ddev configure-coder-hostname
ddev restart
```

### Router Returns 404

**Problem**: Accessing the Coder URL shows "404 page not found" from Traefik/ddev-router.

**Solution**: The router doesn't recognize the Coder hostname. Ensure `.ddev/config.coder.yaml` exists with the correct settings and restart DDEV.

### DDEV uses wrong URL

Run `ddev describe` to see the configured URLs. If they don't match the Coder app URL, regenerate the config:
```bash
ddev configure-coder-hostname
ddev restart
ddev describe
```

## Technical Details

### Port Forwarding

The Coder template uses these port mappings:
- Container port 8080 → DDEV web container HTTP (via `router_http_port` in global config)
- Container port 8443 → DDEV web container HTTPS (via `router_https_port` in global config)

The `coder_app` resource with `subdomain = true` creates the subdomain-based URL.

### DDEV Router Configuration

The global DDEV configuration (`.ddev/global_config.yaml`) sets:
```yaml
router_http_port: "8080"
router_https_port: "8443"
use_dns_when_possible: false
```

This ensures DDEV's router binds to ports that Coder forwards, and disables DNS lookups (which won't work in the container environment).

### Configuration Precedence

DDEV loads configuration files in this order:
1. `.ddev/config.yaml` (base configuration)
2. `.ddev/config.*.yaml` (including `config.coder.yaml`)

Settings in `config.coder.yaml` override the base configuration, allowing you to keep Coder-specific settings separate from your main DDEV config.

## Integration with CI/CD

For projects that need to work both locally and in Coder:

1. **Keep `.ddev/config.coder.yaml` out of version control:**
   ```bash
   echo ".ddev/config.coder.yaml" >> .gitignore
   ```

2. **Use the pre-start hook** (Method 3) so configuration is automatic

3. **Document Coder setup** in your project README for team members

## Benefits of This Approach

Using the DDEV router with proper Coder configuration provides:
- **Automatic routing** - DDEV router handles all traffic
- **Multiple projects** simultaneously with different hostnames
- **Mailpit integration** - Email testing via DDEV's built-in Mailpit
- **Consistent workflow** - Same DDEV commands work locally and in Coder
- **Proper SSL** - Coder handles SSL termination externally

## Related Files

- `coder-ddev/scripts/configure-ddev-router.sh` - Standalone configuration script
- `image/scripts/.ddev/commands/host/configure-coder-hostname` - DDEV host command
- `coder-ddev/template.tf` - Coder template with `coder_app` resource definition
- `image/scripts/.ddev/global_config.yaml` - DDEV global configuration
