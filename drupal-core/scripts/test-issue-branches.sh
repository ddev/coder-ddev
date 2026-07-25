#!/usr/bin/env bash
# test-issue-branches.sh — Test amateescu/ddev-drupal-dev scaffolding
# against Drupal core branches and issue forks.
#
# Usage:
#   bash drupal-core/scripts/test-issue-branches.sh              # run all default tests
#   bash drupal-core/scripts/test-issue-branches.sh ISSUE:BRANCH:TYPE  # run one issue fork
#   bash drupal-core/scripts/test-issue-branches.sh ::BRANCH:TYPE      # run one plain branch
#
# Triple format: ISSUE:BRANCH:DDEV_PROJECT_TYPE
#   Leave ISSUE empty (::BRANCH:TYPE) for plain origin-branch tests without an issue fork.
#   BRANCH is the git branch to check out (e.g. 10.6.x, 11.x, main).
#   Leave BRANCH empty to stay on main.
#
# Requirements: ddev, git
# Projects are created in ~/tmp/drupal-test-<issue|branch>/ and left in place after the run.
# To clean up: cd ~/tmp/drupal-test-<name> && ddev delete -Oy && cd && rm -rf ~/tmp/drupal-test-<name>

# Default test matrix (issue:branch:ddev-project-type triples)
# ddev project type determines PHP version: drupal10/11 -> PHP 8.4, drupal12 -> PHP 8.5
DEFAULT_TESTS=(
  # Plain version tests (no issue fork) — validates non-main branch checkout
  "::10.6.x:drupal10"
  "::11.x:drupal11"
  "::main:drupal12"
  # Issue-fork tests
  "3380334:3380334-user-update-10000:drupal10"
  "3515218:3515218-deprecate-nodeispage-and:drupal11"
  "3562560:3562560-show-both-minor:drupal11"
  "2555609:2555609-bulk-publish-logging:drupal12"
)

