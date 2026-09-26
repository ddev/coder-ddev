# Data Model — Workspace Runtime Contract

This document enumerates the durable entities of the runtime contract. Each entity is one invariant (INV-1…INV-9) plus its attributes and the relationships that bind it to other invariants.

## Entities

### INV-1 — SysboxRuntime
- **Attributes:** `runtime = "sysbox-runc"`, `privileged = false`, `apparmor = unconfined`, `seccomp = unconfined`.
- **Source of truth:** `user-defined-web/template.tf` (`docker_container.workspace` block).
- **Host precondition:** Sysbox installed and registered as a Docker runtime.

### INV-2 — WorkspaceIdentity
- **Attributes:** username `coder`, UID `1000`, primary group `coder`, supplementary group `docker` (default GID `988`, overridable via `var.docker_gid`).
- **Established by:** image `usermod -l coder` + HCL `user = "coder"` + `group_add` + agent env `HOME=/home/coder`.

### INV-3 — SudoPosture
- **Attributes:** entry `coder ALL=(ALL) NOPASSWD:ALL`, sudoers file mode `0440`, `DEBIAN_FRONTEND` preserved.
- **Source of truth:** `image/Dockerfile` sudoers RUN block.
- **Threat-model assumption:** workspace boundary = Sysbox; in-container UID separation is not a defense.

### INV-4 — DockerdLifecycle
- **Attributes:** in-container daemon, started by agent (`sudo dockerd &`), log at `/tmp/dockerd.log`, socket at `/var/run/docker.sock`, socket widened to `chmod 666` after readiness, optional `/etc/docker/daemon.json` registry mirror.
- **Forbidden:** host docker socket mount; systemd-as-PID-1 path.

### INV-5 — VolumeModel
- **Attributes:**
  - Home: host bind `/coder-workspaces/<owner>-<ws>` → `/home/coder`.
  - DinD: named volume `coder-<owner>-<ws>-dind-cache` → `/var/lib/docker`.
  - No other persistent mounts; no host docker.sock.
- **Persistence semantics:** both volumes survive container stop/start; home is host-managed; DinD is Docker-managed.

### INV-6 — HydrationModel
- **Attributes:** staging dir `/home/coder-files/` (outside the bind mount), policy "copy-if-missing, append-if-missing", first-boot marker `~/.bashrc absent`, every step idempotent.
- **Consumed files (today):** `WELCOME.txt`, `.vscode/settings.json`, `.gitconfig`, `.gitignore_global`. Drift D-2 enumerates files staged but uncopied.

### INV-7 — RoutingModel
- **Attributes:** `ddev-router` globally omitted, project web container binds `localhost:80`, single project per workspace, external access only via Coder reverse tunnel + `coder_app.ddev-web` (subdomain).
- **Deviation:** the `freeform` template runs ddev-router and has its own contract; this spec does not govern freeform.

### INV-8 — CleanupModel
- **Attributes:** stop tears down container (count-gated), preserves both volumes; destroy must remove `/coder-workspaces/<owner>-<ws>/` via `null_resource.workspace_cleanup` invoking host-side `coder-delete-workspace-dir`. Stop is graceful: `SIGINT`, `stop_timeout = 180s`, `destroy_grace_seconds = 60s`. Two shutdown hooks run `ddev poweroff` (agent + `coder_script` with `run_on_stop=true`).
- **Host precondition:** `/usr/local/bin/coder-delete-workspace-dir` installed with passwordless sudo for the daemon user.

### INV-9 — IdentitySourceModel
- **Authoritative source:** `coder_agent.env` injects `CODER_WORKSPACE_{ID,NAME,OWNER_NAME,OWNER_EMAIL}`.
- **Forbidden as source:** container `hostname` (it is `<ws-name>-<owner>`; container name is `coder-<id>`; mismatch makes hostname parsing unreliable).
- **Used by:** git config injection, DDEV project naming, dashboard metadata.

## Relationships

| From | Relation | To |
|------|----------|-----|
| INV-1 | enables safe execution of | INV-4 |
| INV-2 | required by | INV-3, INV-4, INV-5 |
| INV-3 | required by | INV-4 (dockerd launch), INV-5 (chown), INV-6 (hydration writes) |
| INV-4 | persists state via | INV-5 (`/var/lib/docker` volume) |
| INV-5 | shadows image content, necessitating | INV-6 |
| INV-6 | populates state in scope of | INV-2 (user-owned files) |
| INV-7 | exposed to users via | `coder_app.ddev-web` |
| INV-8 | depends on host-side helper named in | charter §"Important Constraints" |
| INV-9 | consumed by every step that names a workspace, including | INV-6 (git identity), INV-7 (DDEV project naming) |

## Invariant Coverage Matrix

| Invariant | Image enforces | HCL enforces | Script enforces |
|----------:|:--------------:|:------------:|:---------------:|
| INV-1     |                |     yes      |                 |
| INV-2     |     yes        |     yes      |     yes (chown) |
| INV-3     |     yes        |              |     yes (uses)  |
| INV-4     |     yes (binary) | yes (no socket mount) | yes (start) |
| INV-5     |                |     yes      |                 |
| INV-6     |     yes (stages) |            |     yes (hydrate) |
| INV-7     |     yes (ddev install) | yes (coder_app) | (relies on DDEV global config) |
| INV-8     |                |     yes      |     yes (shutdown) |
| INV-9     |                |     yes (env) |    yes (uses) |

## Drift Catalog (informational)

See `research.md` §"Known Drift" for D-1…D-6. They are **not** modeled as entities here; they are flagged anomalies that will become OpenSpec change proposals in their own missions.
