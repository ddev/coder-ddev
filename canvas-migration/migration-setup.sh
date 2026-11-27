#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

project="${CODER_PROJECT_NAMES:?Missing project name}"
if [[ ! "$project" =~ ^[a-z][a-z0-9-]{0,39}$ ]]; then
  echo 'Invalid project name; expected one lowercase DDEV name.' >&2
  exit 1
fi
state="$HOME/.local/state/canvas-migration"
mkdir -p "$state"
exec 9>"$state/lock"
flock -n 9 || { echo 'Migration setup is already running.'; exit 1; }
destination="${MIGRATION_DESTINATION:-coder}"
[[ "$destination" == coder || "$destination" == source ]] || { echo 'Invalid migration destination.'; exit 1; }
previous=""
[[ ! -f "$state/destination" ]] || previous="$(cat "$state/destination")"
if [[ -f "$state/installed" && -z "$previous" ]]; then previous=coder; fi
if [[ -n "$previous" && "$previous" != "$destination" ]]; then
  echo 'This workspace belongs to a different destination. Create a new workspace; existing storage is unchanged.' >&2
  exit 1
fi
printf '%s\n' "$destination" > "$state/destination"
exec > >(tee -a "$state/setup.log") 2>&1
trap 'rc=$?; if (( rc != 0 )); then printf "failed; see Migration setup log\n" > "$state/status"; fi' EXIT
printf 'starting\n' > "$state/status"
printf '\nMigration setup: %s\n' "$(date -u)"
cd "$HOME"

if [[ ! -f "$state/installed" ]]; then
  # Never replay an installer over a partial or user-owned project.
  if [[ -d "$HOME/$project" ]] && [[ -z "$(ls -A "$HOME/$project")" ]]; then
    rmdir "$HOME/$project"
  fi
  if [[ -e "$HOME/$project" ]]; then
    echo "Project already exists without an installation marker: $HOME/$project"
    echo 'Inspect the log and repair the project before running migration-setup --verify-existing.'
    [[ "${1:-}" == '--verify-existing' ]] || exit 1
  else
    printf 'installing %s workspace\n' "$destination" > "$state/status"
    curl --fail --silent --show-error --location --retry 3 \
      https://aibp.drupalstarforge.ai/install.sh -o "$state/installer.sh"
    if [[ "$destination" == source ]]; then
      bash "$state/installer.sh" \
        https://gitlab.com/freelygive/canvas-storybook-ai \
        --ref 917a01a6e1477d857f7521234d495346847cfb37 \
        --config source --name "$project" --yolo
    else
      bash "$state/installer.sh" \
        https://gitlab.com/freelygive/canvas-storybook-ai@feat/coder \
        --config drupal-cms-coder --name "$project" --yolo
    fi
  fi
fi

cd "$HOME/$project"
[[ -f .ddev/config.yaml ]] || { echo 'Missing DDEV configuration.'; false; }
if [[ "$destination" == source ]]; then
  # Credentials and the component repository must be outside the served docroot.
  mkdir -p public
  ddev config --docroot=public
  ddev coder-setup
fi
# JSON is valid YAML. jq safely encodes quotes and newlines in optional user input.
jq -n --arg source "${MIGRATION_SOURCE_URL:-}" --arg repo "${MIGRATION_GIT_REPOSITORY:-}" \
  '{web_environment: ["MIGRATION_SOURCE_URL=" + $source, "MIGRATION_GIT_REPOSITORY=" + $repo]}' \
  > .ddev/config.migration.yaml
if ! cmp -s .ddev/config.migration.yaml "$state/last-environment.json"; then
  ddev restart
  cp .ddev/config.migration.yaml "$state/last-environment.json"
else
  ddev start
fi

if [[ "$destination" == coder ]]; then
printf 'checking Drupal and MCP\n' > "$state/status"
ddev drush status --field=bootstrap | grep -qx Successful
jq -e '.mcpServers.drupal.headersHelper and .mcpServers.storybook.url' .mcp.json >/dev/null
[[ -x .claude/mcp-headers.sh ]]
# Validate the credential exchange without logging its token.
.claude/mcp-headers.sh | jq -e '.Authorization | startswith("Bearer ") and length > 7' >/dev/null
else
  tmp="$(mktemp)"
  jq '.mcpServers.storybook = {type:"http",url:"http://localhost:6005/mcp"}' .mcp.json > "$tmp"
  mv "$tmp" .mcp.json
