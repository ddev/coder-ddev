#!/usr/bin/env bash
# Reap stale CI workspaces and accumulated template versions on the staging
# Coder instance.
#
# Why this exists:
#   Each integration-test run pushes a template version and creates a workspace,
#   both owned by the CI user (ci-bot). The per-run cleanup (coder delete +
#   coder templates versions archive) lives in `if: always()` steps inside the
#   test job. When a run is cancelled (cancel-in-progress on a new push), force
#   killed, or its workspace lands in `Failed`, those steps never reach the
#   server — GitHub frees its runner but staging keeps the running workspace and
#   the un-archived version. Over many PR pushes this backs staging up.
#
#   This janitor is decoupled from any individual test job: it runs on a schedule
#   and reaps by owner + state + age, so cancellation can never leave an orphan
#   alive longer than one janitor interval. It also handles merged / closed /
#   abandoned PRs, where no replacement run ever comes to clean up.
#
# What it reaps (only workspaces owned by $CI_OWNER, default ci-bot):
#   - failed / stopped / canceled  -> deleted regardless of age
#   - running                      -> deleted if its latest build is older than
#                                     $AGE_MINUTES (default 20)
#   - pending / starting / stopping / canceling / deleting -> left alone
#                                     (transitional; caught on a later pass)
# Then archives all unused template versions for each CI template.
#
# By default runs in dry-run mode (prints what would be deleted).
# Pass --force (or set DRY_RUN=false) to actually delete/archive.
#
# Requires: coder CLI authenticated as a template-admin who owns the CI workspaces.
#
# Environment overrides:
#   CI_OWNER      Coder username that owns CI workspaces (default: ci-bot)
#   AGE_MINUTES   Age threshold in minutes for running workspaces (default: 20)
#   DRY_RUN       true|false (default: true; --force sets false)
#   TEMPLATES     space-separated template names to archive versions for
#
# Usage:
#   ./scripts/ci-reap-staging.sh                 # dry run
#   ./scripts/ci-reap-staging.sh --force         # actually reap
#   AGE_MINUTES=60 ./scripts/ci-reap-staging.sh --force

set -euo pipefail

CI_OWNER="${CI_OWNER:-ci-bot}"
AGE_MINUTES="${AGE_MINUTES:-20}"
DRY_RUN="${DRY_RUN:-true}"
TEMPLATES="${TEMPLATES:-drupal-core drupal-contrib freeform user-defined-web}"

for arg in "$@"; do
  case "$arg" in
    --force) DRY_RUN=false ;;
    --help | -h)
      sed -n '2,40p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY RUN — pass --force (or DRY_RUN=false) to actually reap"
  echo
fi

now=$(date +%s)
cutoff=$((now - AGE_MINUTES * 60))

if ! workspaces_json=$(coder list --all --output json 2>/dev/null); then
  echo "ERROR: 'coder list --all --output json' failed. Is the coder CLI authenticated?" >&2
  exit 1
fi

# --- Workspaces ---
# Emit: name <TAB> status <TAB> build_created  for $CI_OWNER-owned workspaces only.
reaped=0 kept=0
while IFS=$'\t' read -r name status build_created; do
  [[ -z "$name" ]] && continue

  reap_reason=""
  case "$status" in
    failed | stopped | canceled)
      reap_reason="status=$status"
      ;;
    running | started)
      build_epoch=$(date -d "$build_created" +%s 2>/dev/null || echo 0)
      if [[ "$build_epoch" -gt 0 && "$build_epoch" -lt "$cutoff" ]]; then
        age_min=$(((now - build_epoch) / 60))
        reap_reason="running ${age_min}m (>${AGE_MINUTES}m)"
      fi
      ;;
    *)
      # pending / starting / stopping / canceling / deleting — transitional, skip
      ;;
  esac

  if [[ -n "$reap_reason" ]]; then
    echo "REAP  $name  [$reap_reason]"
    reaped=$((reaped + 1))
    if [[ "$DRY_RUN" != "true" ]]; then
      coder delete "$name" --yes || echo "  WARN: delete failed for $name" >&2
    fi
  else
    kept=$((kept + 1))
  fi
done < <(echo "$workspaces_json" |
  jq -r --arg owner "$CI_OWNER" \
    '.[] | select(.owner_name==$owner) | [.name, .latest_build.status, .latest_build.created_at] | @tsv')

echo
echo "Workspaces: reaped=$reaped kept=$kept (owner=$CI_OWNER, age=${AGE_MINUTES}m)"
echo

# --- Template versions ---
# `coder templates archive <t> --all` archives every unused version (never the
# active one, never one with a live workspace), which is exactly what we want.
echo "Archiving unused template versions..."
for t in $TEMPLATES; do
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  would: coder templates archive $t --all --yes"
  else
    coder templates archive "$t" --all --yes || echo "  WARN: archive failed for $t" >&2
  fi
done

echo
echo "Done."
