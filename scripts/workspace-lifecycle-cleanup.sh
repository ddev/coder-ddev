#!/usr/bin/env bash
# Notify and delete idle workspaces on coder.ddev.com.
#
# Why this exists:
#   Stopping a workspace does not free its Docker volume — each Sysbox
#   workspace keeps a multi-GB dind-cache volume until the workspace is
#   deleted (the destroy provisioner in each template removes it). With no
#   lifecycle policy, stopped workspaces accumulate forever and slowly fill
#   /data on the host. This janitor enforces: notify at N days idle, delete
#   7 days after the notice if the workspace is still untouched.
#
# Policy (state machine per workspace, keyed by workspace id):
#   - Not yet notified, age(last_used_at) >= NOTIFY_DAYS
#       -> email the owner, record notified_at=now in the state file
#   - Already notified, but last_used_at advanced past the notice
#       -> the owner came back; clear the state entry (no deletion)
#   - Already notified, DELETE_AFTER_DAYS have passed since notified_at,
#     and last_used_at still hasn't advanced
#       -> `coder delete <owner>/<name>`, drop the state entry (on failure
#          the entry is kept so deletion is retried next run)
#   - Already notified, still within the grace window
#       -> leave alone
#   - State entry exists for a workspace that no longer exists
#       -> drop the stale entry
#
# The very first run against a fleet with no history only sends notices —
# nothing is old enough to be "already notified" yet, so nothing gets
# deleted until a full DELETE_AFTER_DAYS grace period has elapsed from the
# first notice. That is the intended one-time "grandfather" behavior; no
# separate rollout mode is needed.
#
# One-off purge mode (--purge-idle-days=N):
#   Bypasses the notify/grace state machine and deletes every workspace idle
#   >= N days (EXCLUDE_OWNERS still applies). Sends no email and neither
#   reads nor writes the state file — the next normal run prunes state
#   entries for anything purged here. Use when owners have already been
#   notified out of band. Like everything else, it's a dry run unless
#   combined with --force. Mailgun credentials are not required.
#
# By default runs in dry-run mode (prints what would happen, does not send
# email, delete workspaces, or write the state file). Pass --force to act.
#
# Requires: coder CLI (authenticated), jq, curl, a Mailgun account.
#
# Environment:
#   CODER_URL          Coder deployment to operate on (informational; auth
#                       is whatever the coder CLI is currently logged into)
#   NOTIFY_DAYS         Idle days before the first notice (default: 7)
#   DELETE_AFTER_DAYS   Days after notice before deletion (default: 7)
#   EXCLUDE_OWNERS      Space-separated owner usernames to skip (default: ci-bot)
#   STATE_FILE          Path to the JSON state file
#                       (default: scripts/state/workspace-lifecycle-state.json)
#   MAILGUN_API_KEY     Mailgun private API key (required to send, not for dry-run)
#   MAILGUN_DOMAIN      Mailgun sending domain, e.g. mg.ddev.com
#   MAILGUN_BASE_URL    Mailgun API base (default: https://api.mailgun.net/v3;
#                       use https://api.eu.mailgun.net/v3 for EU-region domains)
#   MAILGUN_FROM        From header (default: "DDEV Coder <support@ddev.com>")
#   ANNOUNCE_URL        Blog post explaining the auth change
#                       (default: https://ddev.com/blog/coder-ddev-com-announcement/)
#
# Usage:
#   ./scripts/workspace-lifecycle-cleanup.sh                            # dry run
#   ./scripts/workspace-lifecycle-cleanup.sh --force                    # actually notify/delete
#   ./scripts/workspace-lifecycle-cleanup.sh --purge-idle-days=14           # preview purge
#   ./scripts/workspace-lifecycle-cleanup.sh --purge-idle-days=14 --force   # delete idle >=14d now

set -euo pipefail

