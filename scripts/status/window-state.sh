#!/usr/bin/env bash
# Aggregate Claude Code pane states for tmux windows.
#
# Usage:
#   window-state.sh <window_id>   — single window, outputs: running | needs-input | done | ""
#   window-state.sh --all         — all windows, outputs: <window_id>\t<state> per line
#
# State layers per pane:
#   CC_PANE_{id}_STATE      — the pane's own CC state
#   CC_PANE_{id}_SA_*       — in-process subagent/teammate states
#
# Priority: running (3) > needs-input (2) > done (1) > off (0)

set -euo pipefail

if ! command -v tmux >/dev/null 2>&1; then
  exit 0
fi

state_priority() {
  case "$1" in
  running) echo 3 ;;
  needs-input) echo 2 ;;
  done) echo 1 ;;
  *) echo 0 ;;
  esac
}

priority_label() {
  case "$1" in
  3) printf 'running' ;;
  2) printf 'needs-input' ;;
  1) printf 'done' ;;
  *) printf '' ;;
  esac
}

# Core aggregation. Reads panes from stdin (window_id\tpane_id\tpane_cmd).
# Args: $1 = env_snapshot, $2 = mode ("single" window_id filter, or "all")
# For "single": outputs state label. For "all": outputs window_id\tstate per line.
aggregate() {
  local env_snapshot="$1"
  local mode="$2"
  local filter_wid="${3:-}"

  declare -A win_max

  while IFS=$'\t' read -r wid pane_id pane_cmd; do
    [ -z "$wid" ] && continue

    # In single mode, skip panes from other windows
    if [ "$mode" = "single" ] && [ "$wid" != "$filter_wid" ]; then
      continue
    fi

    pane_num="${pane_id#%}"
    cur_max="${win_max[$wid]:-0}"
    [ "$cur_max" -eq 3 ] && continue

    state=$(printf '%s\n' "$env_snapshot" | sed -n "s/^CC_PANE_${pane_num}_STATE=//p")

    # Shell foreground means CC exited — clear stale state
    if [ -n "$state" ]; then
      case "$pane_cmd" in
      bash | zsh | fish | sh | dash | ksh)
        if [ "$mode" = "single" ]; then
          # Only clean up env vars in single mode (status bar refresh)
          tmux set-environment -gu "CC_PANE_${pane_num}_STATE" 2>/dev/null || true
          printf '%s\n' "$env_snapshot" | sed -n "s/^\(CC_PANE_${pane_num}_SA_[^=]*\)=.*/\1/p" | while read -r sa_key; do
            tmux set-environment -gu "$sa_key" 2>/dev/null || true
          done
        fi
        state=""
        ;;
      esac
    fi

    p=$(state_priority "$state")
    [ "$p" -gt "$cur_max" ] && cur_max="$p"

    # Check SA vars
    if [ "$cur_max" -lt 3 ]; then
      while IFS='=' read -r _ sa_state; do
        [ -z "$sa_state" ] && continue
        p=$(state_priority "$sa_state")
        [ "$p" -gt "$cur_max" ] && cur_max="$p"
        [ "$cur_max" -eq 3 ] && break
      done < <(printf '%s\n' "$env_snapshot" | grep "^CC_PANE_${pane_num}_SA_" || true)
    fi

    win_max[$wid]="$cur_max"
  done

  if [ "$mode" = "single" ]; then
    priority_label "${win_max[$filter_wid]:-0}"
  else
    for wid in "${!win_max[@]}"; do
      local label
      label=$(priority_label "${win_max[$wid]}")
      [ -n "$label" ] && printf '%s\t%s\n' "$wid" "$label"
    done
  fi
}

main() {
  local env_snapshot
  env_snapshot=$(tmux show-environment -g 2>/dev/null | grep '^CC_PANE_' || true)

  if [ "${1:-}" = "--all" ]; then
    aggregate "$env_snapshot" "all" < <(tmux list-panes -a -F '#{window_id}	#{pane_id}	#{pane_current_command}' 2>/dev/null)
  else
    local window_id="${1:-$(tmux display-message -p '#{window_id}')}"
    aggregate "$env_snapshot" "single" "$window_id" < <(tmux list-panes -t "$window_id" -F '#{window_id}	#{pane_id}	#{pane_current_command}' 2>/dev/null)
  fi
}

main "$@"
