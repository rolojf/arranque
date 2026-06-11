#!/usr/bin/env bash
# Language PATH (cargo, node, pyenv) — the sprite does not inject it into bare service processes
while IFS= read -r p; do PATH="$p:$PATH"; done < /etc/profile.d/languages_paths
. /etc/profile.d/languages_env 2>/dev/null
PATH="$HOME/.local/bin:$PATH"
export PATH
# tokens and gateway config
set -a
. "$HOME/.hermes/.env"
set +a
# initial task: hold the sprite up from boot until the first pre_llm_call
TASKLOG="$HOME/.hermes/logs/task-startup.log"
echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) start-hermes.sh starting ===" >> "$TASKLOG"
curl -s --unix-socket /.sprite/api.sock \
     -H "Content-Type: application/json" \
     -X PUT http://sprite/v1/tasks/hermes-active \
     -d '{"expire":"5m"}' >> "$TASKLOG" 2>&1
echo "--- task PUT done ---" >> "$TASKLOG"
exec "$HOME/.local/bin/hermes" gateway
