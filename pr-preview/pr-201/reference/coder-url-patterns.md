# Coder URL and Routing Patterns

Reference for how Coder constructs workspace URLs, what environment variables are available, and how this interacts with DDEV's Traefik router for multi-project routing.

## URL Anatomy

Coder routes workspace traffic in two distinct ways, each producing a different URL pattern.

---

## 1. Named App URLs (`coder_app` with `subdomain = true`)

**Official docs:** The URL construction pattern for named apps is not documented in a single canonical place. The closest references are:

- [coder.com/docs/admin/networking/wildcard-access-url](https://coder.com/docs/admin/networking/wildcard-access-url) — shows the example `8080--main--myworkspace--john.coder.example.com`
- [registry.terraform.io — coder_app resource](https://registry.terraform.io/providers/coder/coder/latest/docs/resources/app) — describes the `subdomain` attribute but does not spell out the URL format
- [coder/coder source: appurl.go](https://github.com/coder/coder/blob/main/coderd/workspaceapps/appurl/appurl.go) — the Go source that generates the subdomain

```text
https://{slug}--{workspace}--{owner}.{wildcard-domain}/
```

When a workspace has only one agent (the normal case), the agent name is omitted. If a workspace defines multiple agents you get:

```text
https://{slug}--{agent}--{workspace}--{owner}.{wildcard-domain}/
```

| Component | Example | Source |
| --------- | ------- | ------ |
| `slug` | `ddev-web`, `mailpit`, `adminer` | `slug` attribute on `coder_app` resource |
| `agent` | `main` | `coder_agent` resource name (only included when multiple agents exist) |
| `workspace` | `myworkspace` | `CODER_WORKSPACE_NAME` |
| `owner` | `rfay` | `CODER_WORKSPACE_OWNER` (username, not display name) |
| `wildcard-domain` | `coder.ddev.com` | `CODER_WILDCARD_ACCESS_URL` minus the leading `*.` |

**Example** — a `coder_app` with `slug = "mailpit"` in workspace `myworkspace` owned by `rfay`:

```text
https://mailpit--myworkspace--rfay.coder.ddev.com/
```

The Coder server terminates TLS and reverse-proxies to the `url` configured on the `coder_app` (e.g. `http://localhost:8025`). The wildcard TLS certificate must cover `*.coder.ddev.com`.

**Scheme correction (X-Forwarded-Proto):** Because Coder terminates TLS and forwards to DDEV's Traefik over plain HTTP entrypoints (`tls: false`), Traefik would otherwise hand the backend `X-Forwarded-Proto: http`. Apps behind these routes (the TYPO3 backend, Vite/Astro dev servers, etc.) then generate `http://` URLs, and browsers break on the resulting `https://`→`http://` downgrade — e.g. TYPO3 throws `MissingReferrerException` on `/typo3/` because the browser drops the `Referer` header. To prevent this, `coder-routes` attaches a Traefik `headers` middleware (`{project}-coder-https`) to every generated router that forces `X-Forwarded-Proto: https` (plus `X-Forwarded-Ssl: on`, `X-Forwarded-Port: 443`), restoring the real external scheme the backend sees.

**`share` options** — controls who can open the URL:

| Value | Access |
| ----- | ------ |
| `"owner"` | Workspace owner only (default) |
| `"authenticated"` | Any logged-in Coder user |
| `"public"` | Anyone with the URL |

**Limits:** No documented per-workspace limit on `coder_app` resources. Use the `order` attribute (integer) and `group` attribute (string, max 64 chars) to control dashboard layout.

---

## 2. Dashboard Port-Forwarding URLs (dynamic, no `coder_app` needed)

**Official docs:** [coder.com/docs/admin/networking/port-forwarding](https://coder.com/docs/admin/networking/port-forwarding)

Any port in the workspace can be forwarded on demand from the Coder dashboard without declaring a `coder_app`. The URL pattern always includes the agent name:

```text
https://{port}--{agent}--{workspace}--{owner}.{wildcard-domain}/
```

For HTTPS (port gets TLS passthrough from Coder):

```text
https://{port}s--{agent}--{workspace}--{owner}.{wildcard-domain}/
```

**Example** — port 3000 on agent `main` in workspace `myworkspace`:

```text
https://3000--main--myworkspace--rfay.coder.ddev.com/
```

> **Note:** Each hostname segment must not exceed 63 characters (DNS label limit). Long workspace or owner names can push past this limit, disabling dashboard port forwarding for that port. CLI port forwarding is unaffected.

---

## 3. CLI Port Forwarding (localhost only)

```bash
# Single port
coder port-forward myworkspace --tcp 8080:80

# Multiple ports / ranges
coder port-forward myworkspace --tcp 3000,9990-9999

# Agent-qualified (multi-agent workspaces)
coder port-forward myworkspace.main --tcp 8080:80
```

Traffic arrives at `http://localhost:{local-port}` — no Coder domain involved. This bypasses TLS and the wildcard domain entirely.

---

## 4. SSH Port Forwarding

```bash
ssh -L 8080:localhost:8000 coder.myworkspace
```

Standard OpenSSH local port forwarding through Coder's SSH proxy. Also localhost-only.

---

## Environment Variables in Workspaces

### Identity

Variables marked **[native]** are injected by the Coder agent automatically. Variables marked **[template]** are set via `env` blocks in the `coder_agent` resource and may differ between templates.

| Variable | Example | Description |
| -------- | ------- | ----------- |
| `CODER_WORKSPACE_NAME` | `myworkspace` | Workspace name **[native]** |
| `CODER_WORKSPACE_ID` | `<uuid>` | Workspace UUID **[native]** |
| `CODER_WORKSPACE_TRANSITION` | `start` | `start` or `stop` **[native]** |
| `CODER_WORKSPACE_OWNER_NAME` | `rfay` | Owner **username** (set from `data.coder_workspace_owner.me.name` in this template) **[template]** |
| `CODER_WORKSPACE_OWNER_EMAIL` | `accounts@ddev.com` | Owner email **[template]** |

> **Important:** In the drupal-core and freeform templates, `CODER_WORKSPACE_OWNER_NAME` holds the **username** (e.g. `rfay`), not the display name. It is set from `data.coder_workspace_owner.me.name` in the `coder_agent` env block. This is what the `coder-routes` script uses to build Host-header rules.

### Template / Build

| Variable | Example | Description |
| -------- | ------- | ----------- |
| `CODER_WORKSPACE_TEMPLATE_NAME` | `freeform` | Template name |
| `CODER_WORKSPACE_TEMPLATE_VERSION` | `v1.2.3` | Template version |

### Agent

| Variable | Description |
| -------- | ----------- |
| `CODER_AGENT_TOKEN` | Agent auth token |
| `CODER_AGENT_NAME` | Agent name (e.g. `main`) |
| `CODER_AGENT_URL` | Coder server base URL — e.g. `https://coder.ddev.com` |

### IDE/Proxy

| Variable | Example | Description |
| -------- | ------- | ----------- |
| `VSCODE_PROXY_URI` | `https://vscode-web--myworkspace--rfay.coder.ddev.com/proxy/{{port}}/` | VS Code proxy template URI; `{{port}}` is replaced at runtime |

### Deriving the wildcard domain at runtime

The wildcard domain is **not** directly injected as an env var, but can be extracted from `VSCODE_PROXY_URI` or `CODER_AGENT_URL`:

```bash
# From VSCODE_PROXY_URI (preferred — always a subdomain of the wildcard domain)
DOMAIN=$(echo "$VSCODE_PROXY_URI" | sed -E 's|https?://[^.]+\.(.+?)(/.*)?$|\1|')

# Fallback: from CODER_AGENT_URL (the Coder server hostname, not the wildcard domain)
DOMAIN=$(echo "$CODER_AGENT_URL" | sed -E 's|https?://(.+?)(/.*)?$|\1|')
```

Once you have `DOMAIN`, `CODER_WORKSPACE_NAME`, and `CODER_WORKSPACE_OWNER_NAME`, you can construct any app URL:

```bash
echo "https://${slug}--${CODER_WORKSPACE_NAME}--${CODER_WORKSPACE_OWNER_NAME}.${DOMAIN}"
```

---

## Server Configuration Requirements

| Setting | Value | Purpose |
| ------- | ----- | ------- |
| `CODER_ACCESS_URL` | `https://coder.ddev.com` | Main Coder UI |
| `CODER_WILDCARD_ACCESS_URL` | `*.coder.ddev.com` | Workspace app subdomains |
| TLS cert SANs | `coder.ddev.com`, `*.coder.ddev.com` | Required; DNS-01 challenge for wildcard |

The wildcard `*.coder.ddev.com` covers one level of subdomain only. Dashboard port-forwarding URLs like `8080--main--myworkspace--rfay.coder.ddev.com` are still a single-level subdomain of `coder.ddev.com`, so the wildcard cert covers them.

**Official docs:** [coder.com/docs/admin/networking/wildcard-access-url](https://coder.com/docs/admin/networking/wildcard-access-url), [coder.com/docs/admin/setup](https://coder.com/docs/admin/setup)
