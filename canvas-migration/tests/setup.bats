#!/usr/bin/env bats
setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  export CODER_PROJECT_NAMES=migration
  export MIGRATION_SOURCE_URL='' MIGRATION_GIT_REPOSITORY=''
  export CALLS="$BATS_TEST_TMPDIR/calls"
  export BATS_TEST_DIRNAME
  export SCRIPT="$BATS_TEST_DIRNAME/../migration-setup.sh"
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -eu
if [[ "$*" == *install.sh* ]]; then
  echo installer-download >> "$CALLS"
  [[ "${FAIL_DOWNLOAD:-0}" != 1 ]] || exit 22
  while [[ "$1" != -o ]]; do shift; done
  cp "$BATS_TEST_DIRNAME/installer-fixture.sh" "$2"
else
  [[ "${FAIL_STORYBOOK:-0}" != 1 ]] || exit 7
fi
MOCK
  cat > "$BATS_TEST_TMPDIR/bin/ddev" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CALLS"
[[ "$1" != drush ]] || echo Successful
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/"*
}
@test 'fresh install is verified; restart does not reinstall' {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/.local/state/canvas-migration/status")" = ready ]
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(grep -c installer-download "$CALLS")" -eq 1 ]
  [ "$(grep -c '^restart$' "$CALLS")" -eq 1 ]
  [ "$(grep -c '^start$' "$CALLS")" -eq 1 ]
}
@test 'existing project without marker is preserved and reports failure' {
  mkdir -p "$HOME/migration"
  echo keep > "$HOME/migration/important"
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/migration/important")" = keep ]
  [ ! -e "$CALLS" ]
  grep -q failed "$HOME/.local/state/canvas-migration/status"
}
@test 'failed installer download cannot produce ready status' {
  export FAIL_DOWNLOAD=1
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/.local/state/canvas-migration/installed" ]
  grep -q failed "$HOME/.local/state/canvas-migration/status"
}
@test 'unavailable Storybook fails readiness and prevents automatic reinstall' {
  export FAIL_STORYBOOK=1
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/.local/state/canvas-migration/installed" ]
  unset FAIL_STORYBOOK
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$(grep -c installer-download "$CALLS")" -eq 1 ]
  run bash "$SCRIPT" --verify-existing
  [ "$status" -eq 0 ]
}
@test 'optional values are safely encoded and changes restart DDEV' {
  export MIGRATION_SOURCE_URL='https://example.com/$(touch bad)?q="quoted"'
  export MIGRATION_GIT_REPOSITORY=$'git@example.com:team/repo.git\nsecond line'
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  jq -e --arg source "$MIGRATION_SOURCE_URL" --arg repo "$MIGRATION_GIT_REPOSITORY" \
    '.web_environment == ["MIGRATION_SOURCE_URL=" + $source, "MIGRATION_GIT_REPOSITORY=" + $repo]' \
    "$HOME/migration/.ddev/config.migration.yaml"
  [ ! -e "$HOME/bad" ]
  export MIGRATION_SOURCE_URL=https://other.example.com
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^restart$' "$CALLS")" -eq 2 ]
}
@test 'invalid project cannot escape home or invoke installer' {
  export CODER_PROJECT_NAMES=../outside
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ ! -e "$CALLS" ]
}
@test 'Claude receives onboarding and environment guidance without replacing user instructions' {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  printf 'User instructions\n' > "$HOME/migration/CLAUDE.md"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/migration/CLAUDE.md")" = 'User instructions' ]
  rule="$HOME/migration/.claude/rules/coder-workspace.md"
  grep -q '/building-ui' "$rule"
  grep -q 'ddev drush' "$rule"
  grep -q 'Configuration alone does not prove a live' "$rule"
  [ "$(grep -c '^# Drupal CMS Canvas Migration workspace' "$rule")" -eq 1 ]
}
