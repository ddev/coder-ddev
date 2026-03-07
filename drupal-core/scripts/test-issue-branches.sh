#!/usr/bin/env bash
# test-issue-branches.sh — Test joachim-n/drupal-core-development-project:dev-main
# against known Drupal core issue branches to validate composer fix logic.
#
# Usage:
#   bash drupal-core/scripts/test-issue-branches.sh              # run all default tests
#   bash drupal-core/scripts/test-issue-branches.sh ISSUE:BRANCH:TYPE  # run one issue fork
#   bash drupal-core/scripts/test-issue-branches.sh ::BRANCH:TYPE      # run one plain branch
#
# Triples format: ISSUE:BRANCH:DDEV_PROJECT_TYPE
#   Leave ISSUE empty (::BRANCH:TYPE) for plain origin-branch tests without an issue fork.
#   BRANCH is the git branch to check out from origin (e.g. 10.6.x, 11.x, main).
#   Leave BRANCH empty (::TYPE or ISSUE::TYPE) to skip checkout and stay on main.
#
# Requirements: ddev, jq, git
# Projects are created in ~/tmp/drupal-test-<issue|branch>/ and left in place after the run.
# To clean up: cd ~/tmp/drupal-test-<name> && ddev delete -Oy

# Default test matrix (issue:branch:ddev-project-type triples)
# ddev project type determines PHP version: drupal10/11 -> PHP 8.4, drupal12 -> PHP 8.5
DEFAULT_TESTS=(
  # Plain version tests (no issue fork) — validates non-main branch checkout + composer fixes
  "::10.6.x:drupal10"
  "::11.x:drupal11"
  "::main:drupal12"
  # Issue-fork tests
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
  if [ -z "$ISSUE" ]; then
    # ::BRANCH:TYPE format — strip the two leading colons then parse normally
    _inner="${PAIR##::}"
    BRANCH="${_inner%%:*}"
    PROJECT_TYPE="${_inner##*:}"
  else
    REST="${PAIR#*:}"
    BRANCH="${REST%%:*}"
    PROJECT_TYPE="${REST##*:}"
  fi
  # Default project type if not specified
  [ "$PROJECT_TYPE" = "$BRANCH" ] && PROJECT_TYPE="drupal11"
  # Directory name: use issue number if present, else branch name (main → "main", 10.6.x → "10.6.x")
  DIR_KEY="${ISSUE:-${BRANCH:-main}}"
  PROJECT_DIR="$HOME/tmp/drupal-test-$DIR_KEY"
  REPOS_DIR="$PROJECT_DIR/repos/drupal"
  START=$SECONDS

  log "========================================================"
  if [ -n "$ISSUE" ]; then
    log "Testing issue #$ISSUE  branch: $BRANCH  type: $PROJECT_TYPE"
  else
    log "Testing plain branch: ${BRANCH:-main}  type: $PROJECT_TYPE"
  fi
  log "Project dir: $PROJECT_DIR"
  log "========================================================"

  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"

  # --- Configure and start DDEV if needed ---
  if ! ddev describe >/dev/null 2>&1; then
    log "Configuring DDEV project (type: $PROJECT_TYPE)..."
    ddev config --project-name "drupal-test-$DIR_KEY" --project-type "$PROJECT_TYPE" --docroot . \
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
    RESULTS["$DIR_KEY"]="FAIL (no repos/drupal)"
    DURATIONS["$DIR_KEY"]=$((SECONDS - START))
    cd "$HOME"
    continue
  fi

  # --- Checkout branch ---
  CURRENT_BRANCH=$(git -C "$REPOS_DIR" branch --show-current 2>/dev/null || echo "")
  TARGET_BRANCH="${BRANCH:-main}"
  if [ "$CURRENT_BRANCH" = "$TARGET_BRANCH" ]; then
    log "Already on branch: $TARGET_BRANCH"
  elif [ -n "$ISSUE" ]; then
    # Issue fork: fetch from issue-specific remote
    log "Adding issue fork remote and fetching..."
    git -C "$REPOS_DIR" remote remove issue 2>/dev/null || true
    git -C "$REPOS_DIR" remote add issue "https://git.drupalcode.org/issue/drupal-$ISSUE.git"
    if ! git -C "$REPOS_DIR" fetch issue 2>&1; then
      log "ERROR: git fetch from issue remote failed"
      RESULTS["$DIR_KEY"]="FAIL (git fetch)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
    log "Checking out branch: $BRANCH"
    if ! (git -C "$REPOS_DIR" checkout -b "$BRANCH" "issue/$BRANCH" 2>&1 || \
          git -C "$REPOS_DIR" checkout "$BRANCH" 2>&1); then
      log "ERROR: branch checkout failed"
      RESULTS["$DIR_KEY"]="FAIL (git checkout)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
  elif [ "$TARGET_BRANCH" != "main" ]; then
    # Plain origin branch (e.g. 10.6.x, 11.x)
    log "Fetching from origin and checking out $TARGET_BRANCH..."
    git -C "$REPOS_DIR" fetch origin 2>&1 | tail -3
    if ! (git -C "$REPOS_DIR" checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH" 2>&1 || \
          git -C "$REPOS_DIR" checkout "$TARGET_BRANCH" 2>&1); then
      log "ERROR: branch checkout failed"
      RESULTS["$DIR_KEY"]="FAIL (git checkout)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
    log "Checked out $TARGET_BRANCH"
  fi

  # --- Apply composer.json fixes ---
  # joachim-n/drupal-core-development-project:dev-main uses "*" for all drupal/* constraints.
  # Issue fork branches present as dev-ISSUEBRANCH; drupal/core-recommended's N.x-dev
  # requirement won't match that, so Fix 1+2 adds an inline alias for issue forks only.
  # Named release branches (10.6.x, 11.x) present at 10.6.x-dev / 11.x-dev — the "*"
  # constraints from the scaffold work fine. 12.x (main) also needs no fix.
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

  # Fix 1+2 (issue forks on 10.x/11.x only): inline alias so path repo packages satisfy
  # each other's N.x-dev constraints. Issue fork branches present as dev-ISSUEBRANCH, which
  # doesn't satisfy drupal/core-recommended's requirement of e.g. 10.6.x-dev. Named release
  # branches (10.6.x, 11.x) already present at 10.6.x-dev / 11.x-dev so no fix is needed —
  # the original "*" constraints in the scaffold work fine. 12.x also needs no fix.
  if [ "$ACTUAL_DRUPAL_MAJOR" != "12" ] && [ -n "$ISSUE" ]; then
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
