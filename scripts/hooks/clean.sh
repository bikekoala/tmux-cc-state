#!/usr/bin/env bash
# Clean up all CC state for the current pane: CC_PANE_{id}_STATE and CC_PANE_{id}_SA_*
# Called by SessionEnd hook.

set -euo pipefail

LOG_FILE="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$0")")")}/cc-state.log"
log() { [ "${CC_STATE_DEBUG:-0}" = "1" ] && printf '%s [clean] %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG_FILE"; return 0; }

if [ -z "${TMUX:-}" ] || ! command -v tmux >/dev/null 2>&1; then
  exit 0
fi

pane_id="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}')}"
pane_num="${pane_id#%}"
prefix="CC_PANE_${pane_num}_"

cleaned=0
while IFS='=' read -r key _; do
  tmux set-environment -gu "$key" 2>/dev/null || true
  cleaned=$(( cleaned + 1 ))
done < <(tmux show-environment -g 2>/dev/null | grep "^${prefix}" || true)

log "pane=${pane_id} cleaned=${cleaned} vars"
tmux refresh-client -S 2>/dev/null || true
