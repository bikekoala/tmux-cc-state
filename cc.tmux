#!/usr/bin/env bash
# cc-state tmux plugin entry point.
# Sets up status bar interpolation and fzf switcher keybindings.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

color_script="$CURRENT_DIR/scripts/status/window-state-color.sh"
icon_script="$CURRENT_DIR/scripts/status/state-icon.sh"

do_interpolation() {
  local string="$1"
  string="${string//\#\{cc_window_state\}/#($CURRENT_DIR/scripts/status/window-state.sh '#{window_id}')}"
  string="${string//\#\{cc-state\}/#($icon_script '#{window_id}')}"
  string="${string//\#\{cc-daily-token\}/#($CURRENT_DIR/scripts/status/cc-daily.sh token)}"
  string="${string//\#\{cc-daily-cost\}/#($CURRENT_DIR/scripts/status/cc-daily.sh cost)}"
  # Replace #{cc_window_bg:#{@var}} with a #() call that outputs the right color.
  # Uses sed to avoid bash issues with } inside ${string/pattern/replacement}.
  string=$(printf '%s' "$string" | sed -E "s|#\\{cc_window_bg:(#\\{@[a-zA-Z0-9_]+\\})\\}|#($color_script '#{window_id}' '\\1')|g")
  echo "$string"
}

update_tmux_option() {
  local option="$1"
  local value
  value=$(tmux show-option -gqv "$option" 2>/dev/null)
  [ -z "$value" ] && return
  local new_value
  new_value=$(do_interpolation "$value")
  [ "$new_value" = "$value" ] && return
  tmux set-option -gq "$option" "$new_value"
}

get_tmux_option() {
  local value
  value=$(tmux show-option -gqv "$1" 2>/dev/null)
  if [ -z "$value" ]; then
    echo "$2"
  else
    echo "$value"
  fi
}

setup_switcher() {
  local keys_prefix
  keys_prefix=$(get_tmux_option "@cc-switcher-key" "C-f")
  local keys_no_prefix
  keys_no_prefix=$(get_tmux_option "@cc-switcher-key-no-prefix" "")
  local preview_enabled
  preview_enabled=$(get_tmux_option "@cc-switcher-preview" "false")

  local width height
  if [ "$preview_enabled" = true ]; then
    width=$(get_tmux_option "@cc-switcher-width-preview" 80)
    height=$(get_tmux_option "@cc-switcher-height-preview" 20)
  else
    width=$(get_tmux_option "@cc-switcher-width" 55)
    height=$(get_tmux_option "@cc-switcher-height" 10)
  fi

  local preview_option="PREVIEW_ENABLED=$( [ "$preview_enabled" = true ] && echo 1 || echo 0 )"
  local switch_script="$CURRENT_DIR/scripts/switcher/switch.sh"

  local key
  for key in $keys_prefix; do
    tmux bind "$key" display-popup -w "$width" -h "$height" -y 15 -E "$preview_option $switch_script"
  done
  for key in $keys_no_prefix; do
    tmux bind -n "$key" display-popup -w "$width" -h "$height" -y 15 -E "$preview_option $switch_script"
  done
}

main() {
  update_tmux_option "status-right"
  update_tmux_option "status-left"
  update_tmux_option "window-status-format"
  update_tmux_option "window-status-current-format"
  setup_switcher
}

main
