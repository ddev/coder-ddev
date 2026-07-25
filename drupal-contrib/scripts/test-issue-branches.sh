#!/usr/bin/env bash
# test-issue-branches.sh — Test drupal-contrib workspace setup locally
# using ddev-drupal-contrib (ddev poser + drush si + module enable).
#
# Usage:
#   bash drupal-contrib/scripts/test-issue-branches.sh              # run all default tests
#   bash drupal-contrib/scripts/test-issue-branches.sh PROJECT:DRUPAL_VERSION
#   bash drupal-contrib/scripts/test-issue-branches.sh PROJECT:DRUPAL_VERSION:ISSUE:BRANCH
#
# Format: PROJECT:DRUPAL_VERSION[:ISSUE[:BRANCH]]
#   PROJECT       — drupal.org machine name (e.g. token, pathauto)
#   DRUPAL_VERSION — 10, 11, or 12
#   ISSUE         — optional issue NID (e.g. 3568144); omit for plain dev
#   BRANCH        — optional branch; required when ISSUE is set
#
# Requirements: ddev, git, jq, curl
# Projects are created in ~/tmp/contrib-test-<project>[-<issue>]/ and left in
# place so you can inspect or restart them. To clean up:
#   cd ~/tmp/contrib-test-<name> && ddev delete -Oy && cd && rm -rf ~/tmp/contrib-test-<name>

DEFAULT_TESTS=(
  "token:11"
  "pathauto:11"
  "token:10"
)

