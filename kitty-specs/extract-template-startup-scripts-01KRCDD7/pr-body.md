## Summary

Resolves #76. Extracts the multi-hundred-line inline bash from each template's
`coder_agent.main.startup_script` heredoc into versioned `.sh` files under
`scripts/templates/<name>/startup.sh` and `scripts/shared/`, loaded from
`template.tf` via `file()` with Terraform-evaluated values passed through
`coder_agent.env`.

Behavior-preserving refactor. Gated by the #71 test surface. The live boot
wall-clock criterion is **partially verified**: static gates (`terraform fmt`,
`terraform validate`, `terraform test` where available) pass; the ±10% live
boot timing across templates was deferred to the maintainer / CI because the
mission lane has no Coder host available for end-to-end startup probes.

## What changed

- 4 `template.tf` files: `startup_script` heredoc → single
  `file("${path.module}/../scripts/templates/<name>/startup.sh")` call, with
  Terraform-evaluated values relocated into `coder_agent.env`.
- New: `scripts/templates/{freeform,user-defined-web,drupal-contrib,drupal-core}/startup.sh`
  (253 / 368 / 726 / 953 lines respectively — pure bash, no Terraform interpolation).
- New: `scripts/shared/lib.sh` — strict-mode + logging prelude, sourced by all 4
  per-template scripts (satisfies Success Criterion #4).
- New: `scripts/shared/{start-dockerd,hydrate-coder-files,install-ddev-config,configure-git-ssh}.sh`
  — 4 function-only helper libraries, each sourced by all 4 per-template scripts.
- New: `scripts/shared/AUDIT.md` documenting helper inventory, adoption status,
  and what was deliberately left inline.

## What did NOT change

- `shutdown_script` heredocs (out of scope — follow-up).
- Secondary `script = <<-EOT` heredocs in `drupal-contrib`, `drupal-core`,
  `freeform`, `user-defined-web` (around `template.tf:1078 / 1353 / 534 / 638`
  respectively) — out of scope.
- `image/Dockerfile` `RUN <<EOF` heredocs — out of scope.
- Per-template `scripts/` test-helper directories — preserved.
- Workspace runtime behavior (observable end state should be unchanged).
- Helper **adoption** — helpers ship as function-only libraries sourced by all
  4 templates, but per-template scripts still run their original inline
  implementations. Replacing inline blocks with calls to the helper functions
  is intentionally deferred (see `scripts/shared/AUDIT.md` and follow-ups).

## Success criteria (from `kitty-specs/extract-template-startup-scripts-01KRCDD7/spec.md` §9)

- [x] Each `template.tf` has ≤ 20 bash content lines remaining in `startup_script`
      (now exactly 1 line each — a single `file(...)` call).
- [x] Future startup-logic PRs are diffable as `.sh` changes.
- [x] `terraform fmt -check -recursive` and `terraform -chdir=<t> test` pass
      for `drupal-core`, `drupal-contrib`, `freeform`
      (`user-defined-web` has no `terraform test` files — `validate` only;
      see plan §research R5).
- [x] ≥ 1 helper under `scripts/shared/` is sourced by ≥ 2 templates
      (5 helpers — `lib.sh` + 4 named helpers — each sourced by all 4 templates;
      see `scripts/shared/AUDIT.md`).
- [ ] Workspace startup wall-clock time within ±10% of baseline (3 runs per
      template) — **deferred to maintainer/CI**. No Coder host available in
      the mission lane; static gates pass, but live boot timing must be
      validated by `@rfay` or CI before this draft is marked Ready for review.
- [x] PR diff contains no out-of-scope file changes (sentinel check passes:
      diff is confined to `scripts/templates/**`, `scripts/shared/**`,
      `kitty-specs/extract-template-startup-scripts-01KRCDD7/**`, and the 4
      `template.tf` files).

## Test plan

- [x] `terraform fmt -check -recursive`
- [x] `terraform -chdir=freeform        validate && test`
- [x] `terraform -chdir=user-defined-web validate`  (no `terraform test` files in this template — see plan §research R5)
- [x] `terraform -chdir=drupal-contrib  validate && test`
- [x] `terraform -chdir=drupal-core     validate && test`
- [ ] Live boot of one workspace per template; agent connects within ±10%
      of baseline — **deferred to maintainer/CI** (see Success Criteria note).

## Follow-up issues to file after this lands

- Extract `shutdown_script` heredocs similarly across all 4 templates.
- Extract secondary `script = <<-EOT` blocks (`template.tf:1078 / 1353 / 534 / 638`).
- **Adopt shared helpers in per-template scripts** — replace inline bash with
  `start_dockerd` / `hydrate_coder_files` / `install_ddev_config` /
  `configure_git_ssh` function calls. Currently helpers ship as function-only
  definitions; adoption was deferred pending live boot smoke tests. See
  `scripts/shared/AUDIT.md`.
- Add a `shellcheck` CI gate over `scripts/`.
- Extract `RUN <<EOF` heredocs from `image/Dockerfile`.
- Add `terraform test` coverage for `user-defined-web`.

## Spec Kitty artifacts (for reviewers)

- [spec.md](../kitty-specs/extract-template-startup-scripts-01KRCDD7/spec.md)
- [plan.md](../kitty-specs/extract-template-startup-scripts-01KRCDD7/plan.md)
- [research.md](../kitty-specs/extract-template-startup-scripts-01KRCDD7/research.md)
- [scripts/shared/AUDIT.md](../scripts/shared/AUDIT.md)

---

_Generated under the `extract-template-startup-scripts-01KRCDD7` Spec Kitty mission._
