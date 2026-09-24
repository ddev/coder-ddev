#!/usr/bin/env bash
# Print the Terraform output of failed Coder provisioner jobs for a CI template
# version and/or workspace.
#
# Why this exists:
#   When `coder create` fails in the server-side Terraform step, the CLI shows
#   only the stage names and a bare "initialize terraform: exit status 1" (or
#   "terraform plan/apply: exit status 1"). The actual Terraform error, e.g.
#   "Failed to download module ... TLS handshake timeout", is only in the
#   provisioner job's logs. This fetches them so the CI log shows the cause.
#
# Usage:
#   ci-show-provisioner-errors.sh <template-version-name> [workspace-name]
#
# Covers template imports and dry-runs of that template version, and builds of
# that workspace. Always exits 0: diagnostics must never change a job's result.
set -uo pipefail

TEMPLATE_VERSION="${1:?usage: ci-show-provisioner-errors.sh <template-version-name> [workspace-name]}"
WORKSPACE="${2:-}"

if ! jobs_json=$(coder provisioner jobs list --status failed --limit 100 --output json 2>&1); then
  echo "WARN: 'coder provisioner jobs list' failed; can't show provisioner errors:" >&2
  echo "$jobs_json" >&2
  exit 0
fi

mapfile -t jobs < <(echo "$jobs_json" | jq -c --arg tv "$TEMPLATE_VERSION" --arg ws "$WORKSPACE" '
  .[] | select(
    (.metadata.template_version_name == $tv and (.type == "template_version_import" or .type == "template_version_dry_run"))
    or ($ws != "" and .metadata.workspace_name == $ws)
  )')

if [[ ${#jobs[@]} -eq 0 ]]; then
  echo "No failed provisioner jobs for template version '$TEMPLATE_VERSION'${WORKSPACE:+ or workspace '$WORKSPACE'}"
  exit 0
fi

url=$(coder whoami --output json 2>/dev/null | jq -r 'if type == "array" then .[0].url else .url end')
token=$(coder login token 2>/dev/null || true)
token="${token:-${CODER_SESSION_TOKEN:-}}"

for job in "${jobs[@]}"; do
  id=$(jq -r '.id' <<<"$job")
  type=$(jq -r '.type' <<<"$job")
  tv_id=$(jq -r '.input.template_version_id // empty' <<<"$job")
  build_id=$(jq -r '.input.workspace_build_id // empty' <<<"$job")
  echo "=== Failed provisioner job $id ($type) at $(jq -r '.created_at' <<<"$job")"
  echo "Error: $(jq -r '.error' <<<"$job")"

  case "$type" in
    template_version_import) path="templateversions/$tv_id/logs" ;;
    template_version_dry_run) path="templateversions/$tv_id/dry-run/$id/logs" ;;
    workspace_build) path="workspacebuilds/$build_id/logs" ;;
    *) path="" ;;
  esac
  if [[ -z "$path" || -z "$url" || -z "$token" ]]; then
    echo "WARN: can't fetch logs for this job (type=$type, url/token available: ${url:+yes}/${token:+yes})" >&2
    continue
  fi
  if ! logs=$(curl -sf --max-time 30 -H "Coder-Session-Token: $token" "$url/api/v2/$path"); then
    echo "WARN: fetching $url/api/v2/$path failed" >&2
    continue
  fi
  # Error-level lines carry the Terraform error; the tail gives context.
  echo "--- Terraform errors:"
  jq -r '.[] | select(.log_level == "error") | "  \(.output)"' <<<"$logs"
  echo "--- Last 20 log lines:"
  jq -r '.[] | select(.output != "") | "  [\(.stage)] \(.output)"' <<<"$logs" | tail -20
done
exit 0
