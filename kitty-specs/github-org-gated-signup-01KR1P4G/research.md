# Research: GitHub Org-Gated Signup

## How Coder server configuration is applied

**Decision**: Edit `/etc/coder.d/coder.env` on the server host, then `sudo systemctl restart coder`.

**Rationale**: Coder is installed via the apt deb package, which installs a systemd unit that reads `/etc/coder.d/coder.env` at startup. This file is the canonical location for all runtime env vars. It is not committed to this repo — credentials and environment-specific values stay on the host.

**Alternatives considered**: Terraform-managed env injection (not applicable here — Terraform manages workspace templates, not the Coder server itself).

---

## One OAuth App vs. two for staging and production

**Decision**: Two separate OAuth Apps — one for staging-coder.ddev.com, one for coder.ddev.com.

**Rationale**: Separate apps mean staging credentials cannot be used against production. Secret rotation on one environment does not affect the other. Aligns with the charter's staging-first validation constraint (C-004).

**Alternatives considered**: Single app with both callback URLs — simpler to manage but couples the two environments' credentials.

---

## Custom OAuth App vs. Coder's default app

**Decision**: Custom DDEV-owned GitHub OAuth App registered under the `ddev` org.

**Rationale**: Coder's documentation explicitly recommends custom apps for production: "For production environments, we strongly recommend that you configure your own GitHub OAuth app to ensure that your data is not shared with Coder (the company)." The default app routes org membership data through Coder's infrastructure.

**Alternatives considered**: Default Coder app — zero setup, but shares org data with Coder the company.

---

## Private org membership and `read:org` scope

**Decision**: Private org membership works with `read:org` scope. Users do not need to publicize their `ddev` or `coder-ddev-com` membership.

**Rationale**: The `read:org` OAuth scope allows the app to read organization membership regardless of visibility setting. GitHub's API returns private membership when this scope is granted. This satisfies NFR-002.

**Warning already documented in server-setup.md**: Do not enable Device Flow (`CODER_OAUTH2_GITHUB_DEVICE_FLOW=true`) alongside `ALLOWED_ORGS` — device flow does not request `read:org` and org membership checks fail with 403.

---

## Required env vars summary

```bash
# /etc/coder.d/coder.env additions (staging and production, separate client IDs/secrets)
CODER_OAUTH2_GITHUB_CLIENT_ID=<app-client-id>
CODER_OAUTH2_GITHUB_CLIENT_SECRET=<app-client-secret>
CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS=true
CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev,coder-ddev-com
# CODER_OAUTH2_GITHUB_DEVICE_FLOW must NOT be set to true
# CODER_DISABLE_PASSWORD_AUTH must NOT be set to true
```

---

## GitHub org for OAuth App ownership

**Decision**: Register the OAuth Apps under the `ddev` GitHub organization.

**Rationale**: Apps registered under an org show "by ddev" on the authorization screen instead of "by \<personal-username\>". Institutional ownership means the app persists even if the registering individual leaves the org. Existing `docs/admin/server-setup.md` already documents this pattern.

---

## What files in this repo change

| File | Change |
| ---- | ------ |
| `docs/admin/server-setup.md` | Update `ALLOWED_ORGS` value, add staging OAuth App section, document `coder-ddev-com` org |
| `docs/admin/user-management.md` | Add "Access Management" section: how to add users to `coder-ddev-com`, how to pre-create password exception accounts |

No Terraform, shell, or Dockerfile changes needed.

---

## $100+/month sponsor GitHub org names

**Finding**: The `ddev/sponsorship-data` `invoiced-sponsorships.jsonc` file records billing tiers and company names in comments but no `github_org` field. Slugs resolved by GitHub API lookup below.

### Confirmed — GitHub org verified

| Company | Monthly equiv. | GitHub org slug |
| ------- | -------------- | --------------- |
| Tag1 | $1,000 | `tag1consulting` |
| Upsun / Platform.sh | ~$1,162 | `upsun` and `platformsh` (Platform.sh rebranded to Upsun; both orgs added) |
| 8mylez | ~$96 (annual $1,153) | `8mylez` — included at operator discretion despite being slightly under $100/month equivalent |
| dkd Internet Service GmbH | $100 (GitHub Sponsors) | `dkd` |
| Liip | $100 (GitHub Sponsors) | `liip` |
| Institute for Advanced Studies | $500 | `Institute-for-Advanced-Studies` (org exists; no public name/description to confirm — needs operator verification) |
| CPS-IT | ~$118 | `CPS-IT` |
| Redfin Solutions | $100 | `redfinsolutions` |
| Lullabot | ~$167 (annual $2k) | `Lullabot` |
| B13 | ~$167 (annual $2k) | `b13` |
| Pixel & Tonic | $100 (annual $1.2k) | `pixelandtonic` |
| Cambrico | $100 (annual $1.2k) | `Cambrico` |
| Centarro | $100 (annual $1.2k) | `centarro` |

### No GitHub org found — excluded

| Company | Monthly equiv. | Notes |
| ------- | -------------- | ----- |
| LetsTalk | $100 | `lets-talk` GitHub org exists but is not the correct org for this sponsor; no confirmed GitHub org found — individual access via `coder-ddev-com` membership instead |

### GitHub Sponsors individual at $100/month

One individual (not an org) sponsors at $100/month via GitHub Sponsors. Because they have a personal account (not a GitHub org), they cannot be added to `CODER_OAUTH2_GITHUB_ALLOWED_ORGS`. Grant access by adding their GitHub username to the `coder-ddev-com` org directly.

Identified as `dougvann` via [ddev/ddev.com#626](https://github.com/ddev/ddev.com/pull/626). Add `dougvann` to `coder-ddev-com` org directly after org creation.

### Resulting `ALLOWED_ORGS` value (staging/production)

```bash
CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev,coder-ddev-com,tag1consulting,upsun,platformsh,Institute-for-Advanced-Studies,CPS-IT,redfinsolutions,Lullabot,b13,pixelandtonic,Cambrico,centarro,8mylez,dkd,liip
# LetsTalk: no confirmed GitHub org — add individuals to coder-ddev-com instead
# dougvann ($100/month individual GitHub Sponsor): add to coder-ddev-com directly
```
