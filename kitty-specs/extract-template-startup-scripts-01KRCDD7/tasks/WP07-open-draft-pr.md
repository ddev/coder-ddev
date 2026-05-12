---
work_package_id: WP07
title: Open draft PR + finalize
dependencies:
- WP06
requirement_refs:
- FR-008
- FR-009
planning_base_branch: extract-template-startup-scripts
merge_target_branch: extract-template-startup-scripts
branch_strategy: Planning artifacts for this feature were generated on extract-template-startup-scripts. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into extract-template-startup-scripts unless the human explicitly redirects the landing branch.
subtasks:
- T027
- T028
- T029
agent: "claude:opus-4-7:reviewer:reviewer"
shell_pid: "485074"
history:
- timestamp: '2026-05-12T00:00:00Z'
  event: created
authoritative_surface: kitty-specs/extract-template-startup-scripts-01KRCDD7/
execution_mode: planning_artifact
owned_files:
- kitty-specs/extract-template-startup-scripts-01KRCDD7/pr-body.md
tags: []
---

# WP07 — Open draft PR + finalize

## Objective

Ship the mission. Push the feature branch to the user's fork (`origin` = `jonesrussell/coder-ddev`) and open a **draft pull request** against `ddev/coder-ddev:main`. Confirm CI is green and the final diff matches the Success Criteria checklist from [`spec.md`](../spec.md).

## Context

- All implementation work (WP01–WP06) has landed on local branch `extract-template-startup-scripts`.
- Remotes:
  - `origin` → `git@github.com:jonesrussell/coder-ddev.git` (fork)
  - `upstream` → `git@github.com:ddev/coder-ddev.git` (canonical)
- The PR is **draft** intentionally — issue #150's draft PR #149 set a precedent in this repo; the maintainer (`@rfay`) confirms style before merging.
- This WP produces a planning artifact (`pr-body.md`) inside `kitty-specs/`, not source code.

## Branch strategy

- Planning/base branch: `extract-template-startup-scripts` (off `upstream/main`)
- Final merge target: `ddev/coder-ddev:main` (draft PR opened here)
- Execution worktree allocated per lane from `lanes.json`.

## Subtasks

### T027 — Generate PR body

**Purpose**: Produce a reviewer-ready PR body referencing #76, listing what's in and out of scope, and seeding follow-up issues.

