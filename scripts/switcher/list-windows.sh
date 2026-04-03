#!/usr/bin/env bash
# List all tmux windows with cc-state icons.
# Usage: list_windows.sh [--cc-only]
set -euo pipefail

CC_ONLY="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read icons from tmux options (once)
icon_running=$(tmux show-option -gqv "@cc-state-running" 2>/dev/null)
icon_needs_input=$(tmux show-option -gqv "@cc-state-needs-input" 2>/dev/null)
icon_done=$(tmux show-option -gqv "@cc-state-done" 2>/dev/null)
: "${icon_running:=●}" "${icon_needs_input:=◆}" "${icon_done:=✓}"

# Batch: get all window states in one call
declare -A win_states
while IFS=$'\t' read -r wid state; do
  win_states[$wid]="$state"
done < <("$SCRIPT_DIR/../status/window-state.sh" --all)

# Output windows with icons
tmux list-windows -a -F "#{session_name}:#{window_index}:#{window_id}:#{window_name}" |
  while IFS= read -r line; do
    wid="${line#*:}" ; wid="${wid#*:}" ; wid="${wid%%:*}"
    state="${win_states[$wid]:-}"
    case "$state" in
    running)     printf '%s %s\n' "$line" "$icon_running" ;;
    needs-input) printf '%s %s\n' "$line" "$icon_needs_input" ;;
    done)        printf '%s %s\n' "$line" "$icon_done" ;;
    *)           [ "$CC_ONLY" != "--cc-only" ] && printf '%s\n' "$line" ;;
    esac
  done
