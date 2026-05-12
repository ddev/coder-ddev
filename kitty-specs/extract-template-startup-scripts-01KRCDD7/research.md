# Phase 0 Research — Extract Template Startup Scripts

**Mission**: `extract-template-startup-scripts-01KRCDD7`
**Date**: 2026-05-12
**Companion**: [`plan.md`](plan.md)

## R1 — Interpolation manifest

**Decision**: Use Terraform `file()` (not `templatefile()`) for all four templates, and route every Terraform-evaluated value through the `coder_agent.env` map as a shell environment variable.

**Rationale**: A `grep` across each template's `startup_script` heredoc range produced a small, regular set of Terraform interpolations — all of them top-of-heredoc assignments of the form `NAME="${terraform.expr}"`. Promoting these to `coder_agent.env = { NAME = terraform.expr }` removes the only reason to use `templatefile()` and lets every extracted script be parsed and shellchecked as plain bash.

**Evidence**:

| Template            | Terraform `${...}` refs | `$${...}` shell-escapes |
| ------------------- | ----------------------- | ----------------------- |
| `drupal-contrib`    | 7                       | 31                      |
| `drupal-core`       | 5                       | 42                      |
| `freeform`          | 1                       | 1                       |
| `user-defined-web`  | 1                       | 0                       |

Full reference list in [`plan.md`](plan.md#interpolation-manifest-validated-during-planning).

**Alternatives considered**:
- *`templatefile()`*: keeps `.sh` files Terraform-aware. Rejected — every extracted file would need `$${...}` escaping again for shell variables, defeating most of the readability gain.
- *Per-template decision (file vs templatefile)*: rejected because no template actually requires `templatefile()` — every `${...}` is a top-of-heredoc shell variable assignment.

## R2 — `file()` path resolution

**Decision**: Reference scripts as `file("${path.module}/../scripts/templates/<name>/startup.sh")` from each template's `template.tf`.

**Rationale**: `path.module` resolves to the directory of the `.tf` file containing the expression. Per-template `template.tf` files live at `<repo>/<template>/template.tf`, so `${path.module}/../scripts/...` reaches the repo-root `scripts/` directory. This works from a fresh clone with no additional setup (FR-007, C-002).

**Verification step (during WP2)**: `terraform -chdir=freeform init -backend=false && terraform -chdir=freeform validate` after the first extraction will fail loudly if the path is wrong.

## R3 — `coder_agent.env` semantics

**Decision**: Pass Terraform-evaluated values to the script via `coder_agent.main.env = { NAME = terraform.expr, ... }`.

**Rationale**: The Coder Terraform provider supports an `env` block on `coder_agent` that is exposed to processes spawned by the agent, including `startup_script`. This is the idiomatic mechanism for promoting Terraform values into shell scope without `templatefile()` substitution.

**Verification step (during WP2)**: Before running the extraction, add a single test env var (`SPEC_KITTY_PROBE=ok`), boot the workspace, confirm `echo "$SPEC_KITTY_PROBE"` shows `ok` in the agent log. Remove the probe before commit.

## R4 — Cross-template duplication audit

**Decision**: Treat the following as *candidate* shared helpers, to be confirmed during WP6 after WP2–WP5 land as monolithic per-template scripts:

| Candidate helper                  | Likely callers                                   |
| --------------------------------- | ------------------------------------------------ |
| `scripts/shared/lib.sh`           | All 4 templates (logging, traps, `set -euo`)     |
| `scripts/shared/start-dockerd.sh` | All 4 (sysbox-runc + dockerd + socket wait)      |
| `scripts/shared/hydrate-coder-files.sh` | All 4 (copy `/home/coder-files/*` into `/home/coder/`) |
| `scripts/shared/install-ddev-config.sh` | All 4 (place `~/.ddev/global_config.yaml`) |
| `scripts/shared/configure-git-ssh.sh`   | All 4 (GitSSH wrapper)                           |

**Rationale**: CLAUDE.md's "Startup Script Flow" enumerates the 8-step boot sequence shared across templates, and the heredoc line counts (225 / 340 / 692 / 921) suggest the larger templates extend rather than replace that shared core. Lexical confirmation must happen against the actually-extracted files, not against the inline heredocs (which interleave shared and template-specific blocks).

**Alternatives considered**:
- *Extract shared helpers in WP2 speculatively*: rejected — would commit to factoring before seeing real diffs across all four extracted scripts.
- *No shared helpers, ship 4 standalone scripts*: rejected — fails Success Criterion #4 (at least one helper reused by ≥ 2 templates).

## R5 — `user-defined-web` test surface

**Decision**: Document that `user-defined-web` has no `terraform test` files (only `tests/` shell helpers), and rely on `terraform -chdir=user-defined-web validate` + live smoke-boot for WP3 acceptance.

**Rationale**: CLAUDE.md "Before Pushing / Pre-push Checklist" enumerates `terraform test` only for `drupal-core`, `drupal-contrib`, `freeform`. A directory listing of `user-defined-web/tests/` confirms it ships shell-driven helpers, not native Terraform tests. FR-009 in `spec.md` already acknowledges this by scoping `terraform test` to the three templates that have it.

**Follow-up (not part of this mission)**: file an issue to add `terraform test` coverage for `user-defined-web/` so future refactors have parity.
