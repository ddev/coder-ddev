## 1. Implementation
- [x] 1.1 Run `~/.coder-startup.sh` (detached, logged, explicit PATH) from the `startup_script` in `drupal-core`, `drupal-contrib` and `freeform` <!-- id: 1.1 -->
- [x] 1.2 Add a `user_startup_hook` run to each template's `tests/validate.tftest.hcl` <!-- id: 1.2 -->
- [x] 1.3 Document the hook in `docs/user/using-workspaces.md` <!-- id: 1.3 -->

## 2. Validation
- [x] 2.1 `terraform fmt -check -recursive`, `make validate` and `make test-templates` pass <!-- id: 2.1 -->
- [x] 2.2 Integration test: `freeform/scripts/test-freeform-startup-hook.sh` installs a hook before the GH freeform job's workspace restart and verifies it after <!-- id: 2.2 -->
- [ ] 2.3 Integration test passes on staging <!-- id: 2.3 -->

## 3. Image
- [x] 3.1 Install `claude-code@latest` instead of `claude-code` in `image/Dockerfile` (VERSION unchanged) <!-- id: 3.1 -->
