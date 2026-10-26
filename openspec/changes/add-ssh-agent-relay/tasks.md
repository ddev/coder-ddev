## 1. Implementation
- [x] 1.1 Install `socat`, `fzf`, `zstd` and ship `ssh-agent-relay/connect` and `bashrc.sh` in the image; bump `VERSION` to `v0.6` (DDEV v1.25.5) <!-- id: 1.1 -->
- [x] 1.2 Add `shared/ssh-agent-setup.sh`, the `sync-ssh-agent-setup` make target, and include it in the `startup_script` of `drupal-core`, `drupal-contrib` and `freeform` <!-- id: 1.2 -->
- [x] 1.3 Add an `ssh_agent_relay` run to each template's `tests/validate.tftest.hcl` <!-- id: 1.3 -->
- [x] 1.4 Document in `docs/user/using-workspaces.md` <!-- id: 1.4 -->
- [x] 1.5 Revert the PHP2Shell workaround (#222), now that DDEV v1.25.5 has fixed PHP <!-- id: 1.5 -->

## 2. Validation
- [x] 2.1 `terraform fmt -check -recursive`, `make validate` and `make test-templates` pass <!-- id: 2.1 -->
- [x] 2.2 Relay fallback order checked in a plain `ubuntu:24.04` container: Coder key only, forwarded agent, shell retargeting, agent gone, all gone, dead `SSH_AUTH_SOCK` <!-- id: 2.2 -->
- [ ] 2.3 With the v0.6 image on staging: `ddev-ssh-agent` in the nested Docker connects to the `mode=600` relay socket under Sysbox <!-- id: 2.3 -->
- [ ] 2.4 On staging, from a fresh workspace: `ddev auth ssh` and `ddev exec ssh -T git@github.com` with no forwarded agent (Coder key), with `coder ssh -A`, and with VS Code Desktop, including after a VS Code reconnect <!-- id: 2.4 -->