NOTIFY_DAYS="${NOTIFY_DAYS:-7}"
DELETE_AFTER_DAYS="${DELETE_AFTER_DAYS:-7}"
EXCLUDE_OWNERS="${EXCLUDE_OWNERS:-ci-bot}"
STATE_FILE="${STATE_FILE:-scripts/state/workspace-lifecycle-state.json}"
MAILGUN_BASE_URL="${MAILGUN_BASE_URL:-https://api.mailgun.net/v3}"
MAILGUN_FROM="${MAILGUN_FROM:-DDEV Coder <support@ddev.com>}"
ANNOUNCE_URL="${ANNOUNCE_URL:-https://ddev.com/blog/coder-ddev-com-announcement/}"
FORCE=false
PURGE_IDLE_DAYS=""

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --purge-idle-days=*)
      PURGE_IDLE_DAYS="${arg#*=}"
      if ! [[ "$PURGE_IDLE_DAYS" =~ ^[0-9]+$ ]] || [[ "$PURGE_IDLE_DAYS" -eq 0 ]]; then
        echo "ERROR: --purge-idle-days requires a whole number of days >= 1, got '${PURGE_IDLE_DAYS}'" >&2
        exit 1
      fi
      ;;
    --help | -h)
      awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ "$FORCE" == false ]]; then
  echo "DRY RUN — pass --force to actually notify/delete and persist state"
  echo
fi

# Purge mode sends no email, so Mailgun credentials are only needed for
# the normal notify/delete flow.
if [[ "$FORCE" == true && -z "$PURGE_IDLE_DAYS" ]]; then
  : "${MAILGUN_API_KEY:?MAILGUN_API_KEY is required with --force}"
  : "${MAILGUN_DOMAIN:?MAILGUN_DOMAIN is required with --force}"
fi

# Portable date handling: prefer GNU date (Linux, or `gdate` from
# coreutils on macOS); fall back to BSD date's `-j -f` / `-r` syntax.
if date -d "1970-01-01T00:00:00Z" +%s >/dev/null 2>&1; then
  DATE_BIN=(date)
elif command -v gdate >/dev/null 2>&1; then
  DATE_BIN=(gdate)
else
  DATE_BIN=()
fi

