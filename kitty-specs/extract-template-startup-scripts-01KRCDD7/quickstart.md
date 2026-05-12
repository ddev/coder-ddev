# Quickstart — Validating Extract Template Startup Scripts

**Mission**: `extract-template-startup-scripts-01KRCDD7`
**Audience**: Reviewer of the draft PR, or contributor running the mission's verification locally.

## TL;DR

```bash
cd /path/to/coder-ddev
git fetch upstream
git checkout extract-template-startup-scripts
git diff upstream/main...HEAD -- '*.tf'    # should be minimal
terraform fmt -check -recursive
for t in drupal-contrib drupal-core freeform user-defined-web; do
  terraform -chdir="$t" init -backend=false
  terraform -chdir="$t" validate
done
for t in drupal-core drupal-contrib freeform; do
  terraform -chdir="$t" test
done
```

If every step is green, the spec's behavior-preserving claim is supported by the test surface from issue #71.

## Step-by-step

### 1. Branch and tree state

- Branch: `extract-template-startup-scripts`
- Remote: `origin` = `jonesrussell/coder-ddev` (fork), `upstream` = `ddev/coder-ddev`.
- Diff against the canonical baseline: `git diff upstream/main...HEAD` (per CLAUDE.md convention, never compare against local `main`).

### 2. Terraform formatting

```bash
terraform fmt -check -recursive
```

CI runs this — if it fails locally, CI will fail. The mission must leave this green (Success Criterion #3).

### 3. Per-template validation

```bash
terraform -chdir=drupal-contrib init -backend=false && terraform -chdir=drupal-contrib validate
terraform -chdir=drupal-core    init -backend=false && terraform -chdir=drupal-core    validate
terraform -chdir=freeform       init -backend=false && terraform -chdir=freeform       validate
terraform -chdir=user-defined-web init -backend=false && terraform -chdir=user-defined-web validate
```

This catches `${path.module}/../scripts/...` resolution failures, missing `env` keys, or syntax regressions in `template.tf`.

### 4. Native Terraform tests (#71 surface)

```bash
terraform -chdir=drupal-core    test
terraform -chdir=drupal-contrib test
terraform -chdir=freeform       test
```

`user-defined-web` has shell-driven tests under `user-defined-web/tests/` but no `terraform test` files yet (see [`research.md`](research.md#r5--user-defined-web-test-surface)); rely on validate + live boot for that template.

### 5. Live workspace boot (NFR-001 timing)

Against `staging-coder.ddev.com` (or another Coder host):

```bash
coder create --template freeform          freeform-smoke          --yes
coder create --template user-defined-web  udw-smoke               --yes
coder create --template drupal-contrib    drupal-contrib-smoke    --yes
coder create --template drupal-core       drupal-core-smoke       --yes
```

For each workspace, capture `time-to-agent-connected` and compare against a pre-refactor baseline. NFR-001 requires median wall-clock time within ±10% of baseline over 3 runs per template.

Cleanup:

```bash
for ws in freeform-smoke udw-smoke drupal-contrib-smoke drupal-core-smoke; do
  coder delete "$ws" --yes
done
```

### 6. Out-of-scope sentinel

Confirm no out-of-scope files changed:

```bash
git diff --name-only upstream/main...HEAD | grep -E '(shutdown_script|image/|Dockerfile)' && echo "OUT-OF-SCOPE CHANGES FOUND" || echo "OK"
```

(Note: `shutdown_script` lives inside `template.tf`, so this is a coarse check. Reviewer should also scan the `template.tf` diff visually to confirm `shutdown_script` heredocs and secondary `script` heredocs are untouched.)

### 7. PR submission

```bash
git push origin extract-template-startup-scripts
gh pr create --draft \
  --repo ddev/coder-ddev \
  --base main \
  --head jonesrussell:extract-template-startup-scripts \
  --title "Refactor: extract template startup_script heredocs into versioned scripts (#76)" \
  --body-file kitty-specs/extract-template-startup-scripts-01KRCDD7/pr-body.md  # generated in WP7
```
