#!/usr/bin/env bash
# Output an icon based on the aggregated CC state for a window.
# Usage: state-icon.sh <window_id>
#
# Customize icons in ~/.tmux.conf:
#   set -g @cc-state-running     '●'
#   set -g @cc-state-needs-input '◆'
#   set -g @cc-state-done        '✓'
#
# Defaults: running=● needs-input=◆ done=✓

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

window_id="${1:-}"

state=$("$SCRIPT_DIR/window-state.sh" "$window_id")

[ -z "$state" ] && exit 0

icon=$(tmux show-option -gqv "@cc-state-${state}" 2>/dev/null)

if [ -z "$icon" ]; then
  case "$state" in
  running)      icon='●' ;;
  needs-input)  icon='◆' ;;
  done)         icon='✓' ;;
  esac
fi

prefix=$(tmux show-option -gqv '@cc-state-prefix' 2>/dev/null)
suffix=$(tmux show-option -gqv '@cc-state-suffix' 2>/dev/null)

printf '%s%s%s' "$prefix" "$icon" "$suffix"
