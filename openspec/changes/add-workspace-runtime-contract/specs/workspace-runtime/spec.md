## ADDED Requirements

### Requirement: Sysbox Container Runtime
Workspace containers SHALL run under the `sysbox-runc` Docker runtime, MUST NOT be privileged, and SHALL set `apparmor:unconfined` and `seccomp:unconfined` security options so that the nested Docker daemon can operate safely without `--privileged`.

#### Scenario: Workspace container declares Sysbox runtime
- **WHEN** a workspace is provisioned from any `coder-ddev` template
- **THEN** the underlying `docker_container` resource SHALL declare `runtime = "sysbox-runc"`
- **AND** SHALL declare `privileged = false`
- **AND** SHALL declare `security_opts = ["apparmor:unconfined", "seccomp:unconfined"]`

#### Scenario: Host without Sysbox refuses provisioning
- **WHEN** the Coder host does not have the `sysbox-runc` runtime registered
- **THEN** `terraform apply` SHALL fail with a Docker runtime error
- **AND** no partial workspace container SHALL be created

---

### Requirement: Workspace User Identity
The container SHALL run as the `coder` user (UID 1000), with `HOME=/home/coder` forced through agent environment variables, and SHALL receive the host docker group as a supplementary group via the parametric `docker_gid` variable.

#### Scenario: Container starts as coder
- **WHEN** a workspace container starts
- **THEN** the container process SHALL run as user `coder` (UID 1000)
- **AND** `HOME` SHALL be `/home/coder`
- **AND** the process SHALL be a member of the supplementary group whose GID equals `var.docker_gid` (default 988)

#### Scenario: Image identity matches HCL identity
- **WHEN** the base image is built
- **THEN** the image SHALL rename the stock Ubuntu user to `coder` while preserving UID 1000

---

### Requirement: NOPASSWD Sudo Posture
The `coder` user SHALL have unrestricted passwordless sudo (`coder ALL=(ALL) NOPASSWD:ALL`) so the agent startup script can start `dockerd`, repair home ownership, write `/etc/docker/daemon.json`, and adjust the docker socket without interactive prompts. The privilege boundary SHALL be the Sysbox runtime, not in-container UID separation.

#### Scenario: Sudoers entry exists with correct mode
- **WHEN** the base image is built
- **THEN** `/etc/sudoers.d/coder` SHALL contain `coder ALL=(ALL) NOPASSWD:ALL`
- **AND** SHALL have mode `0440`
- **AND** SHALL preserve `DEBIAN_FRONTEND` via `Defaults env_keep`

#### Scenario: Agent script can sudo without prompt
- **WHEN** the agent `startup_script` invokes `sudo dockerd` or `sudo chown` or `sudo tee /etc/docker/daemon.json`
- **THEN** each invocation SHALL succeed without an interactive password prompt

---

### Requirement: In-Container Dockerd Lifecycle
The Docker daemon SHALL run inside the workspace container, SHALL be started by the agent `startup_script` (not by systemd-as-PID-1), SHALL log to `/tmp/dockerd.log`, SHALL expose `/var/run/docker.sock` to the `coder` user, and SHALL persist state under `/var/lib/docker` (backed by the named volume defined in the Volume Model requirement). The host Docker socket MUST NOT be mounted into the workspace.

#### Scenario: Dockerd is started by the agent on first boot
- **WHEN** the agent `startup_script` runs and `pgrep -x dockerd` returns nothing
- **THEN** the script SHALL invoke `sudo dockerd > /tmp/dockerd.log 2>&1 &`
- **AND** SHALL poll `/var/run/docker.sock` for readiness with a bounded timeout
- **AND** SHALL relax socket permissions so the `coder` user can communicate with the daemon

#### Scenario: Host docker socket is never mounted
- **WHEN** the `docker_container.workspace` resource is rendered
- **THEN** it MUST NOT declare a `volumes` or `mounts` block whose target is `/var/run/docker.sock`
- **AND** no host path SHALL be exposed at that container path

#### Scenario: Registry mirror is applied before daemon start
- **WHEN** the agent detects a reachable registry mirror or `var.docker_registry_mirror` is non-empty
- **THEN** the script SHALL write `/etc/docker/daemon.json` with the mirror configuration before invoking `dockerd`
- **AND** subsequent `docker pull` calls SHALL use the mirror

---

### Requirement: Two-Volume Persistence Model
Each workspace SHALL be backed by exactly two persistent surfaces: a host bind mount at `/coder-workspaces/<owner>-<ws>` mapped to `/home/coder`, and a named Docker volume `coder-<owner>-<ws>-dind-cache` mapped to `/var/lib/docker`. No other persistent mounts SHALL be added by the template.

#### Scenario: Home is a host bind mount
- **WHEN** the workspace container is created
- **THEN** the container path `/home/coder` SHALL be backed by the host directory `/coder-workspaces/<owner>-<ws>`
- **AND** the bind SHALL be writable

