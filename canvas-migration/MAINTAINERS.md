# Template maintenance

Based on the `freeform` template, using the `ddev/coder-ddev` image version in
the root `VERSION` file. The installation uses
`canvas-storybook-ai@feat/coder`, config `drupal-cms-coder`.

This template is experimental. Its display name says so on the templates page.

## Shared assets

Like the other templates, this directory holds vendored copies of
`modules/claude-remote-control`, `modules/claude-self-hosted-runner`,
`modules/docker-daemon` and the files in `shared/`. Edit the canonical copies
at the repository root and run `make sync-shared`; see `AGENTS.md`.

The template configures `claude-remote-control` through module variables:
remote control and skipped permission prompts default to on, Claude starts in
the project directory, and the **Start a migration with /building-ui** switch
passes `start-building-ui.sh` as the module's `launch_script`.

## Prerequisites

The DDEV Coder infrastructure must provide Sysbox, the workspace directory
cleanup helper, and access to the `ddev/coder-ddev` image. The provisioner must
have Docker access. Outbound access is needed for the installer, Composer, npm,
Git repositories and Claude. Complete Claude authentication yourself in the
Claude Code app; no password or Claude token is a template parameter.

## Recovery

Setup records successful installation in `~/.local/state/canvas-migration/installed`.
An existing project without that marker is not overwritten. Inspect the setup log,
repair the project, then run `~/.local/bin/migration-setup --verify-existing`.
This validates an existing project without reinstalling it.

The installer and `feat/coder` branch are fetched on first creation. Existing
projects are not automatically updated. Optional migration inputs are exposed
as `MIGRATION_SOURCE_URL` and `MIGRATION_GIT_REPOSITORY` on the host and in DDEV.

## Validation

From the repository root, run `make validate` and `make test-templates`, which
cover this template. ShellCheck covers `migration-setup.sh` and
`start-building-ui.sh`; Bats tests in `tests/setup.bats` exercise restart
behavior, partial failure, readiness failure and safe input handling with mock
commands:

```bash
shellcheck canvas-migration/migration-setup.sh canvas-migration/start-building-ui.sh
bats canvas-migration/tests/setup.bats
```

These checks do not replace a real staging workspace test.

## Push

```bash
# Staging, inactive, to test before promoting
make push-template-canvas-migration ACTIVATE=false

# Production, after merge
make push-template-canvas-migration
```
