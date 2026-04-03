#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cleanup() { printf '\e[2 q'; }
trap cleanup EXIT

get_tmux_option() {
    local value
    value=$(tmux show-option -gqv "$1" 2>/dev/null)
    printf '%s' "${value:-$2}"
}

function main {
    local windows
    local window
    local query
    local win_arr
    local retval
    local list_script="$CURRENT_DIR/list-windows.sh"
    local header_normal='j/k g/G /search c:cc q'

    local pointer
    pointer=$(get_tmux_option '@cc-switcher-pointer' '>')
    local color
    color=$(get_tmux_option '@cc-switcher-color' '')
    local prompt_normal
    prompt_normal=$(get_tmux_option '@cc-switcher-prompt' '  ')
    local prompt_search
    prompt_search=$(get_tmux_option '@cc-switcher-prompt-search' '  ')

    local fzf_command=(fzf --exit-0 --print-query --reverse --delimiter=":" --with-nth=1,2,4 \
        --disabled \
        --pointer="$pointer" \
        --prompt="$prompt_normal" \
        --header="$header_normal" \
        --bind='change:clear-query' \
        --bind='j:down,k:up,q:abort,g:first,G:last' \
        --bind="/:enable-search+unbind(change,j,k,q,g,G,c)+clear-query+change-prompt($prompt_search)+change-header(ESC: back)+execute-silent(printf \"\e[6 q\" > /dev/tty)" \
        --bind="esc:disable-search+rebind(change,j,k,q,g,G,c)+change-prompt($prompt_normal)+change-header($header_normal)+execute-silent(printf \"\e[2 q\" > /dev/tty)" \
        --bind="c:reload($list_script --cc-only)+change-header(a:all │ $header_normal)" \
        --bind="a:reload($list_script)+change-header($header_normal)")

    [ -n "$color" ] && fzf_command+=(--color="$color")

    if [ "${PREVIEW_ENABLED}" = "1" ]; then
        fzf_command+=(--preview "$CURRENT_DIR/preview.sh {}" --preview-window=right:70%)
    fi

    # Find current window position in the list to set initial cursor
    local current_sw
    current_sw=$(tmux display-message -p '#{session_name}:#{window_index}')
    local list
    list=$("$list_script")
    local pos
    pos=$(echo "$list" | grep -n "^${current_sw}:" | head -1 | cut -d: -f1)
    if [ -n "$pos" ]; then
        fzf_command+=(--bind "start:pos($pos)")
    fi

    windows=$(echo "$list" | "${fzf_command[@]}")
    retval=$?
    
    IFS=$'\n' read -rd '' -a win_arr <<<"$windows"
    window="${win_arr[1]}"
    query="${win_arr[0]}"
    
    if [ $retval -eq 0 ]; then
        if [ -z "$window" ]; then
            window="$query"
        fi
        session_window=(${window//:/ })
        tmux switch-client -t "${session_window[0]}:${session_window[1]}"
    elif [ $retval -eq 1 ]; then
        session_name=$(tmux display-message -p "#{session_name}")
        tmux command-prompt -b -p "Press enter to create window [$query]" \
            "run '$CURRENT_DIR/new-window.sh \"$query\" \"$session_name\"'"
    fi
}

main
