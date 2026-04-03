#!/usr/bin/env bash
# Capture the active pane of a given window for fzf preview.
# Input format from fzf: "session:index:wid:name [icon]"

spec="$1"
IFS=':' read -r sess idx _wid _name <<< "$spec"

if [ -z "$sess" ] || [ -z "$idx" ]; then
  echo "Invalid input: '$spec'"
  exit 1
fi

win="${sess}:${idx}"
pane=$(tmux list-panes -t "$win" -F '#{pane_id} #{pane_active}' | awk '$2 == "1" {print $1}')

if [ -z "$pane" ]; then
  echo "No active pane for $win"
  exit 1
fi

tmux capture-pane -ep -t "$pane"
