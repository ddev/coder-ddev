## 1. Implementation
- [x] 1.1 Run `~/.coder-startup.sh` (detached, logged, explicit PATH) from the `startup_script` in `drupal-core`, `drupal-contrib` and `freeform` <!-- id: 1.1 -->
- [x] 1.2 Add a `user_startup_hook` run to each template's `tests/validate.tftest.hcl` <!-- id: 1.2 -->
- [x] 1.3 Document the hook in `docs/user/using-workspaces.md` <!-- id: 1.3 -->

## 2. Validation
- [x] 2.1 `terraform fmt -check -recursive`, `make validate` and `make test-templates` pass <!-- id: 2.1 -->
- [x] 2.2 Integration test: `freeform/scripts/test-freeform-startup-hook.sh` installs a hook before the GH freeform job's workspace restart and verifies it after <!-- id: 2.2 -->
- [x] 2.3 Integration test passes on staging <!-- id: 2.3 -->
- [x] 2.4 Manual check on staging: a `~/.coder-startup.sh` that starts a Claude self-hosted runner in tmux brings the runner up after a workspace restart with no terminal open, and a session lands on it <!-- id: 2.4 -->

## 3. Image
- [x] 3.1 Install `claude-code@latest` instead of `claude-code` in `image/Dockerfile` (VERSION unchanged) <!-- id: 3.1 -->

## 4. CI diagnostics
- [x] 4.1 Add `scripts/ci-show-provisioner-errors.sh` and an `if: failure()` step after every `coder create` step in the integration workflows, so a failed server-side Terraform init/plan/apply shows its real error (not just `exit status 1`) <!-- id: 4.1 -->
