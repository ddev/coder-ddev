#!/usr/bin/env bash
# test-freeform-startup-hook.sh — Test the optional ~/.coder-startup.sh user hook.
# Run inside a freeform workspace: `install` before a workspace restart,
# `verify` after the agent has reconnected.
#
# Usage: bash test-freeform-startup-hook.sh install|verify
#
# The test hook records its PATH lookups to /tmp (wiped when the container is
# recreated, so a result there proves the hook ran on this start), then keeps
# running forever. The agent finishing its startup script while the hook is
# still running shows the hook is detached and can't block workspace startup.

set -euo pipefail

HOOK="$HOME/.coder-startup.sh"
RESULT=/tmp/ci-startup-hook-result
PIDFILE=/tmp/ci-startup-hook-pid
HOOK_LOG=/tmp/coder-startup-user.log

case "${1:-}" in
  install)
    cat > "$HOOK" << 'EOF'
#!/usr/bin/env bash
echo $$ > /tmp/ci-startup-hook-pid   # written first; exec below keeps this PID
{
  echo "claude=$(command -v claude || echo MISSING)"
  echo "ddev=$(command -v ddev || echo MISSING)"
} > /tmp/ci-startup-hook-result
echo "ci startup hook ran"
exec sleep infinity
EOF
    chmod +x "$HOOK"
    echo "Installed $HOOK"
    ;;

  verify)
    # The startup script launches the hook as its last step; give it a moment.
    for _ in $(seq 30); do
      [ -s "$RESULT" ] && break
      sleep 1
    done
    if [ ! -s "$RESULT" ]; then
      echo "ERROR: $RESULT not written — ~/.coder-startup.sh did not run on workspace start" >&2
      echo "--- $HOOK_LOG:" >&2
      cat "$HOOK_LOG" >&2 2>/dev/null || echo "(missing)" >&2
      exit 1
    fi
    echo "--- $RESULT:"
    cat "$RESULT"
    if grep -q MISSING "$RESULT"; then
      echo "ERROR: hook PATH is missing claude or ddev" >&2
      exit 1
    fi
    if ! grep -q "ci startup hook ran" "$HOOK_LOG"; then
      echo "ERROR: hook output not in $HOOK_LOG" >&2
      exit 1
    fi
    HOOK_PID=$(cat "$PIDFILE" 2>/dev/null || true)
    if [ -z "$HOOK_PID" ] || ! kill -0 "$HOOK_PID" 2>/dev/null; then
      echo "ERROR: hook is no longer running — it should still be running detached" >&2
      exit 1
    fi
    echo "OK: hook ran on start, found claude and ddev, logged to $HOOK_LOG, and is still running detached"
    rm -f "$HOOK"
    kill "$HOOK_PID" || true
    ;;

  *)
    echo "Usage: $0 install|verify" >&2
    exit 2
    ;;
esac