fi
printf 'checking Storybook\n' > "$state/status"
curl --fail --silent --show-error --retry 12 --retry-delay 5 --retry-all-errors \
  --max-time 10 "http://localhost:6005/" -o /dev/null

mkdir -p .claude/rules
# A project rule is loaded by Claude even if the installer owns CLAUDE.md.
cat > .claude/rules/coder-workspace.md <<'GUIDANCE'
# Drupal CMS Canvas Migration workspace

This project uses the Canvas AI Migrations tooling:
https://www.drupal.org/project/canvas_ai_migrations
The project page links to the migration documentation. Its detailed Acquia Source
guide describes a hosted target; this workspace instead has its own Drupal CMS
site in DDEV. Do not assume Acquia authentication or a hosted Source target.

## Help the user get started

When the user greets you or asks how to start, briefly explain that Drupal CMS,
Canvas and Storybook are set up here, and recommend `/building-ui` as the starting
skill. For a request to rebuild or migrate a site's UI, load the installed
building-ui skill and follow its build-approach questions before making changes.
If that skill is unavailable, report the missing skill rather than inventing its
instructions. Do not repeat onboarding in every reply or start a migration merely
because a source URL is configured.

Read MIGRATION_SOURCE_URL from the environment as the suggested source website.
If blank, ask for the source URL or design reference. MIGRATION_GIT_REPOSITORY is
an optional output destination; ask before changing remotes or pushing.

## Coder and DDEV

You run on the Linux Coder workspace host, inside the project's directory, not
on the user's computer and not inside the DDEV web container. Use `ddev drush`,
`ddev composer`, and `ddev npm` for Drupal and project tooling. Read AGENTS.md for
project-specific conventions and the installed skills' settings. One migration
project lives in this workspace.

Use the site's Coder app links for users. The project's AGENTS.md and .env contain
SITE_PUBLIC_URL and STORYBOOK_PUBLIC_URL. Internal *.ddev.site URLs work only in
the workspace. Never print the entire .env file or credentials to discover URLs.

## MCP connections

The project .mcp.json configures `drupal` and `storybook` MCP servers. Drupal uses
.claude/mcp-headers.sh to obtain a token; do not display the token or client secret.
Use the available MCP tools for site and component work. Before reporting that
the connections work, check the tools available in this session and make a
read-only request where supported. Configuration alone does not prove a live
connection. If tools are missing or a request fails, explain which connection is
unavailable and suggest checking `/mcp`; do not ask the user to set everything
up again or claim both servers are connected without evidence.
GUIDANCE

if [[ "$destination" == source ]]; then
  cat > .claude/rules/coder-workspace.md <<'SOURCE_GUIDANCE'
# Acquia Source migration workspace

Storybook and the migration agent run here; the destination CMS is an existing
Acquia Source site. There is no local Drupal installation. Use `ddev npm` for
Canvas CLI and component work. Use the `source` MCP server for destination
content and `storybook` for component previews. Start with `/building-ui`.

Connect the site's per-site API client through the migration dashboard, then
check the workspace connections before migration. Never request a personal
Acquia platform key. Do not create sites through the platform API.

Credentials live in ignored private files. Do not print .env, OAuth tokens,
headers-helper output or client secrets. The Source headers helper obtains a
fresh token for each connection. If authentication fails, stop destination
writes and ask the operator to reconnect in the dashboard. Lost contact does
not mean migration finished or stopped.

MIGRATION_SOURCE_URL is the read-only origin to migrate. The destination and
public site URL are the values configured by the operator, not this workspace's
local PHP app. Git publication and Canvas publication are separate decisions;
follow the migration preferences supplied by the dashboard.
SOURCE_GUIDANCE
  if [[ ! -f "$state/source-browser-tools" ]]; then
    if npm install -g agent-browser && npx --yes playwright install --with-deps chromium; then
      touch "$state/source-browser-tools"
    else
      echo 'Browser tooling needs repair before visual migration checks.' >&2
      exit 1
    fi
  fi
fi

touch "$state/installed"
printf 'ready\n' > "$state/status"
echo "Migration project ready: $HOME/$project"
echo 'Open Claude Code, finish your Claude login, check /mcp, then start with /building-ui.'