if [ $# -gt 0 ]; then
  TESTS=("$@")
else
  TESTS=("${DEFAULT_TESTS[@]}")
fi

declare -A RESULTS
declare -A DURATIONS

log() { echo "[$(date '+%H:%M:%S')] $*"; }

for PAIR in "${TESTS[@]}"; do
  ISSUE="${PAIR%%:*}"
  if [ -z "$ISSUE" ]; then
    _inner="${PAIR##::}"
    BRANCH="${_inner%%:*}"
    PROJECT_TYPE="${_inner##*:}"
  else
    REST="${PAIR#*:}"
    BRANCH="${REST%%:*}"
    PROJECT_TYPE="${REST##*:}"
  fi
  [ "$PROJECT_TYPE" = "$BRANCH" ] && PROJECT_TYPE="drupal12"
  DIR_KEY="${ISSUE:-${BRANCH:-main}}"
  PROJECT_DIR="$HOME/tmp/drupal-test-$DIR_KEY"
  TARGET_BRANCH="${BRANCH:-main}"
  START=$SECONDS

  log "========================================================"
  if [ -n "$ISSUE" ]; then
    log "Testing issue #$ISSUE  branch: $BRANCH  type: $PROJECT_TYPE"
  else
    log "Testing plain branch: $TARGET_BRANCH  type: $PROJECT_TYPE"
  fi
  log "Project dir: $PROJECT_DIR"
  log "========================================================"

  # --- Clone (or reuse existing clone) ---
  if [ ! -d "$PROJECT_DIR/.git" ]; then
    log "Cloning Drupal core..."
    if ! git clone https://git.drupalcode.org/project/drupal.git "$PROJECT_DIR" 2>&1; then
      log "ERROR: git clone failed"
      RESULTS["$DIR_KEY"]="FAIL (git clone)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      continue
    fi
  else
    log "Clone already present — reusing"
  fi

  cd "$PROJECT_DIR"

  # --- Checkout branch ---
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
  if [ "$CURRENT_BRANCH" = "$TARGET_BRANCH" ]; then
    log "Already on branch: $TARGET_BRANCH"
  elif [ -n "$ISSUE" ]; then
    log "Adding issue fork remote and fetching..."
    git remote remove issue 2>/dev/null || true
    git remote add issue "https://git.drupalcode.org/issue/drupal-$ISSUE.git"
    if ! git fetch issue 2>&1; then
      log "ERROR: git fetch from issue remote failed"
      RESULTS["$DIR_KEY"]="FAIL (git fetch)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
    log "Checking out branch: $BRANCH"
    if ! (git checkout -b "$BRANCH" "issue/$BRANCH" 2>&1 || git checkout "$BRANCH" 2>&1); then
      log "ERROR: branch checkout failed"
      RESULTS["$DIR_KEY"]="FAIL (git checkout)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
    DIRTY=$(git status --short 2>/dev/null)
    if [ -n "$DIRTY" ]; then
      log "ERROR: dirty git tree after issue branch checkout:"
      echo "$DIRTY" | head -20
      RESULTS["$DIR_KEY"]="FAIL (dirty git tree after checkout)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
    log "✓ git tree clean after checkout"
  elif [ "$TARGET_BRANCH" != "main" ]; then
    log "Checking out $TARGET_BRANCH..."
    if ! (git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH" 2>&1 || \
          git checkout "$TARGET_BRANCH" 2>&1); then
      log "ERROR: branch checkout failed"
      RESULTS["$DIR_KEY"]="FAIL (git checkout)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
    log "Checked out $TARGET_BRANCH"
  fi

  # --- Configure DDEV ---
  if ! ddev describe >/dev/null 2>&1; then
    log "Configuring DDEV ($PROJECT_TYPE)..."
    ddev config --project-name "drupal-test-$DIR_KEY" --project-type "$PROJECT_TYPE" 2>&1 | tail -5
    ddev start 2>&1 | tail -10
  else
    log "DDEV project already configured"
    ddev start 2>&1 | tail -5
  fi

  # --- Install add-on and composer install ---
  log "Installing ddev-drupal-dev add-on..."
  ddev add-on get amateescu/ddev-drupal-dev 2>&1 | tail -5
  ddev restart 2>&1 | tail -5

  log "Running ddev composer install..."
  COMPOSER_EXIT=0
  ddev composer install 2>&1 || COMPOSER_EXIT=$?

  if [ "$COMPOSER_EXIT" = "0" ]; then
    # Mirrors the Drush install in template.tf: fall back to an inline Guzzle
    # alias while Drush still requires guzzlehttp/guzzle ^7.0 and core main
    # requires ^8.0 (drush-ops/drush#6602).
    DRUSH_EXIT=0
    ddev composer require drush/drush > /tmp/drush-require.log 2>&1 || DRUSH_EXIT=$?
    tail -5 /tmp/drush-require.log
    if [ "$DRUSH_EXIT" != "0" ]; then
      GUZZLE_VER=$(jq -r '.packages[] | select(.name == "guzzlehttp/guzzle") | .version' composer.lock 2>/dev/null || true)
      case "$GUZZLE_VER" in
        8.*) ddev composer require "guzzlehttp/guzzle:$GUZZLE_VER as 7.99.0" drush/drush -W 2>&1 | tail -5 ;;
      esac
    fi
  fi

  # --- Record result ---
  ELAPSED=$((SECONDS - START))
  DURATIONS["$DIR_KEY"]=$ELAPSED
  if [ "$COMPOSER_EXIT" = "0" ]; then
    RESULTS["$DIR_KEY"]="PASS"
    log "PASS — $DIR_KEY (${ELAPSED}s)"
  else
    RESULTS["$DIR_KEY"]="FAIL (composer exit $COMPOSER_EXIT)"
    log "FAIL — $DIR_KEY (${ELAPSED}s)"
  fi

  cd "$HOME"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================= SUMMARY ============================="
printf "%-20s %-44s %-8s %s\n" "Test" "Branch" "Time" "Result"
printf "%-20s %-44s %-8s %s\n" "----" "------" "----" "------"
for PAIR in "${TESTS[@]}"; do
  ISSUE="${PAIR%%:*}"
  if [ -z "$ISSUE" ]; then
    _inner="${PAIR##::}"
    BRANCH="${_inner%%:*}"
  else
    REST="${PAIR#*:}"
    BRANCH="${REST%%:*}"
  fi
  DIR_KEY="${ISSUE:-${BRANCH:-main}}"
  LABEL="${ISSUE:+#$ISSUE}"
  LABEL="${LABEL:-${BRANCH:-main}}"
  printf "%-20s %-44s %-8s %s\n" \
    "$LABEL" "$BRANCH" "${DURATIONS[$DIR_KEY]:-?}s" "${RESULTS[$DIR_KEY]:-unknown}"
done
echo "==================================================================="
