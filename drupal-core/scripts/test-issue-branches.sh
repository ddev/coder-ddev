#!/usr/bin/env bash
# test-issue-branches.sh — Test joachim-n/drupal-core-development-project:dev-main
# against known Drupal core issue branches to validate composer fix logic.
#
# Usage:
#   bash drupal-core/scripts/test-issue-branches.sh              # run all 5 default issues
#   bash drupal-core/scripts/test-issue-branches.sh ISSUE:BRANCH # run one specific issue
#
# Requirements: ddev, jq, git
# Projects are created in ~/tmp/drupal-test-<issue>/ and left in place after the run.
# To clean up: cd ~/tmp/drupal-test-<issue> && ddev delete -Oy

# Default test matrix (issue:branch:ddev-project-type triples)
# ddev project type determines PHP version: drupal10/11 -> PHP 8.4, drupal12 -> PHP 8.5
DEFAULT_TESTS=(
  "3380334:3380334-user-update-10000:drupal10"
  "3515218:3515218-deprecate-nodeispage-and:drupal11"
  "3562560:3562560-show-both-minor:drupal11"
  "3164889:3164889-issue-with-the:drupal11"
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
  REST="${PAIR#*:}"
  BRANCH="${REST%%:*}"
  PROJECT_TYPE="${REST##*:}"
  # Default project type if not specified
  [ "$PROJECT_TYPE" = "$BRANCH" ] && PROJECT_TYPE="drupal11"
  PROJECT_DIR="$HOME/tmp/drupal-test-$ISSUE"
  REPOS_DIR="$PROJECT_DIR/repos/drupal"
  START=$SECONDS

  log "========================================================"
  log "Testing issue #$ISSUE  branch: $BRANCH"
  log "Project dir: $PROJECT_DIR"
  log "========================================================"

  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"

  # --- Configure and start DDEV if needed ---
  if ! ddev describe >/dev/null 2>&1; then
    log "Configuring DDEV project (type: $PROJECT_TYPE)..."
    ddev config --project-name "drupal-test-$ISSUE" --project-type "$PROJECT_TYPE" --docroot . \
      --composer-version 2 2>&1 | tail -5
    ddev start 2>&1 | tail -10
  else
    log "DDEV project already configured"
  fi

  # --- composer create-project using dev-main ---
  if [ ! -f "composer.json" ]; then
    log "Running composer create-project (dev-main)..."
    ddev composer create-project --no-install --no-interaction \
      "joachim-n/drupal-core-development-project:dev-main" . 2>&1 | tail -20
  else
    log "composer.json already present — skipping create-project"
  fi

  if [ ! -d "$REPOS_DIR/.git" ]; then
    log "ERROR: repos/drupal/.git not found after create-project"
    RESULTS["$ISSUE"]="FAIL (no repos/drupal)"
    DURATIONS["$ISSUE"]=$((SECONDS - START))
    cd "$HOME"
    continue
  fi

  # --- Checkout issue branch ---
  CURRENT_BRANCH=$(git -C "$REPOS_DIR" branch --show-current 2>/dev/null || echo "")
  if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    log "Adding issue fork remote and fetching..."
    git -C "$REPOS_DIR" remote remove issue 2>/dev/null || true
    git -C "$REPOS_DIR" remote add issue "https://git.drupalcode.org/issue/drupal-$ISSUE.git"
    if ! git -C "$REPOS_DIR" fetch issue 2>&1; then
      log "ERROR: git fetch from issue remote failed"
      RESULTS["$ISSUE"]="FAIL (git fetch)"
      DURATIONS["$ISSUE"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
    log "Checking out branch: $BRANCH"
    if ! (git -C "$REPOS_DIR" checkout -b "$BRANCH" "issue/$BRANCH" 2>&1 || \
          git -C "$REPOS_DIR" checkout "$BRANCH" 2>&1); then
      log "ERROR: branch checkout failed"
      RESULTS["$ISSUE"]="FAIL (git checkout)"
      DURATIONS["$ISSUE"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
  else
    log "Already on branch: $BRANCH"
  fi

  # --- Apply composer.json fixes ---
  # joachim-n/drupal-core-development-project:dev-main uses "*" for all drupal/* constraints
  # in the root and includes repos/drupal/composer/Plugin/* as a glob (so RecipeUnpack is
  # covered). However, transitive constraints between path repo packages still need Fix 1+2
  # for 10.x/11.x: packages like drupal/core-recommended require drupal/core 11.x-dev, but
  # a branch with alias 11.3.x-dev can't satisfy that without an inline alias. For 12.x,
  # the 12.x-dev branch-alias = dev-main on Packagist, so no fix is needed.
  cd "$PROJECT_DIR"

  CHECKED_OUT_BRANCH=$(git -C "$REPOS_DIR" branch --show-current 2>/dev/null || echo "")
  TARGET_ALIAS=$(jq -r '.require["drupal/core"]' \
    "$REPOS_DIR/composer/Metapackage/CoreRecommended/composer.json" 2>/dev/null || echo "")
  ACTUAL_DRUPAL_MAJOR=$(echo "$TARGET_ALIAS" | grep -oE '^[0-9]+' || echo "11")
  if [ -z "$TARGET_ALIAS" ]; then
    log "WARNING: could not read TARGET_ALIAS from CoreRecommended; defaulting to 11.x-dev"
    ACTUAL_DRUPAL_MAJOR="11"
    TARGET_ALIAS="11.x-dev"
  fi
  log "Detected Drupal $ACTUAL_DRUPAL_MAJOR.x (CoreRecommended requires: $TARGET_ALIAS)"

  # Fix 1+2 (10.x/11.x only): inline alias so path repo packages satisfy each other's N.x-dev
  # constraints. 12.x branches work without this (12.x-dev = dev-main on Packagist).
  if [ "$ACTUAL_DRUPAL_MAJOR" != "12" ]; then
    jq --arg val "dev-$CHECKED_OUT_BRANCH as $TARGET_ALIAS" \
      '.require |= with_entries(if (.key | startswith("drupal/")) and .key != "drupal/drupal" then .value = $val else . end)' \
      composer.json > composer.json.tmp && mv composer.json.tmp composer.json
    jq --arg branch "dev-$CHECKED_OUT_BRANCH" \
      '.require["drupal/drupal"] = $branch' \
      composer.json > composer.json.tmp && mv composer.json.tmp composer.json
    log "  Inline alias: dev-$CHECKED_OUT_BRANCH as $TARGET_ALIAS; drupal/drupal pinned"
  fi

  # Fix 3: pin composer/composer when json-schema conflict present
  # drupal/core-dev on some branches (10.x, 11.2.x) requires justinrainbow/json-schema ^5.2,
  # but composer 2.9.x requires ^6.5.1 — conflict. See https://www.drupal.org/project/drupal/issues/3557585
  _core_dev_json_schema=$(jq -r '.require["justinrainbow/json-schema"] // ""' \
    "$REPOS_DIR/composer/Metapackage/DevDependencies/composer.json" 2>/dev/null || echo "")
  if echo "$_core_dev_json_schema" | grep -q '^\^5'; then
    jq '.require["composer/composer"] = "~2.8.1" | .config.audit["block-insecure"] = false' \
      composer.json > composer.json.tmp && mv composer.json.tmp composer.json
    log "  Pinned composer/composer ~2.8.1 (json-schema conflict detected)"
  fi

  # --- Run composer update -W ---
  log "Running ddev composer update -W..."
  COMPOSER_EXIT=0
  ddev composer update -W 2>&1 || COMPOSER_EXIT=$?

  # --- Record result ---
  ELAPSED=$((SECONDS - START))
  DURATIONS["$ISSUE"]=$ELAPSED
  if [ "$COMPOSER_EXIT" = "0" ]; then
    RESULTS["$ISSUE"]="PASS"
    log "PASS — issue #$ISSUE (${ELAPSED}s)"
  else
    RESULTS["$ISSUE"]="FAIL (composer exit $COMPOSER_EXIT)"
    log "FAIL — issue #$ISSUE (${ELAPSED}s)"
  fi

  cd "$HOME"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================= SUMMARY ============================="
printf "%-12s %-48s %-8s %s\n" "Issue" "Branch" "Time" "Result"
printf "%-12s %-48s %-8s %s\n" "-----" "------" "----" "------"
for PAIR in "${TESTS[@]}"; do
  ISSUE="${PAIR%%:*}"
  REST="${PAIR#*:}"
  BRANCH="${REST%%:*}"
  printf "%-12s %-48s %-8s %s\n" \
    "#$ISSUE" "$BRANCH" "${DURATIONS[$ISSUE]:-?}s" "${RESULTS[$ISSUE]:-unknown}"
done
echo "==================================================================="
