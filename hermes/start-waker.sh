#!/usr/bin/env bash
# Waker service launcher. The sprite does not inject PATH into bare service
# processes, so rebuild it the same way start-hermes.sh does. This service is
# PUBLIC and deliberately does NOT source .env — it must never see secrets.
while IFS= read -r p; do PATH="$p:$PATH"; done < /etc/profile.d/languages_paths
. /etc/profile.d/languages_env 2>/dev/null
PATH="$HOME/.local/bin:$PATH"
export PATH
exec python3 "$HOME/bin/waker.py"
