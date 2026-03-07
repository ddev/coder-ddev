#!/usr/bin/env bash
# create-test-workspaces.sh — Create Coder workspaces for issue-branch testing.
#
# Usage:
#   bash drupal-core/scripts/create-test-workspaces.sh              # create all 5 default workspaces
#   bash drupal-core/scripts/create-test-workspaces.sh ISSUE:BRANCH:DRUPAL_MAJOR  # create one
#   bash drupal-core/scripts/create-test-workspaces.sh --check      # check logs of existing test workspaces
#   bash drupal-core/scripts/create-test-workspaces.sh --delete     # delete all test workspaces
#
# Triples format: ISSUE:BRANCH:DRUPAL_MAJOR
#   DRUPAL_MAJOR is 10, 11, or 12 (used for --parameter drupal_version=N)
#
# Requirements: coder CLI authenticated against your Coder deployment
# Workspaces are named t-<issue> and created with the drupal-core template.

TEMPLATE="drupal-core"
WORKSPACE_PREFIX="t-"
INSTALL_PROFILE="demo_umami"

# Default test matrix (issue:branch:drupal-major triples)
DEFAULT_TESTS=(
  "3380334:3380334-user-update-10000:10"
  "3515218:3515218-deprecate-nodeispage-and:11"
  "3562560:3562560-show-both-minor:11"
  "3164889:3164889-issue-with-the:11"
  "2555609:2555609-bulk-publish-logging:12"
)

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
MODE="create"
if [ "${1:-}" = "--check" ]; then
  MODE="check"
  shift
elif [ "${1:-}" = "--delete" ]; then
  MODE="delete"
  shift
fi

if [ $# -gt 0 ]; then
  TESTS=("$@")
else
  TESTS=("${DEFAULT_TESTS[@]}")
fi

# ---------------------------------------------------------------------------
# Delete mode
# ---------------------------------------------------------------------------
if [ "$MODE" = "delete" ]; then
  log "Deleting test workspaces..."
  for PAIR in "${TESTS[@]}"; do
    ISSUE="${PAIR%%:*}"
    WS="${WORKSPACE_PREFIX}${ISSUE}"
    log "  Deleting $WS..."
    coder delete "$WS" --yes 2>&1 || log "  (not found or already deleted)"
  done
  log "Done."
  exit 0
fi

# ---------------------------------------------------------------------------
# Check mode — show key log lines from existing workspaces
# ---------------------------------------------------------------------------
if [ "$MODE" = "check" ]; then
  for PAIR in "${TESTS[@]}"; do
    ISSUE="${PAIR%%:*}"
    REST="${PAIR#*:}"
    BRANCH="${REST%%:*}"
    WS="${WORKSPACE_PREFIX}${ISSUE}"
    echo "=== $WS ($BRANCH) ==="
    coder logs "$WS" 2>&1 | grep -E "(✓|✗|⚠|Setup Complete|setup complete|composer update|Composer update|Detected Drupal|inline alias|Temp branch|Pinned composer|RecipeUnpack|drush si|Drupal install)" | tail -15
    echo ""
  done
  exit 0
fi

# ---------------------------------------------------------------------------
# Create mode
# ---------------------------------------------------------------------------
declare -A WORKSPACE_NAMES
CREATED=()
FAILED=()

TIMESTAMP=$(date '+%m%d-%H%M')

for PAIR in "${TESTS[@]}"; do
  ISSUE="${PAIR%%:*}"
  REST="${PAIR#*:}"
  BRANCH="${REST%%:*}"
  DRUPAL_VERSION="${REST##*:}"
  BASE_WS="${WORKSPACE_PREFIX}${ISSUE}"

  # If the base name already exists, append a timestamp to avoid collision
  if coder show "$BASE_WS" >/dev/null 2>&1; then
    WS="${BASE_WS}-${TIMESTAMP}"
    log "Workspace $BASE_WS already exists — creating $WS instead"
  else
    WS="$BASE_WS"
  fi

  log "Creating workspace $WS (issue #$ISSUE, branch $BRANCH, Drupal $DRUPAL_VERSION)..."

  if coder create --template "$TEMPLATE" "$WS" --yes \
      --parameter issue_fork="$ISSUE" \
      --parameter issue_branch="$BRANCH" \
      --parameter drupal_version="$DRUPAL_VERSION" \
      --parameter install_profile="$INSTALL_PROFILE" 2>&1 | tail -3; then
    CREATED+=("$WS")
    WORKSPACE_NAMES["$ISSUE"]="$WS"
    log "  Created: $WS"
  else
    FAILED+=("$WS")
    log "  FAILED to create: $WS"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================= SUMMARY ============================="
echo "Created ${#CREATED[@]} workspace(s):"
for WS in "${CREATED[@]}"; do
  echo "  $WS"
done
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "Failed ${#FAILED[@]} workspace(s):"
  for WS in "${FAILED[@]}"; do
    echo "  $WS"
  done
fi
echo ""
echo "Check logs after startup completes (~5-10 min):"
echo "  bash drupal-core/scripts/create-test-workspaces.sh --check"
echo ""
echo "Delete all test workspaces:"
echo "  bash drupal-core/scripts/create-test-workspaces.sh --delete"
echo "==================================================================="