if [ $# -gt 0 ]; then
  TESTS=("$@")
else
  TESTS=("${DEFAULT_TESTS[@]}")
fi

declare -A RESULTS
declare -A DURATIONS

log() { echo "[$(date '+%H:%M:%S')] $*"; }

for SPEC in "${TESTS[@]}"; do
  IFS=':' read -r PROJECT DRUPAL_VERSION ISSUE BRANCH <<< "$SPEC"
  DRUPAL_VERSION="${DRUPAL_VERSION:-11}"
  ISSUE="${ISSUE:-}"
  BRANCH="${BRANCH:-}"

  DIR_KEY="${PROJECT}${ISSUE:+-$ISSUE}"
  PROJECT_DIR="$HOME/tmp/contrib-test-$DIR_KEY"
  START=$SECONDS

  log "========================================================"
  if [ -n "$ISSUE" ]; then
    log "Testing $PROJECT (D$DRUPAL_VERSION) issue #$ISSUE branch: $BRANCH"
  else
    log "Testing $PROJECT (D$DRUPAL_VERSION) plain dev"
  fi
  log "Project dir: $PROJECT_DIR"
  log "========================================================"

  mkdir -p "$PROJECT_DIR"

  # --- Clone project if needed ---
  if [ ! -d "$PROJECT_DIR/$PROJECT/.git" ]; then
    log "Cloning $PROJECT from git.drupalcode.org..."
    if ! git clone "https://git.drupalcode.org/project/$PROJECT.git" \
        "$PROJECT_DIR/$PROJECT" 2>&1 | tail -5; then
      log "ERROR: git clone failed"
      RESULTS["$DIR_KEY"]="FAIL (git clone)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      continue
    fi
  else
    log "Project already cloned — skipping"
  fi

  cd "$PROJECT_DIR/$PROJECT"

  # --- Issue fork checkout ---
  if [ -n "$ISSUE" ] && [ -n "$BRANCH" ]; then
    REMOTE_NAME="issue-$ISSUE"
    FORK_URL="https://git.drupalcode.org/issue/$PROJECT-$ISSUE.git"
    log "Adding issue fork remote: $FORK_URL"
    git remote remove "$REMOTE_NAME" 2>/dev/null || true
    git remote add "$REMOTE_NAME" "$FORK_URL"
    if ! git fetch "$REMOTE_NAME" 2>&1 | tail -3; then
      log "ERROR: git fetch from issue remote failed"
      RESULTS["$DIR_KEY"]="FAIL (git fetch)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
    if ! (git checkout -b "$BRANCH" "$REMOTE_NAME/$BRANCH" 2>&1 || \
          git checkout "$BRANCH" 2>&1); then
      log "ERROR: branch checkout failed"
      RESULTS["$DIR_KEY"]="FAIL (git checkout)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
    log "Checked out issue branch: $BRANCH"
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
  fi

  # --- Configure DDEV if needed ---
  if ! ddev describe >/dev/null 2>&1; then
    log "Configuring DDEV (drupal$DRUPAL_VERSION, docroot=web)..."
    ddev config \
      --project-name "contrib-test-$DIR_KEY" \
      --project-type "drupal$DRUPAL_VERSION" \
      --docroot web 2>&1 | tail -5
    log "Installing ddev-drupal-contrib addon..."
    ddev add-on get ddev/ddev-drupal-contrib 2>&1 | tail -5

    log "Starting DDEV..."
    if ! ddev start 2>&1 | tail -10; then
      log "ERROR: ddev start failed"
      RESULTS["$DIR_KEY"]="FAIL (ddev start)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi
  else
    log "DDEV already configured — skipping init"
  fi

  # --- Add drush as require-dev and run ddev poser ---
  if [ ! -f web/index.php ]; then
    log "Adding drush as require-dev..."
    ddev exec composer require --dev drush/drush --no-update --no-interaction 2>&1 | tail -5

    log "Running ddev poser..."
    POSER_RC=0
    ddev poser > /tmp/poser-attempt.log 2>&1 || POSER_RC=$?
    tail -10 /tmp/poser-attempt.log
    # Mirrors the Guzzle alias fallback in template.tf: Drush still requires
    # guzzlehttp/guzzle ^7.0 while core main requires ^8.0, which makes a plain
    # poser run unsolvable on Drupal 12 HEAD. Removal tracked in #179
    # (upstream: drush-ops/drush#6602).
    if [ "$POSER_RC" != "0" ] && grep -q "drush/drush.*requires guzzlehttp/guzzle" /tmp/poser-attempt.log; then
      GUZZLE_VER=$(curl -fsSL --max-time 30 https://repo.packagist.org/p2/guzzlehttp/guzzle.json 2>/dev/null |
        jq -r '[.packages["guzzlehttp/guzzle"][].version | select(test("^8[.][0-9]+[.][0-9]+$"))] | sort_by(split(".") | map(tonumber)) | last // empty' 2>/dev/null || true)
      if [ -n "$GUZZLE_VER" ]; then
        log "Drush/Guzzle conflict — retrying poser with guzzle $GUZZLE_VER aliased as 7.99.0..."
        jq --arg v "$GUZZLE_VER as 7.99.0" '.["require-dev"]["guzzlehttp/guzzle"] = $v' composer.json > composer.json.tmp && mv composer.json.tmp composer.json
        POSER_RC=0
        ddev poser > /tmp/poser-attempt.log 2>&1 || POSER_RC=$?
        tail -10 /tmp/poser-attempt.log
      fi
    fi
    if [ "$POSER_RC" != "0" ]; then
      log "ERROR: ddev poser failed"
      RESULTS["$DIR_KEY"]="FAIL (ddev poser)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi

    log "Restarting DDEV to trigger symlink-project..."
    ddev restart 2>&1 | tail -5

    log "Installing Drupal (minimal profile)..."
    if ! ddev drush si minimal -y --account-pass=admin 2>&1 | tail -10; then
      log "ERROR: drush si failed"
      RESULTS["$DIR_KEY"]="FAIL (drush si)"
      DURATIONS["$DIR_KEY"]=$((SECONDS - START))
      cd "$HOME"
      continue
    fi

    log "Enabling $PROJECT..."
    if ! ddev drush en "$PROJECT" -y 2>&1; then
      log "WARNING: could not enable $PROJECT (may need manual enable)"
    fi
  else
    log "Drupal already installed — skipping install"
  fi

  # --- Verify ---
  log "Verifying DB connection..."
  DB_STATUS=$(ddev drush status --fields=db-status 2>/dev/null | grep -i connected || echo "")
  if [ -z "$DB_STATUS" ]; then
    log "ERROR: drush status shows DB not connected"
    RESULTS["$DIR_KEY"]="FAIL (db not connected)"
    DURATIONS["$DIR_KEY"]=$((SECONDS - START))
    cd "$HOME"
    continue
  fi

  log "Checking module is enabled..."
  MODULE_STATUS=$(ddev drush pm:list --status=enabled --type=module 2>/dev/null | grep -i "$PROJECT" || echo "")
  if [ -z "$MODULE_STATUS" ]; then
    log "WARNING: $PROJECT not found in enabled modules"
    RESULTS["$DIR_KEY"]="PASS (module not enabled — may need manual enable)"
  else
    RESULTS["$DIR_KEY"]="PASS"
  fi

  DURATIONS["$DIR_KEY"]=$((SECONDS - START))
  log "${RESULTS[$DIR_KEY]} — $DIR_KEY (${DURATIONS[$DIR_KEY]}s)"
  cd "$HOME"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================= SUMMARY ============================="
printf "%-30s %-8s %s\n" "Test" "Time" "Result"
printf "%-30s %-8s %s\n" "----" "----" "------"
for SPEC in "${TESTS[@]}"; do
  IFS=':' read -r PROJECT DRUPAL_VERSION ISSUE BRANCH <<< "$SPEC"
  DIR_KEY="${PROJECT}${ISSUE:+-$ISSUE}"
  LABEL="${PROJECT} D${DRUPAL_VERSION:-11}${ISSUE:+ #$ISSUE}"
  printf "%-30s %-8s %s\n" \
    "$LABEL" "${DURATIONS[$DIR_KEY]:-?}s" "${RESULTS[$DIR_KEY]:-unknown}"
done
echo "==================================================================="