**Steps**:
1. Create `kitty-specs/extract-template-startup-scripts-01KRCDD7/pr-body.md` with:
   ```markdown
   ## Summary

   Resolves #76. Extracts ~2,178 lines of inline bash from each template's
   `coder_agent.main.startup_script` heredoc into versioned `.sh` files
   under `scripts/templates/<name>/` and `scripts/shared/`, loaded from
   `template.tf` via `file()` with Terraform-evaluated values passed through
   `coder_agent.env`.

   Behavior-preserving refactor. Gated by the #71 test surface (closed
   2026-05-10).

   ## What changed

   - 4 `template.tf` files: `startup_script` heredoc → `file(...)` + `env = {...}`.
     Total inline-bash reduction: ≥ 99% of the ~2,178 starting lines.
   - New: `scripts/templates/{freeform,user-defined-web,drupal-contrib,drupal-core}/startup.sh`.
   - New: `scripts/shared/lib.sh` (strict-mode + logging prelude, sourced by all 4).
   - New: `scripts/shared/*.sh` shared helpers (count and identities per `scripts/shared/AUDIT.md`).
   - New: `scripts/shared/AUDIT.md` documenting what was factored vs. left inline.

   ## What did NOT change

   - `shutdown_script` heredocs (out of scope — follow-up).
   - Secondary `script = <<-EOT` heredocs in `drupal-contrib`, `drupal-core`,
     `freeform`, `user-defined-web` (around lines 1078 / 1353 / 534 / 638
     respectively) — out of scope.
   - `image/Dockerfile` heredocs — out of scope.
   - Per-template `scripts/` test-helper directories — preserved.
   - Workspace runtime behavior (observable end state, boot time within ±10%).

   ## Success criteria (from kitty-specs/extract-template-startup-scripts-01KRCDD7/spec.md §9)

   - [x] Each `template.tf` has ≤ 20 bash content lines remaining in `startup_script`.
   - [x] Future startup-logic PRs are diffable as `.sh` changes.
   - [x] `terraform fmt -check -recursive` and `terraform -chdir=<t> test` pass for `drupal-core`, `drupal-contrib`, `freeform`.
   - [x] ≥ 1 helper under `scripts/shared/` is sourced by ≥ 2 templates (see AUDIT.md).
   - [x] Workspace startup wall-clock time within ±10% of baseline (3 runs per template).
   - [x] PR diff contains no out-of-scope file changes.

   ## Test plan

   - [x] `terraform fmt -check -recursive`
   - [x] `terraform -chdir=freeform        validate && test`
   - [x] `terraform -chdir=user-defined-web validate`  (no `terraform test` files in this template — see plan §research R5)
   - [x] `terraform -chdir=drupal-contrib  validate && test`
   - [x] `terraform -chdir=drupal-core     validate && test`
   - [x] Live boot of one workspace per template; agent connects within ±10% of baseline

   ## Follow-up issues to file after this lands

   - Extract `shutdown_script` heredocs similarly.
   - Extract secondary `script = <<-EOT` blocks (template.tf:1078 / 1353 / 534 / 638).
   - Add `shellcheck` CI gate over `scripts/`.
   - Extract `RUN <<EOF` heredocs from `image/Dockerfile`.
   - Add `terraform test` coverage for `user-defined-web`.

   ## Spec Kitty artifacts (for reviewers)

   - [spec.md](../kitty-specs/extract-template-startup-scripts-01KRCDD7/spec.md)
   - [plan.md](../kitty-specs/extract-template-startup-scripts-01KRCDD7/plan.md)
   - [research.md](../kitty-specs/extract-template-startup-scripts-01KRCDD7/research.md)
   - [scripts/shared/AUDIT.md](../scripts/shared/AUDIT.md)

   ---

   _Generated under the `extract-template-startup-scripts-01KRCDD7` Spec Kitty mission._
   ```
2. Cross-check every Success Criteria checkbox against actual artifacts before marking checked. If any criterion is **not yet met**, leave the box unchecked and call it out in the PR description's opening line.

**Files**:
- `kitty-specs/extract-template-startup-scripts-01KRCDD7/pr-body.md` (new)

**Validation**:
- [ ] `pr-body.md` exists and references all 6 Success Criteria
- [ ] Every checked box has a corresponding artifact (don't check criteria that aren't actually satisfied)
- [ ] Out-of-scope items listed match `spec.md` §3 and §14

### T028 — Push branch and open the draft PR

**Purpose**: Publish to GitHub.

**Steps**:
1. Push the branch to the fork:
   ```bash
   git push -u origin extract-template-startup-scripts
   ```

2. Open the draft PR using `gh`:
   ```bash
   gh pr create --draft \
     --repo ddev/coder-ddev \
     --base main \
     --head jonesrussell:extract-template-startup-scripts \
     --title "Refactor: extract template startup_script heredocs into versioned scripts (#76)" \
     --body-file kitty-specs/extract-template-startup-scripts-01KRCDD7/pr-body.md
   ```

3. Capture the PR URL from the `gh` output. Record it in this WP's review notes.

**Files**: none modified locally (publication step).

**Validation**:
- [ ] `git push` succeeds; remote branch exists at `origin/extract-template-startup-scripts`
- [ ] `gh pr view` returns a PR in `DRAFT` state targeting `ddev/coder-ddev:main`
- [ ] PR title includes `(#76)`
- [ ] PR body matches `pr-body.md`

### T029 — Confirm CI green; verify final diff

**Purpose**: Last gate before handing off to the maintainer for review.

**Steps**:
1. Wait for CI to run on the draft PR:
   ```bash
   gh pr checks --watch
   ```

2. If any check fails:
   - Investigate the specific failure (`terraform fmt`, `terraform validate`, etc.).
   - Fix on the local branch.
   - Push the fix; `gh pr checks --watch` again.

3. Final diff audit:
   ```bash
   git diff upstream/main...HEAD --name-only
   ```
   Expected output groups:
   - `kitty-specs/extract-template-startup-scripts-01KRCDD7/**` — planning artifacts
   - `scripts/templates/*/startup.sh` — 4 new scripts
   - `scripts/shared/**` — new shared helpers + lib.sh + AUDIT.md
   - `{freeform,user-defined-web,drupal-contrib,drupal-core}/template.tf` — heredoc → `file()`

   **Sentinel check** — confirm out-of-scope files are absent:
   ```bash
   git diff --name-only upstream/main...HEAD | grep -E '^image/|/scripts/(create-test|test-issue|test-freeform|update-drupal)' \
     && echo "UNEXPECTED FILES IN DIFF" || echo "OK"
   ```

4. Final Success Criteria walkthrough — read [`spec.md`](../spec.md) §9 line by line and confirm every criterion is satisfied. Update `pr-body.md` checkboxes if anything is out of date.

**Validation**:
- [ ] All CI checks pass
- [ ] Diff includes only the expected file groups
- [ ] Sentinel check returns `OK`
- [ ] Every `spec.md` §9 Success Criterion is satisfied

## Definition of Done

- Draft PR exists at `ddev/coder-ddev` targeting `main`, sourced from `jonesrussell:extract-template-startup-scripts`.
- CI is green on the PR.
- `pr-body.md` references #76, all 6 Success Criteria, and the follow-up list.
- Final diff audit passes the sentinel check.

## Risks

| Risk                                                                                   | Mitigation                                                                              |
| -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| CI fails on `terraform fmt -check`                                                     | Run `terraform fmt -recursive` locally and push before opening the PR.                  |
| `upstream/main` has moved during the mission                                           | `git fetch upstream && git rebase upstream/main` before push; resolve conflicts; re-test. |
| Maintainer prefers a different PR shape                                                 | Mission #150 is precedent for descriptive-first style; if `@rfay` redirects, file an issue and adapt in a follow-up commit. |
| `gh` not authenticated                                                                 | `gh auth status`; resolve before T028.                                                  |

## Reviewer guidance (for the WP07 implementer's self-review)

- Open the draft PR URL in a browser. Spot-check the diff visualization.
- Confirm draft state (not "Ready for review").
- Confirm the PR title format matches the repo's convention (look at recent merged PRs for style: `fix:`, `feat:`, `chore:`, `docs:` prefixes; #76 is a refactor — `refactor:` or no prefix both acceptable, the title above uses no prefix per the bigger context).

## Implementation command

```bash
spec-kitty agent action implement WP07 --agent <name>
```

## Activity Log

- 2026-05-12T17:45:26Z – claude:opus-4-7:implementer:implementer – shell_pid=484396 – Started implementation via action command
- 2026-05-12T17:47:21Z – claude:opus-4-7:implementer:implementer – shell_pid=484396 – pr-body.md drafted; T028/T029 (push + gh pr create) deferred to orchestrator post-merge (depends on lane-a merging into extract-template-startup-scripts first)
- 2026-05-12T17:47:44Z – claude:opus-4-7:reviewer:reviewer – shell_pid=485074 – Started review via action command
