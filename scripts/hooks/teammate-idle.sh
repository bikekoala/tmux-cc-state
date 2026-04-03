#!/usr/bin/env bash
# Handle TeammateIdle for both in-process and tmux teammates.
# Reads teammate_name/team_name from stdin JSON.
#
# Detection: if this pane owns a SA var for the teammate,
# we're the leader (in-process context); otherwise we're
# the tmux teammate itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}/cc-state.log"
log() { [ "${CC_STATE_DEBUG:-0}" = "1" ] && printf '%s [teammate-idle] %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG_FILE"; return 0; }

INPUT=""
read -r INPUT || true
[ -z "$INPUT" ] && exit 0

if [ -z "${TMUX:-}" ] || ! command -v tmux >/dev/null 2>&1; then
  exit 0
fi

teammate=$(printf '%s' "$INPUT" | jq -r '.teammate_name // empty')
team=$(printf '%s' "$INPUT" | jq -r '.team_name // empty')
pane_id="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}')}"
pane_num="${pane_id#%}"

if [ -n "$teammate" ] && [ -n "$team" ]; then
  safe_id=$(printf '%s' "${teammate}_${team}" | tr -c 'A-Za-z0-9_-' '_')
  env_key="CC_PANE_${pane_num}_SA_${safe_id}"
  existing=$(tmux show-environment -g "$env_key" 2>/dev/null | sed 's/^[^=]*=//' || true)
  if [ -n "$existing" ]; then
    # In-process: this pane owns the SA var → we're the leader
    tmux set-environment -g "$env_key" done
    log "in-process: name=$teammate team=$team sa=$env_key -> done"
    exec "$SCRIPT_DIR/set-state.sh" running
  fi

  # Tmux teammate: search globally for the SA var on the leader pane
  matched=$(tmux show-environment -g 2>/dev/null | grep "_SA_${safe_id}=" | head -1 || true)
  if [ -n "$matched" ]; then
    matched_key="${matched%%=*}"
    tmux set-environment -g "$matched_key" done
    log "tmux: name=$teammate team=$team sa=$matched_key -> done"
    tmux refresh-client -S 2>/dev/null || true
    exec "$SCRIPT_DIR/set-state.sh" done
  fi
fi

# Tmux teammate: no SA var found, just set own pane to done
log "tmux: name=$teammate team=$team pane=${pane_id} (no SA var)"
exec "$SCRIPT_DIR/set-state.sh" done
