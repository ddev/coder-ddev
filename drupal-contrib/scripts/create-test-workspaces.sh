#!/usr/bin/env bash
# create-test-workspaces.sh — batch create/check/delete drupal-contrib test workspaces
#
# Usage:
#   ./create-test-workspaces.sh              # create all test workspaces
#   ./create-test-workspaces.sh --check      # show logs for existing workspaces
#   ./create-test-workspaces.sh --delete     # delete all test workspaces
#
# Format: PROJECT:DRUPAL_VERSION[:ISSUE:BRANCH]
# Examples:
#   token:11
#   views:11:3568144:3568144-some-fix-2.x

set -euo pipefail

TEMPLATE="drupal-contrib"

# Test matrix: PROJECT:DRUPAL_VERSION or PROJECT:DRUPAL_VERSION:ISSUE:BRANCH
TESTS=(
  "token:11"
  "views:11"
  "pathauto:11"
)

MODE="${1:-create}"

workspace_name() {
  local project="$1"
  local drupal_version="$2"
  local issue="${3:-}"
  if [ -n "$issue" ]; then
    echo "t-${project}-issue-${issue}"
  else
    echo "t-${project}-d${drupal_version}"
  fi
}

for spec in "$${TESTS[@]}"; do
  IFS=':' read -r project drupal_version issue branch <<< "$spec"
  issue="${issue:-}"
  branch="${branch:-}"
  ws=$(workspace_name "$project" "$drupal_version" "$issue")

  case "$MODE" in
    --delete)
      echo "--- Deleting workspace $ws ---"
      coder delete "$ws" --yes 2>/dev/null || echo "  (not found or already deleted)"
      ;;
    --check)
      echo "--- Checking workspace $ws ---"
      coder ssh "$ws" -- bash -c "cat ~/SETUP_STATUS.txt 2>/dev/null || echo 'SETUP_STATUS.txt not found'" 2>/dev/null || echo "  (workspace not accessible)"
      echo ""
      ;;
    *)
      echo "--- Creating workspace $ws (project=$project drupal=$drupal_version issue=${issue:-none}) ---"
      PARAMS="--parameter project_name=$project --parameter drupal_version=$drupal_version"
      if [ -n "$issue" ]; then
        PARAMS="$PARAMS --parameter issue_fork=$issue"
      fi
      if [ -n "$branch" ]; then
        PARAMS="$PARAMS --parameter issue_branch=$branch"
      fi
      # shellcheck disable=SC2086
      coder create --template "$TEMPLATE" "$ws" $PARAMS --yes || echo "  (creation failed)"
      ;;
  esac
done

echo "Done."
