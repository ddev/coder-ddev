# Research — Workspace Runtime Contract

## Purpose

Synthesize the foundational runtime invariants of a `coder-ddev` workspace from three existing artifacts — `image/Dockerfile`, `user-defined-web/template.tf`, and the inlined `startup_script` — into a single descriptive-first spec named `workspace-runtime-contract`.

This research is the **basis of evidence** for OpenSpec change `add-workspace-runtime-contract` and the Spec Kitty mission `workspace-runtime-contract-01KRC8WY`. No new behavior is proposed; every invariant maps to existing code.

## Method

1. Read each governing source end-to-end (image, template HCL, startup script, governance scaffolding) and produce per-source analyses.
2. Cross-reference the three sources for each candidate invariant.
3. Reject candidates that exist in only one source or that are aspirational rather than enforced.
4. Promote the remaining cross-referenced invariants into INV-1…INV-9.
5. Catalog known drift (cases where prose docs disagree with code) as D-1…D-6 — these are **not** part of the contract; they are tracked attachment points for follow-up changes.

## Key Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D-RUNTIME | Adopt Sysbox-runc as the only supported container runtime for workspaces. | The HCL pins `runtime = "sysbox-runc"`; the script's manual `sudo dockerd &` only works safely under Sysbox; `--privileged` is explicitly avoided. |
| D-IDENT | Identity = `coder` (UID 1000), docker GID = 988 (parametric). | Image renames `ubuntu` → `coder`; HCL sets `user = "coder"` and `group_add = [tostring(var.docker_gid)]`; agent env forces `HOME=/home/coder`. |
| D-SUDO | NOPASSWD sudo is load-bearing, not optional. | Required by `dockerd &`, `chown /home/coder`, `tee /etc/docker/daemon.json`, `chmod /var/run/docker.sock`. Removing it breaks every boot. |
| D-DAEMON | dockerd is started manually by the agent (`sudo dockerd &`), not by systemd-as-PID-1. | Image enables the systemd unit but the container's PID 1 is `sh -c $CODER_AGENT_INIT_SCRIPT`. Two start models coexist; only the manual path is exercised. |
| D-VOLUMES | Two-volume model: host bind for `/home/coder` + named volume for `/var/lib/docker`. No host docker socket mount. | HCL `volumes` + `mounts` blocks; comment explicitly forbids socket mount; named volume survives container replacement, bind survives workspace restart. |
| D-HYDRATION | "Copy-if-missing, append-if-missing" hydration from `/home/coder-files`. | Bind mount shadows image content; idempotent boot is required because the script re-runs every start; user state must survive. |
| D-ROUTING | Direct-bind on `localhost:80`, ddev-router globally omitted, one project at a time. | Documented in CLAUDE.md and reflected in `coder_app.ddev-web`; `freeform` template is the explicit deviation and has its own contract. |
| D-CLEANUP | Workspace delete must remove `/coder-workspaces/<owner>-<ws>` via host-side `coder-delete-workspace-dir` invoked from `null_resource.workspace_cleanup`. | Otherwise host directories orphan; Docker named volume is auto-cleaned by Terraform; bind dir is not. |
| D-IDSRC | Workspace identity is sourced from `coder_agent.env`, not the container hostname. | Hostname = `<ws-name>-<owner>`; container name = `coder-<id>`. Script's hostname heuristic is defense-in-depth only. |

## Known Drift (D-1…D-6) — Tracked, Not Resolved Here

| ID | Drift | Where |
|----|-------|-------|
| D-1 | `image/scripts/.ddev/global_config.yaml` referenced by CLAUDE.md but missing from image tree. | `CLAUDE.md` "Architecture" + `image/scripts/.ddev/` listing |
| D-2 | `.ddev/commands/host/{launch,coder-routes,coder-setup}` shipped but never copied by `user-defined-web` startup. | `image/scripts/.ddev/commands/host/` vs. `user-defined-web/template.tf:295-340` |
| D-3 | `coder-setup` lacks explicit `chmod 755` in image build. | `image/Dockerfile:189-195` |
| D-4 | Dual dockerd-start models (manual + systemd unit enabled). | `image/Dockerfile:118` + script `dockerd &` |
| D-5 | `chmod 666 /var/run/docker.sock` is broader than needed given `group_add = 988`. | Script line ~422 |
| D-6 | `image_version` is a single tag across all four templates; per-template pinning unsupported. | `VERSION` + template `local.image_version` |

## Open Questions (carried into planning)

- Should D-1 (`global_config.yaml`) be remediated in a follow-up OpenSpec change `restore-ddev-global-config` or rolled into a broader `template-contract` change?
- Should the systemd-as-init code path (D-4) be removed in a single image change or kept until a runtime contract v2 explicitly retires it?
- For Spec Kitty / OpenSpec linkage: persist `openspec_change_id` in mission `meta.json` (preferred) or only in `proposal.md` (lower coupling)? Recommendation: both.

## Outputs

- `kitty-specs/workspace-runtime-contract-01KRC8WY/spec.md` — mission spec describing this work.
- `kitty-specs/workspace-runtime-contract-01KRC8WY/data-model.md` — entities representing the 9 invariants.
- `openspec/changes/add-workspace-runtime-contract/` — proposal, tasks, design, delta spec (created in the `tasks` step).

## Risks

- **Spec text becomes stale** if `CLAUDE.md` or HCL drift after archive. Mitigation: descriptive-first language + Phase 4 CI drift check (out of scope here).
- **Pilot mission collision**: existing `github-org-gated-signup-01KR1P4G` mission is open. Spec Kitty allows concurrent missions but auto-commits may interleave. Mitigation: this mission runs on its own branch `spec-workspace-runtime-contract` from `upstream/main`.
- **Two governance systems** (OpenSpec + Spec Kitty) cohabit without enforcement. Mitigation: cross-link via `meta.json` and proposal body; CI gating reserved for Phase 4.
