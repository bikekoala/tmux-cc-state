#!/usr/bin/env bash
# Create a new tmux window (and session if needed), then switch to it.
# $1 = window name, $2 = session name (defaults to $1)

win_name="${1}"
sess_name="${2:-${win_name}}"

if ! tmux has-session -t "${sess_name}" 2>/dev/null; then
    tmux new-session -d -s "${sess_name}"
fi

wid=$(tmux new-window -t "${sess_name}" -d -n "${win_name}" -P -F "#{window_id}")
tmux switch-client -t "${wid}"