#### Scenario: Dockerd storage is a named volume
- **WHEN** the workspace container is created
- **THEN** the container path `/var/lib/docker` SHALL be backed by a Docker named volume whose name encodes the workspace owner and slug
- **AND** the volume SHALL survive container replacement (image bump, stop/start)

#### Scenario: No additional persistent mounts
- **WHEN** the workspace template HCL is rendered
- **THEN** the `docker_container.workspace` resource SHALL declare exactly one `volumes` block (home bind) and exactly one `mounts` block (DinD volume)

---

### Requirement: Copy-If-Missing Home Hydration
On every agent start, the workspace SHALL hydrate `/home/coder` from `/home/coder-files/` (staged outside the bind mount at image build time) using a "copy-if-missing, append-if-missing" policy. User edits MUST NOT be overwritten. Hydration steps SHALL be idempotent.

#### Scenario: First-boot hydration
- **WHEN** the agent starts and `~/.bashrc` does not exist
- **THEN** the script SHALL seed the home directory from `/etc/skel/`
- **AND** SHALL copy any image-supplied skeleton from `/home/coder-files/` into the user's home

#### Scenario: Subsequent boot preserves user state
- **WHEN** the agent starts and `~/.bashrc` already exists with user modifications
- **THEN** copy steps SHALL be skipped for any file whose target already exists
- **AND** append steps SHALL be guarded by `grep -q` or equivalent so duplicate entries are not written

#### Scenario: Missing staging directory is non-fatal
- **WHEN** `/home/coder-files/` is absent from the image
- **THEN** the script SHALL log a warning and continue without aborting

---

### Requirement: Direct-Bind Single-Project Web Routing
For templates governed by this contract (`user-defined-web`, `drupal-core`, `drupal-contrib`), DDEV SHALL be configured globally with `--omit-containers=ddev-router`; the active project's web container SHALL bind directly to `localhost:80` inside the workspace; and external access SHALL flow through Coder's reverse tunnel via a `coder_app` advertisement (with `subdomain = true`). At most one DDEV project SHALL be running per workspace.

#### Scenario: ddev-router is omitted globally
- **WHEN** the agent has finished initialization
- **THEN** `~/.ddev/global_config.yaml` SHALL declare `omit_containers: [ddev-router]`

#### Scenario: Dashboard exposes localhost:80
- **WHEN** the workspace HCL is rendered
- **THEN** a `coder_app` resource SHALL advertise `url = "http://localhost:80"` with `subdomain = true`
- **AND** a healthcheck SHALL be declared against that URL

#### Scenario: Container publishes no host ports
- **WHEN** the `docker_container.workspace` resource is rendered
- **THEN** it SHALL NOT declare a `ports` block

---

### Requirement: Host-Aware Cleanup
Stopping a workspace SHALL tear down the container while preserving both persistent volumes. Deleting a workspace SHALL also remove the host bind-mount root `/coder-workspaces/<owner>-<ws>/` via a `null_resource` destroy provisioner that invokes the host-side helper `/usr/local/bin/coder-delete-workspace-dir` with passwordless sudo. Stop SHALL be graceful enough that `ddev poweroff` can complete.

#### Scenario: Stop preserves volumes
- **WHEN** a workspace transitions to `start_count = 0`
- **THEN** the `docker_container` resource SHALL be destroyed by Terraform
- **AND** the host bind directory SHALL remain
- **AND** the named DinD volume SHALL remain

#### Scenario: Delete removes the host directory
- **WHEN** a workspace is destroyed via `terraform destroy` or `coder delete`
- **THEN** the `null_resource.workspace_cleanup` destroy provisioner SHALL invoke `sudo /usr/local/bin/coder-delete-workspace-dir` with the host bind path
- **AND** the directory SHALL be removed before the workspace is considered deleted

#### Scenario: Graceful stop allows ddev poweroff
- **WHEN** a stop is initiated
- **THEN** the container SHALL receive `SIGINT`
- **AND** SHALL be given `stop_timeout = 180s` and `destroy_grace_seconds = 60s`
- **AND** the `coder_script` shutdown hook SHALL run `ddev poweroff` with a docker-socket race guard

---

### Requirement: Env-Sourced Workspace Identity
The authoritative source of workspace identity (`CODER_WORKSPACE_ID`, `CODER_WORKSPACE_NAME`, `CODER_WORKSPACE_OWNER_NAME`, `CODER_WORKSPACE_OWNER_EMAIL`) SHALL be the agent `env` block injected via `coder_agent.env`. Container `hostname` parsing MUST NOT be used as an identity source in new code.

#### Scenario: Agent env carries identity
- **WHEN** the workspace agent starts
- **THEN** the four `CODER_WORKSPACE_*` environment variables SHALL be exported into every agent-spawned shell
- **AND** git global `user.name` and `user.email` SHALL be set from `CODER_WORKSPACE_OWNER_NAME` and `CODER_WORKSPACE_OWNER_EMAIL`

