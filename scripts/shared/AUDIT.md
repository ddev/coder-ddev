# scripts/shared/ — Audit & Helper Inventory

This document records what `scripts/shared/` contains, why each helper exists,
and where each helper stands on adoption (sourcing vs. invocation) across the
four per-template `startup.sh` files produced by WP02–WP05.

## TL;DR

- 4 function-only helper libraries live under `scripts/shared/`.
- All 4 per-template `startup.sh` scripts source all 4 helpers via the
  `[ -f "${SHARED_DIR}/${_helper}.sh" ] && . "${SHARED_DIR}/${_helper}.sh"`
  loop installed in WP02–WP05.
- **Adoption of the helper functions is deferred.** Sourcing is a no-op (the
  helpers only define bash functions); per-template scripts still run their
  original inline implementations. A follow-up issue will replace each
  duplicated inline block with a call to the corresponding helper function
  once we can run live boot-time smoke tests across all four templates.

## Helper inventory

| Helper | Function defined | Templates that source it | Decision |
| ------ | ---------------- | ------------------------ | -------- |
| `start-dockerd.sh` | `start_dockerd` | freeform, user-defined-web, drupal-contrib, drupal-core | EXTRACT (adoption deferred) |
| `hydrate-coder-files.sh` | `hydrate_coder_files` | freeform, user-defined-web, drupal-contrib, drupal-core | EXTRACT (adoption deferred) |
| `install-ddev-config.sh` | `install_ddev_config` | freeform, user-defined-web, drupal-contrib, drupal-core | EXTRACT (adoption deferred) |
| `configure-git-ssh.sh` | `configure_git_ssh` | freeform, user-defined-web, drupal-contrib, drupal-core | EXTRACT (adoption deferred) |

Each helper is **sourced by ≥ 2 templates** (in fact by all 4), satisfying
Success Criterion #4 in [`spec.md`](../../kitty-specs/extract-template-startup-scripts-01KRCDD7/spec.md).

## Audit findings — recurring conceptual blocks

The four per-template `startup.sh` files vary widely in total size:

| Template            | LOC |
| ------------------- | --- |
| freeform            | 253 |
| user-defined-web    | 368 |
| drupal-contrib      | 726 |
| drupal-core         | 953 |

Most of the variance is template-specific project bootstrap logic (DDEV project
setup, Drupal core checkout, contrib module hydration, etc.). The infrastructure
prelude is what overlaps. Inspection of all four scripts confirmed the
following recurring conceptual blocks:

### 1. Docker daemon bring-up — `start-dockerd.sh`

All four scripts contain a `pgrep -x dockerd` guard followed by
`sudo dockerd > /tmp/dockerd.log 2>&1 &` and a wait loop on
`/var/run/docker.sock` with a timeout. Logic is functionally equivalent across
templates with minor formatting differences.

**Helper contract:** `start_dockerd` is idempotent (returns 0 immediately if
the socket is already responsive), parameterised by `DOCKER_SOCKET`,
`DOCKERD_TIMEOUT_SECONDS`, and `DOCKERD_LOG` env vars. Exit codes 0/2/3.

### 2. /home/coder-files hydration — `hydrate-coder-files.sh`

All four scripts copy from `/home/coder-files/` into `$HOME` for the same set
of artefacts: `WELCOME.txt`, `.vscode/settings.json`, `.gitconfig`,
`.gitignore_global`. Each is guarded by an existence check on the destination
to avoid clobbering user state.

**Helper contract:** `hydrate_coder_files` is idempotent (skip-if-present),
parameterised by `CODER_FILES_DIR` and `CODER_HOME`.

### 3. DDEV global_config install — `install-ddev-config.sh`

All four scripts unconditionally force-copy `global_config.yaml` from
`/home/coder-files/.ddev/` into `~/.ddev/`, and also force-copy any
`.ddev/commands/host/*` host commands. The global config is the canonical
defaults file; force-copying on each boot is the documented behaviour.

**Helper contract:** `install_ddev_config` is idempotent (re-running yields
the same on-disk state), parameterised by `CODER_FILES_DIR` and `CODER_HOME`.

### 4. Coder GitSSH wrapper — `configure-git-ssh.sh`

All four scripts export `GIT_SSH_COMMAND` pointing at the Coder agent's
`gitssh` wrapper if not already set. The exact wrapper path is supplied via
the `CODER_GITSSH` env var the agent injects.

**Helper contract:** `configure_git_ssh` is idempotent (leaves
`GIT_SSH_COMMAND` alone if already set) and probes a small set of well-known
gitssh locations as a fallback.

## Adoption-deferred design

This WP ships the helpers as **definition-only** libraries: sourcing them
adds bash functions to the shell but produces no observable side effects.
The reasons for deferring call-site adoption to a follow-up:

1. **Behaviour preservation.** WP02–WP05 carried the per-template scripts
   verbatim from the previous template architecture. The conservative path is
   to land the helper foundation here and replace inline blocks under a
   separate, smoke-testable change.
2. **Live boot validation.** Each per-template startup script needs a live
   boot test before its inline block is removed; that requires a Coder
   workspace cycle per template, which is out of scope for the implementer
   loop. The follow-up issue should bundle four live-boot smoke tests with
   the call-site swap.
3. **Ownership.** WP06's `owned_files` does not include the per-template
   `startup.sh` files. Editing them here would violate ownership validation.

Each per-template `startup.sh` already includes a guarded sourcing loop
(installed in WP02–WP05) that pulls these helpers in automatically:

```bash
for _helper in start-dockerd hydrate-coder-files install-ddev-config configure-git-ssh; do
  if [ -f "${SHARED_DIR}/${_helper}.sh" ]; then
    . "${SHARED_DIR}/${_helper}.sh"
  fi
done
unset _helper
```

Because the helpers are no-ops on source, dropping them in this WP cannot
regress any template — but it does make the functions available for the next
WP/issue to adopt at call sites.

## Sourcing guarantees

- All helpers guard against double-sourcing via per-file
  `__CODER_DDEV_HELPER_<NAME>_SOURCED` markers.
- No helper sources `lib.sh` itself; per-template scripts source `lib.sh`
  before the helpers, so `log`, `warn`, `die`, and `set -euo pipefail` are
  already in scope.
- No helper executes its function on source. Functions are only invoked when
  a caller explicitly does so (adoption-deferred).

## Follow-up work

Open issue (to be filed in WP07 or after merge):

> **Adopt scripts/shared/ helpers at call sites in per-template startup.sh.**
> For each of the four per-template `startup.sh` files, replace the inline
> implementations of dockerd bring-up, /home/coder-files hydration, DDEV
> global_config install, and GitSSH configuration with calls to the
> corresponding `*_*` functions defined in `scripts/shared/`. Validate with a
> live workspace boot per template and confirm time-to-agent-connected is
> within ±10% of the baselines captured in T004/T008/T012/T017.

## Verification record (this WP)

- `bash -n` on all four helpers — pass
- `shellcheck scripts/shared/*.sh` — pass
- Sourcing test (lib.sh + all 4 helpers) — clean, all 4 functions defined
- `terraform fmt -check -recursive` — pass
- `terraform validate` on all 4 templates — pass
- `terraform test` on drupal-contrib, drupal-core, freeform — pass
- Sourcing count per helper (templates sourcing via `[ -f ]` block): 4