iso_to_epoch() {
  local iso="$1"
  if [[ ${#DATE_BIN[@]} -gt 0 ]]; then
    "${DATE_BIN[@]}" -d "$iso" +%s 2>/dev/null && return
  fi
  date -j -f "%Y-%m-%dT%H:%M:%S" "${iso%%.*}" +%s 2>/dev/null || echo 0
}

epoch_to_ymd() {
  local epoch="$1"
  if [[ ${#DATE_BIN[@]} -gt 0 ]]; then
    "${DATE_BIN[@]}" -d "@${epoch}" +%Y-%m-%d 2>/dev/null && return
  fi
  date -j -r "$epoch" +%Y-%m-%d 2>/dev/null || echo "unknown"
}

epoch_to_iso() {
  local epoch="$1"
  if [[ ${#DATE_BIN[@]} -gt 0 ]]; then
    "${DATE_BIN[@]}" -u -d "@${epoch}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return
  fi
  date -u -j -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null
}

if ! workspaces_json=$(coder list --all --output json 2>/dev/null); then
  echo "ERROR: 'coder list --all --output json' failed. Is the coder CLI authenticated?" >&2
  exit 1
fi

workspace_count=$(echo "$workspaces_json" | jq 'length')
if [[ "$workspace_count" -eq 0 ]]; then
  echo "ERROR: 'coder list' returned zero workspaces. Refusing to proceed — this looks like an auth or connectivity problem, not an empty fleet." >&2
  exit 1
fi

now=$(date +%s)

# --- One-off purge mode: delete everything idle >= N days, no notices ---
if [[ -n "$PURGE_IDLE_DAYS" ]]; then
  purge_deleted=0 purge_failed=0 purge_kept=0
  while IFS=$'\t' read -r id name owner last_used_at; do
    [[ -z "$id" ]] && continue

    if grep -qx "$owner" <<<"$(tr ' ' '\n' <<<"$EXCLUDE_OWNERS")"; then
      continue
    fi

    last_epoch=$(iso_to_epoch "$last_used_at")
    age_days=$(((now - last_epoch) / 86400))

    if [[ "$age_days" -ge "$PURGE_IDLE_DAYS" ]]; then
      echo "DELETE  $owner/$name — idle ${age_days}d (>= ${PURGE_IDLE_DAYS}d)"
      purge_deleted=$((purge_deleted + 1))
      if [[ "$FORCE" == true ]]; then
        if ! coder delete "$owner/$name" --yes; then
          echo "  WARN: delete failed for $owner/$name" >&2
          purge_deleted=$((purge_deleted - 1))
          purge_failed=$((purge_failed + 1))
        fi
      fi
    else
      purge_kept=$((purge_kept + 1))
    fi
  done < <(echo "$workspaces_json" | jq -r '.[] | [.id, .name, .owner_name, .last_used_at] | @tsv')

  echo
  echo "Purge summary: deleted=$purge_deleted failed=$purge_failed kept=$purge_kept"
  if [[ "$FORCE" == false ]]; then
    echo
    echo "Re-run with --force to actually delete."
  fi
  exit 0
fi

mkdir -p "$(dirname "$STATE_FILE")"
if [[ -f "$STATE_FILE" ]]; then
  state_json=$(cat "$STATE_FILE")
else
  state_json='{}'
fi

# Persist immediately after every state transition, not just at the end of
# the run: notice emails are the one side effect that can't be taken back,
# so a mid-run failure must not forget who has already been notified.
persist_state() {
  if [[ "$FORCE" == true ]]; then
    echo "$state_json" | jq '.' >"$STATE_FILE"
  fi
}

if ! users_json=$(coder users list --output json 2>/dev/null); then
  echo "ERROR: 'coder users list --output json' failed." >&2
  exit 1
fi

send_notice_email() {
  local to_email="$1" owner_name="$2" workspace_name="$3" last_used_human="$4" delete_date_human="$5"

  local subject="Action needed: your coder.ddev.com workspace \"${workspace_name}\" will be deleted on ${delete_date_human}"
  local body
  body=$(
    cat <<EOF
Hi ${owner_name},

Your DDEV Coder workspace "${workspace_name}" on coder.ddev.com hasn't been
used since ${last_used_human}. To keep the shared server healthy, idle
workspaces are automatically deleted after two weeks of inactivity.

If you don't log in and use this workspace before ${delete_date_human}, it
(and everything in it that isn't pushed elsewhere) will be permanently
deleted.

To keep it: just log in and start the workspace at https://coder.ddev.com
before that date.

Can't log in anymore?
We recently tightened access to coder.ddev.com to a GitHub-org-based login.
If you used to have access and now can't sign in, that's almost certainly
why — see the announcement for details on what changed and how to get
access back:

  ${ANNOUNCE_URL}

If you're a DDEV partner, coder.ddev.com is free as a partner perk — the
announcement above explains how that works too.

Sorry for the inconvenience, and thanks for helping us keep the server
usable for everyone.

— The DDEV team
EOF
  )

  if [[ "$FORCE" == true ]]; then
    if ! curl -sf --user "api:${MAILGUN_API_KEY}" \
      "${MAILGUN_BASE_URL}/${MAILGUN_DOMAIN}/messages" \
      -F from="${MAILGUN_FROM}" \
      -F to="${to_email}" \
      -F subject="${subject}" \
      -F text="${body}" >/dev/null; then
      echo "  WARN: Mailgun send to ${to_email} failed" >&2
      return 1
    fi
  fi
}

notified=0 revived=0 deleted=0 pending=0 kept=0 pruned=0

# --- Prune state entries for workspaces that no longer exist ---
current_ids=$(echo "$workspaces_json" | jq -r '.[].id')
new_state_json="$state_json"
while IFS= read -r stale_id; do
  [[ -z "$stale_id" ]] && continue
  if ! grep -qx "$stale_id" <<<"$current_ids"; then
    echo "PRUNE  state entry for deleted workspace $stale_id"
    new_state_json=$(echo "$new_state_json" | jq --arg id "$stale_id" 'del(.[$id])')
    pruned=$((pruned + 1))
  fi
done < <(echo "$state_json" | jq -r 'keys[]')
state_json="$new_state_json"
persist_state

# --- Walk workspaces ---
while IFS=$'\t' read -r id name owner last_used_at; do
  [[ -z "$id" ]] && continue

  if grep -qx "$owner" <<<"$(tr ' ' '\n' <<<"$EXCLUDE_OWNERS")"; then
    continue
  fi

  last_epoch=$(iso_to_epoch "$last_used_at")
  age_days=$(((now - last_epoch) / 86400))

  entry=$(echo "$state_json" | jq --arg id "$id" '.[$id]')

  if [[ "$entry" != "null" ]]; then
    notified_at=$(echo "$entry" | jq -r '.notified_at')
    notified_epoch=$(iso_to_epoch "$notified_at")

    if [[ "$last_epoch" -gt "$notified_epoch" ]]; then
      echo "REVIVE  $name (owner=$owner) — used again since notice, clearing pending deletion"
      revived=$((revived + 1))
      state_json=$(echo "$state_json" | jq --arg id "$id" 'del(.[$id])')
      persist_state
      continue
    fi

    since_notice_days=$(((now - notified_epoch) / 86400))
    if [[ "$since_notice_days" -ge "$DELETE_AFTER_DAYS" ]]; then
      echo "DELETE  $owner/$name — idle ${age_days}d, notified ${since_notice_days}d ago"
      deleted=$((deleted + 1))
      if [[ "$FORCE" == true ]]; then
        if coder delete "$owner/$name" --yes; then
          state_json=$(echo "$state_json" | jq --arg id "$id" 'del(.[$id])')
          persist_state
        else
          echo "  WARN: delete failed for $owner/$name — keeping state entry to retry next run" >&2
        fi
      fi
    else
      echo "PENDING $name (owner=$owner) — notified ${since_notice_days}d ago, deletes in $((DELETE_AFTER_DAYS - since_notice_days))d unless used"
      pending=$((pending + 1))
    fi
    continue
  fi

  if [[ "$age_days" -ge "$NOTIFY_DAYS" ]]; then
    owner_email=$(echo "$users_json" | jq -r --arg u "$owner" '.[] | select(.username==$u) | .email // empty')
    owner_display=$(echo "$users_json" | jq -r --arg u "$owner" '.[] | select(.username==$u) | .name // empty')
    if [[ -z "$owner_email" ]]; then
      echo "  WARN: no email found for owner $owner (workspace $name), skipping notice" >&2
      continue
    fi

    last_used_human=$(epoch_to_ymd "$last_epoch")
    delete_epoch=$((now + DELETE_AFTER_DAYS * 86400))
    delete_date_human=$(epoch_to_ymd "$delete_epoch")

    echo "NOTIFY  $name (owner=$owner <$owner_email>) — idle ${age_days}d, last used $last_used_human, deletes $delete_date_human unless used"
    if send_notice_email "$owner_email" "${owner_display:-$owner}" "$name" "$last_used_human" "$delete_date_human"; then
      notified=$((notified + 1))
      state_json=$(echo "$state_json" | jq --arg id "$id" --arg at "$(epoch_to_iso "$now")" --arg name "$name" --arg owner "$owner" \
        '.[$id] = {notified_at: $at, name: $name, owner: $owner}')
      persist_state
    else
      echo "  WARN: notice for $name not recorded; will retry next run" >&2
    fi
  else
    kept=$((kept + 1))
  fi
done < <(echo "$workspaces_json" | jq -r '.[] | [.id, .name, .owner_name, .last_used_at] | @tsv')

echo
echo "Summary: notified=$notified pending=$pending deleted=$deleted revived=$revived kept=$kept pruned=$pruned"

if [[ "$FORCE" == true ]]; then
  persist_state
  echo "State written to $STATE_FILE"
else
  echo
  echo "Re-run with --force to send notices, delete workspaces, and persist state."
fi
