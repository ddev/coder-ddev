#!/usr/bin/env bash
set -euo pipefail
claude=/home/linuxbrew/.linuxbrew/bin/claude
args=(--remote-control "${CODER_WORKSPACE_NAME:?}")
[[ -z ${CLAUDE_EXTRA_FLAGS:-} ]] || args+=("$CLAUDE_EXTRA_FLAGS")
state="$HOME/.local/state/canvas-migration"
cd "${MIGRATION_PROJECT_DIR:?}"
[[ -f "$state/installed" ]]
if ! "$claude" auth status >/dev/null 2>&1; then
  echo 'Sign in to Claude to start this migration.'
  "$claude" auth login
fi
if mkdir "$state/building-ui-started" 2>/dev/null; then
  prompt="/building-ui Recreate the homepage of ${MIGRATION_SOURCE_URL:?} in this project's Storybook using Canvas Code Components. Inspect the source as read-only. Follow the skill's build-approach questions. Review content, responsive layouts and accessibility before asking me about any Drupal writes."
  exec "$claude" "${args[@]}" "$prompt"
fi
exec "$claude" "${args[@]}" --continue
