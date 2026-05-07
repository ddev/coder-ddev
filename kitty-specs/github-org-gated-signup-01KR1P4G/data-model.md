# Data Model: GitHub Org-Gated Signup

## Entities

### GitHub OAuth App
Represents the custom DDEV-owned GitHub OAuth application registered under the `ddev` org.

| Attribute | Type | Notes |
| --------- | ---- | ----- |
| `client_id` | string | Unique per environment (staging vs production) |
| `client_secret` | string | Secret; stored only in `/etc/coder.d/coder.env` on host |
| `owner_org` | string | Always `ddev` (institutional ownership) |
| `callback_url` | string | e.g. `https://coder.ddev.com/api/v2/users/oidc/callback` |
| `scopes` | string[] | `read:user`, `user:email`, `read:org` |

**Notes**: Two separate OAuth App instances exist — one for staging, one for production. Credentials are never committed to this repo.

---

### GitHub Organization
Represents a GitHub org whose members are allowed to create Coder accounts.

| Attribute | Type | Notes |
| --------- | ---- | ----- |
| `org_slug` | string | GitHub org handle (e.g. `ddev`, `coder-ddev-com`) |
| `org_type` | enum | `core` \| `managed-access-list` \| `sponsor` |
| `access_method` | enum | `direct` — members sign in via org membership |
| `added_to_allowed_orgs` | bool | Whether the slug appears in `CODER_OAUTH2_GITHUB_ALLOWED_ORGS` |

**Org type meanings:**
- `core` — `ddev` org; all DDEV contributors. Primary access channel.
- `managed-access-list` — `coder-ddev-com` org; explicitly managed list for individuals outside `ddev`.
- `sponsor` — $100+/month sponsor orgs; members get access without individual enrollment in `coder-ddev-com`.

**Current allowed orgs (27 total):**
`ddev`, `coder-ddev-com`, `tag1consulting`, `upsun`, `platformsh`, `Institute-for-Advanced-Studies`, `CPS-IT`, `redfinsolutions`, `Lullabot`, `b13`, `pixelandtonic`, `Cambrico`, `centarro`, `8mylez`, `dkd`, `liip`, `i-gelb`, `FameHelsinki`, `Gizra`, `mobilistics`, `OPTASY`, `passbolt`, `vaersaagod`, `affinitybridge`, `AGILEDROP`, `NPO-Applications-GmbH`, `AtenDesignGroup`

---

### Coder User
Represents a user account on coder.ddev.com or staging-coder.ddev.com.

| Attribute | Type | Notes |
| --------- | ---- | ----- |
| `username` | string | Coder account identifier |
| `auth_method` | enum | `github-oauth` \| `password` |
| `account_status` | enum | `existing` \| `new` |
| `github_org_membership` | string[] | Orgs the user belongs to (checked at signup) |

**Notes**: Existing accounts created before org-gating are preserved. New signups require org membership. Password-auth accounts remain usable and are never disabled (`CODER_DISABLE_PASSWORD_AUTH` is not set).

---

### Coder Server Environment
Represents the runtime configuration of one Coder server instance.

| Attribute | Type | Notes |
| --------- | ---- | ----- |
| `config_file` | string | `/etc/coder.d/coder.env` |
| `environment` | enum | `staging` \| `production` |
| `CODER_OAUTH2_GITHUB_CLIENT_ID` | string | From OAuth App for this environment |
| `CODER_OAUTH2_GITHUB_CLIENT_SECRET` | string | From OAuth App for this environment |
| `CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS` | bool | Must be `true` |
| `CODER_OAUTH2_GITHUB_ALLOWED_ORGS` | string | Comma-separated org slug list |
| `CODER_OAUTH2_GITHUB_DEVICE_FLOW` | bool | Must NOT be `true` (breaks `read:org`) |
| `CODER_DISABLE_PASSWORD_AUTH` | bool | Must NOT be `true` |

---

## Relationships

```
Coder Server Environment
  └─ uses ──► GitHub OAuth App (one per environment)
                └─ allows ──► GitHub Organization (many, via ALLOWED_ORGS)
                                └─ grants access to ──► Coder User (new signups)

Coder User
  ├─ auth_method: github-oauth  ──► must belong to at least one allowed GitHub org
  └─ auth_method: password      ──► manually pre-created; org membership not checked
```

---

## Configuration Scope

This feature involves **no code changes** — only documentation and operator-applied server configuration:

| Layer | Changes |
| ----- | ------- |
| Terraform templates | None |
| Docker image | None |
| Shell scripts | None |
| Docs (`docs/admin/server-setup.md`) | Update ALLOWED_ORGS, add staging OAuth section, document coder-ddev-com, add sponsor table and runbook |
| Docs (`docs/admin/user-management.md`) | Add Access Management section |
| Docs (`docs/admin/coder-ddev-com/`) | New directory: org profile README, access-requests repo README, issue template, sponsor notification |
| Docs (`docs/admin/blog-post-draft.md`) | Draft diff for ddev.com blog post |
| Server host (out of repo) | `/etc/coder.d/coder.env` on staging then production |
