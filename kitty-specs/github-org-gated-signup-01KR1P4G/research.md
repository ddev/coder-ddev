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

### Confirmed — add to `ALLOWED_ORGS`

All featured sponsors on ddev.com are at the $100/month level. MacStadium and JetBrains are in-kind (not cash) sponsors and are excluded. The ddev.com sponsor link for Webikon points to the individual `claudiu-cristea`, so the org is excluded and the individual gets `coder-ddev-com` membership instead.

| Company | Source | GitHub org slug |
| ------- | ------ | --------------- |
| Tag1 | invoiced | `tag1consulting` |
| Upsun | invoiced | `upsun` |
| Platform.sh (rebranded to Upsun) | invoiced | `platformsh` |
| Institute for Advanced Studies | invoiced | `Institute-for-Advanced-Studies` ⚠️ org exists but unverified — confirm with operator |
| CPS-IT | invoiced | `CPS-IT` |
| Redfin Solutions | invoiced + featured | `redfinsolutions` |
| Lullabot | invoiced | `Lullabot` |
| B13 | invoiced + featured | `b13` |
| Pixel & Tonic (Craft CMS) | invoiced + featured | `pixelandtonic` |
| Cambrico | invoiced + featured | `Cambrico` |
| Centarro | invoiced + featured | `centarro` |
| 8mylez | invoiced | `8mylez` |
| dkd Internet Service GmbH | GitHub Sponsors | `dkd` |
| Liip | GitHub Sponsors | `liip` |
| i-gelb GmbH | featured | `i-gelb` |
| Fame Helsinki | featured | `FameHelsinki` |
| Gizra | featured | `Gizra` |
| mobilistics GmbH | featured | `mobilistics` |
| OPTASY | featured | `OPTASY` |
| Passbolt | featured | `passbolt` |
| Værsågod | featured | `vaersaagod` |
| Affinity Bridge | featured | `affinitybridge` |
| Agiledrop | featured | `AGILEDROP` |
| NPO Applications GmbH | featured | `NPO-Applications-GmbH` |
| Aten Design Group | featured | `AtenDesignGroup` |

### Individual/unresolved — add to `coder-ddev-com` org

| Sponsor | Notes |
| ------- | ----- |
| `dougvann` | Individual $100/month GitHub Sponsor — confirmed via [ddev/ddev.com#626](https://github.com/ddev/ddev.com/pull/626) |
| claudiu-cristea (Webikon) | ddev.com sponsor link points to individual, not org |
| LetsTalk | No confirmed GitHub org (`lets-talk` is wrong org); add individual GitHub username when known |
| Amedick Sommer | No GitHub org found; add individual GitHub username when known |
| Pottkinder GmbH | No GitHub org found; add individual GitHub username when known |

### Excluded

| Sponsor | Reason |
| ------- | ------ |
| MacStadium | In-kind (hardware), not cash sponsor |
| JetBrains | In-kind (licenses), not cash sponsor |

### Resulting `ALLOWED_ORGS` value (staging/production)

```bash
CODER_OAUTH2_GITHUB_ALLOWED_ORGS=ddev,coder-ddev-com,tag1consulting,upsun,platformsh,Institute-for-Advanced-Studies,CPS-IT,redfinsolutions,Lullabot,b13,pixelandtonic,Cambrico,centarro,8mylez,dkd,liip,i-gelb,FameHelsinki,Gizra,mobilistics,OPTASY,passbolt,vaersaagod,affinitybridge,AGILEDROP,NPO-Applications-GmbH,AtenDesignGroup
# Webikon: sponsor link is individual claudiu-cristea — add to coder-ddev-com instead
# LetsTalk, Amedick Sommer, Pottkinder GmbH: no GitHub org — add individuals to coder-ddev-com when known
```