#### Scenario: Hostname is not a valid identity source
- **WHEN** a new contributor adds code that derives workspace identity
- **THEN** that code SHALL read from the env variables above
- **AND** SHALL NOT parse the container `hostname` (which is `<ws-name>-<owner>`, deliberately distinct from the container `name` `coder-<id>`)

---

### Requirement: Required Agent Boot Sequence
The agent `startup_script` SHALL execute the boot steps in the order: (1) repair home ownership, (2) seed skeleton on first boot, (3) configure GitSSH for the current session, (4) hydrate from `/home/coder-files`, (5) apply git identity, (6) configure registry mirror, (7) start `dockerd` and wait for socket, (8) pre-warm DDEV images, (9) ensure standard directories, (10) assemble shell profile. Each step SHALL be idempotent. The script SHALL use `set +e` so a single failure never aborts boot; failures SHALL be logged.

#### Scenario: Mirror precedes dockerd start
- **WHEN** the registry mirror configuration is enabled
- **THEN** `/etc/docker/daemon.json` SHALL be written before `dockerd` is launched
- **AND** the first image pull SHALL go through the mirror

#### Scenario: Hydration precedes shell profile assembly
- **WHEN** the agent boots
- **THEN** files from `/home/coder-files/` SHALL be copied into the home directory before `~/.bash_profile` is assembled
- **AND** `~/.bash_profile` SHALL source `/etc/bash.bashrc` and `~/.bashrc` and display `~/WELCOME.txt` for login shells

#### Scenario: Best-effort boot
- **WHEN** any individual boot step fails (e.g., dockerd timeout)
- **THEN** the script SHALL log the failure
- **AND** SHALL continue to subsequent steps
- **AND** SHALL exit 0

---

### Requirement: Forbidden Runtime Behaviors
The following behaviors SHALL NOT appear in any template, image, or agent script governed by this contract:

- F-1: Mounting the host Docker socket into the workspace.
- F-2: Setting `privileged = true` on the workspace container.
- F-3: Hard-coding UID or GID numerically in scripts (use names `coder` / `docker` and HCL variable `docker_gid`).
- F-4: Persisting `GIT_SSH_COMMAND` to any user dotfile.
- F-5: Overwriting user state in `/home/coder` during hydration.
- F-6: Publishing container ports on the host via the `ports` argument.
- F-7: Adding a new persistent mount without a destroy-time cleanup obligation.
- F-8: Relying on container `hostname` for workspace identity.
- F-9: Starting `dockerd` via `systemd-as-PID-1` (the systemd unit installed by the image is dormant; mixing paths is forbidden).
- F-10: Adding `set -e` to the boot script without re-engineering every failure path.

#### Scenario: Static check rejects forbidden HCL constructs
- **WHEN** a reviewer inspects a PR that modifies a `template.tf`
- **THEN** the PR SHALL be rejected if it adds a host-socket mount (F-1), sets `privileged = true` (F-2), or publishes container ports (F-6)
- **AND** the reviewer SHALL be able to cite the corresponding F-id in the rejection

#### Scenario: Script review rejects forbidden patterns
- **WHEN** a reviewer inspects a PR that modifies the inlined `startup_script`
- **THEN** the PR SHALL be rejected if it persists `GIT_SSH_COMMAND` (F-4), parses `hostname` for identity (F-8), or adds `set -e` (F-10)

---

## Known Drift

The following anomalies exist in the repository at the time this spec lands. They are **informational** and **not enforced** by this contract. Each will become its own follow-up OpenSpec proposal that references the relevant invariant.

- **D-1** — `image/scripts/.ddev/global_config.yaml` is referenced by `CLAUDE.md` but absent from the image tree. Affects Requirement: Direct-Bind Single-Project Web Routing. Source: `CLAUDE.md` Architecture section vs. `image/scripts/` listing.
- **D-2** — `/home/coder-files/.ddev/commands/host/{launch,coder-routes,coder-setup}` are staged by the image but never copied into `~/.ddev/commands/host/` by `user-defined-web/template.tf`. Affects Requirement: Copy-If-Missing Home Hydration. Source: `image/Dockerfile` `COPY scripts` step vs. `user-defined-web/template.tf` `startup_script` hydration block.
- **D-3** — `coder-setup` is missing from the explicit `chmod 755` list after `COPY scripts /home/coder-files` in `image/Dockerfile`. Affects executability of an image-shipped DDEV host command.
- **D-4** — Two `dockerd` start models coexist in the image (`systemctl enable docker` + manual `sudo dockerd` in the agent script). Forbidden behavior F-9 disallows the systemd path; the systemd install will be retired in a follow-up.
- **D-5** — The agent script applies `chmod 666 /var/run/docker.sock` even though `group_add = 988` already grants the `coder` user write access. Broader than necessary; a follow-up will tighten to `chmod 660` after asserting GID alignment at boot.
- **D-6** — `image_version` is a single tag across all four templates; per-template image pinning is not currently supported. Tracked for a future Volume Model extension.
