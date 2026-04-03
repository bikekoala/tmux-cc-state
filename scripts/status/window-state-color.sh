#!/usr/bin/env bash
# Output a color value based on the aggregated CC state for a window.
# Usage: window-state-color.sh <window_id> <fallback_color>
#
# State-to-color mapping:
#   running      → green  (#5faf5f)
#   needs-input  → yellow (#d7af5f)
#   done         → grey   (#808080)
#   (no state)   → fallback_color (passed by caller)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

window_id="${1:-}"
fallback="${2:-}"

state=$("$SCRIPT_DIR/window-state.sh" "$window_id")

get_option() {
  local value
  value=$(tmux show-option -gqv "$1" 2>/dev/null)
  printf '%s' "${value:-$2}"
}

case "$state" in
running)      get_option '@cc-color-running'     '#5faf5f' ;;
needs-input)  get_option '@cc-color-needs-input'  '#d7af5f' ;;
done)         get_option '@cc-color-done'          '#808080' ;;
*)            printf '%s' "$fallback" ;;
esac
