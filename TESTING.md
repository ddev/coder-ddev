# Testing Coder Host Header Forwarding

## Quick Test

To determine if Coder forwards the Host header to your workspace:

### 1. Stop DDEV (if running)

```bash
ddev stop --all
```

### 2. Run the test server

```bash
./test-coder-headers.sh
```

This will start a simple HTTP server on port 80 that logs all incoming headers.

### 3. Access via Coder

1. Open your Coder dashboard
2. Click on the "DDEV Web" app
3. A browser tab will open

### 4. Check the terminal output

Look for the `Host:` header in the terminal output. It will be highlighted with `>>>`.

**If you see:**
```
>>> Host: ddev-web--workspace--user--id.coder.domain <<<
```

Then Coder **IS forwarding the Host header**! You can configure DDEV to accept this hostname.

**If you see:**
```
>>> Host: localhost <<<
```
or
```
>>> Host: 127.0.0.1 <<<
```

Then Coder is **NOT forwarding the Host header**, and you'll need to use a workaround.

## Testing Different Ports

To test port 8080 instead:

```bash
./test-coder-headers.sh 8080
```

Then update the `coder_app` resource temporarily to use that port:
```hcl
resource "coder_app" "ddev-web" {
  url = "http://localhost:8080"
  # ...
}
```

## What to Do Next

### If Host Header IS Forwarded

Configure DDEV to accept the Coder hostname:

```bash
# In your DDEV project directory
ddev config --additional-fqdns=ddev-web--workspace--user--id.coder.domain
ddev restart
```

Update `global_config.yaml` to remove direct port binding:
```yaml
# Remove these lines:
# host_webserver_port: "8080"
# host_https_port: "8443"
```

Update `template.tf`:
```hcl
resource "coder_app" "ddev-web" {
  url = "http://localhost:80"  # Use router
  # ...
}
```

### If Host Header is NOT Forwarded

Keep the current approach using direct binding:

```yaml
# In global_config.yaml:
host_webserver_port: "8080"
host_https_port: "8443"
```

```hcl
# In template.tf:
resource "coder_app" "ddev-web" {
  url = "http://localhost:8080"  # Direct to web container
  # ...
}
```

## Alternative: Manual curl test

You can also test manually from within the workspace:

```bash
# Start DDEV
ddev start

# Test with DDEV hostname (should work)
curl -v -H "Host: myproject.ddev.site" http://localhost:80

# Test without Host header (will likely fail with 404)
curl -v http://localhost:80
```

If the first succeeds and second fails, the router is working correctly and just needs the proper hostname configured.
