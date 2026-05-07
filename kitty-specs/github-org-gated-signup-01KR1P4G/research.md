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

**Finding**: The `ddev/sponsorship-data` `invoiced-sponsorships.jsonc` file records billing tiers and company names in comments but contains no `github_org` field. GitHub org slugs must be resolved manually.

**Known $100+/month invoiced sponsors** (from the data file comments) that need GitHub org slug mapping:

| Company | Monthly amount | GitHub org slug (TBD) |
| ------- | -------------- | --------------------- |
| cps-it | ~$118 | TBD |
| Redfin Solutions | $100 | TBD |
| LetsTalk | $100 | TBD |
| Institute for Advanced Studies | $500 | TBD |
| Tag1 | $1,000 | TBD |
| Upsun | ~$1,162 | TBD |
| B13 | annual ($2,000/yr) | TBD |
| Lullabot | annual ($2,000/yr) | TBD |
| 8mylez | annual (~$1,153/yr) | TBD |
| Cambrico | annual ($1,200/yr) | TBD |
| Centarro | annual ($1,200/yr) | TBD |
| Pixel & Tonic | annual ($1,200/yr) | TBD |

**Action required (operator)**: Confirm GitHub org slug for each before adding to `ALLOWED_ORGS`. Some may not have a GitHub org (individuals or companies without a public GitHub presence).

**GitHub Sponsors orgs** (sponsoring via github.com/sponsors/ddev at $100+/month tier): requires a token with `read:user` scope on the `ddev` org owner account to enumerate via the GraphQL API. Out of scope for this mission's automated resolution — resolve manually or in a follow-up.
