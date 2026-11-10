#!/usr/bin/env bash
set -eu
mkdir -p "$HOME/migration/.ddev" "$HOME/migration/.claude"
printf 'name: migration\n' > "$HOME/migration/.ddev/config.yaml"
printf '{"mcpServers":{"drupal":{"headersHelper":"helper"},"storybook":{"url":"http://localhost:6005/mcp"}}}\n' > "$HOME/migration/.mcp.json"
printf '#!/bin/sh\nprintf '\''{"Authorization":"Bearer test-token"}\\n'\''\n' > "$HOME/migration/.claude/mcp-headers.sh"
chmod +x "$HOME/migration/.claude/mcp-headers.sh"
touch "$HOME/migration/AGENTS.md"
