#!/usr/bin/env bash
# Handle PreToolUse(SendMessage) to restore teammate SA var from done → running.
# SendMessage is the only way to wake an idle teammate, so intercepting it
# tracks the idle→running transition on the leader side.
#
# stdin JSON provides tool_input.to (teammate name).
# We find the matching CC_PANE_{pane}_SA_{name}* var and set it to running.

set -euo pipefail

LOG_FILE="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$0")")")}/cc-state.log"
log() { [ "${CC_STATE_DEBUG:-0}" = "1" ] && printf '%s [teammate-wake] %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG_FILE"; return 0; }

INPUT=""
read -r INPUT || true
[ -z "$INPUT" ] && exit 0

to=$(printf '%s' "$INPUT" | jq -r '.tool_input.to // empty')
[ -z "$to" ] && exit 0

if [ -z "${TMUX:-}" ] || ! command -v tmux >/dev/null 2>&1; then
  exit 0
fi

pane_id="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}')}"
pane_num="${pane_id#%}"
prefix="CC_PANE_${pane_num}_SA_"

# Sanitize the teammate name the same way agent-spawn.sh does
safe_name=$(printf '%s' "$to" | tr -c 'A-Za-z0-9_-' '_')

# Find matching SA var: prefix + safe_name (+ _ + team suffix)
matched=""
while IFS= read -r line; do
  key="${line%%=*}"
  case "$key" in
    ${prefix}${safe_name}_*)
      matched="$key"
      break
      ;;
  esac
done < <(tmux show-environment -g 2>/dev/null | grep "^${prefix}${safe_name}_" || true)

if [ -z "$matched" ]; then
  # Teammate-to-teammate: search globally for the SA var on the leader pane
  while IFS= read -r line; do
    key="${line%%=*}"
    case "$key" in
      *_SA_${safe_name}_*)
        matched="$key"
        break
        ;;
    esac
  done < <(tmux show-environment -g 2>/dev/null | grep "_SA_${safe_name}_" || true)
fi

if [ -z "$matched" ]; then
  log "pane=${pane_id} to=${to} no matching SA var"
  exit 0
fi

current=$(tmux show-environment -g "$matched" 2>/dev/null | sed 's/^[^=]*=//' || true)
if [ "$current" != "done" ]; then
  log "pane=${pane_id} to=${to} sa=${matched} already ${current}, skip"
  exit 0
fi

tmux set-environment -g "$matched" running
log "pane=${pane_id} to=${to} sa=${matched} done -> running"
tmux refresh-client -S 2>/dev/null || true
