#!/usr/bin/env bash
# Set Claude Code pane state in tmux environment.
# Usage: set-state.sh <running|needs-input|done>

set -euo pipefail

LOG_FILE="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$0")")")}/cc-state.log"
log() { [ "${CC_STATE_DEBUG:-0}" = "1" ] && printf '%s [set-state] %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG_FILE"; return 0; }

if [ -z "${TMUX:-}" ] || ! command -v tmux >/dev/null 2>&1; then
  exit 0
fi

state="${1:-}"
case "$state" in
running | needs-input | done) ;;
*)
  echo "Usage: set-state.sh <running|needs-input|done>" >&2
  exit 1
  ;;
esac

pane_id="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}')}"
env_key="CC_PANE_${pane_id#%}_STATE"

current=$(tmux show-environment -g "$env_key" 2>/dev/null | sed "s/^${env_key}=//" || true)
if [ "$current" = "$state" ]; then
  log "pane=${pane_id} state=$state (unchanged, skip)"
  exit 0
fi

tmux set-environment -g "$env_key" "$state"

log "pane=${pane_id} state=$state"
tmux refresh-client -S 2>/dev/null || true
