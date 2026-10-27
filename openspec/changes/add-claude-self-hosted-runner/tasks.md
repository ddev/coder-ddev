## 1. Implementation
- [x] 1.1 Add `modules/claude-self-hosted-runner` and the `sync-claude-runner-module` Makefile target <!-- id: 1.1 -->
- [x] 1.2 Wire the module into `freeform`, after the remote-control snippet and before the user startup hook <!-- id: 1.2 -->
- [x] 1.3 Add runner runs to `freeform/tests/validate.tftest.hcl` <!-- id: 1.3 -->
- [x] 1.4 Document the runner in `docs/user/using-workspaces.md` <!-- id: 1.4 -->

## 2. Validation
- [x] 2.1 `terraform fmt -check -recursive`, `make validate` and `make test-templates` pass <!-- id: 2.1 -->
- [ ] 2.2 Manual check on staging: with the switch on and the secret saved, the runner comes up after a workspace restart with no terminal open, and a session lands on it <!-- id: 2.2 -->
- [ ] 2.3 Manual check on staging: with capacity 2, two sessions run at once and both see the `coder-shared-workspace` skill <!-- id: 2.3 -->
