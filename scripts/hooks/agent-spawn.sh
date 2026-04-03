#!/usr/bin/env bash
# Track tmux teammate spawn via PreToolUse(Agent).
# Reads tool_input from stdin JSON. Filters out non-team calls.
# Sets CC_PANE_{leader}_SA_{name_team} = running on the leader pane.

set -euo pipefail

LOG_FILE="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$0")")")}/cc-state.log"
log() { [ "${CC_STATE_DEBUG:-0}" = "1" ] && printf '%s [agent-spawn] %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG_FILE"; return 0; }

INPUT=""
read -r INPUT || true
[ -z "$INPUT" ] && exit 0

# Filter: only handle team-based Agent calls
team_name=$(printf '%s' "$INPUT" | jq -r '.tool_input.team_name // empty')
[ -z "$team_name" ] && exit 0

if [ -z "${TMUX:-}" ] || ! command -v tmux >/dev/null 2>&1; then
  exit 0
fi

name=$(printf '%s' "$INPUT" | jq -r '.tool_input.name // empty')
[ -z "$name" ] && exit 0

pane_id="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}')}"
safe_id=$(printf '%s' "${name}_${team_name}" | tr -c 'A-Za-z0-9_-' '_')
env_key="CC_PANE_${pane_id#%}_SA_${safe_id}"

tmux set-environment -g "$env_key" running
log "pane=${pane_id} teammate=${name} team=${team_name} -> running"
tmux refresh-client -S 2>/dev/null || true
