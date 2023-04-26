#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_man.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-04-26T08:32:06+0200

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to search and open man pages
  Usage:
    $script

  Examples:
    $script"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit 0

select=$(man -k -l '' \
    | sort \
    | fzf -e --cycle --query=^ \
        --preview "man {1}{2}" \
        --preview-window "up:75%" \
    | cut -d ' ' -f1,2 \
    | tr -d ' ' \
)

[ -n "$select" ] \
    && man "$select"
