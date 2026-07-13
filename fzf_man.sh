#!/bin/sh

# path:   /home/klassiker/Projects/repos/fzf/fzf_man.sh
# author: klassiker [mrdotx]
# url:    https://github.com/mrdotx/fzf
# date:   2026-07-13T03:37:07+0200

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to search and open man pages
  Usage:
    $script

  Examples:
    $script"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit

select=$(man -k . \
    | fzf +s --query="^" \
        --preview-window "up:75%" \
        --preview "man {1}{2} 2>/dev/null" \
    | cut -d ' ' -f1,2 \
    | tr -d ' ' \
)

[ -n "$select" ] \
    && man "$select"
