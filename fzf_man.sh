#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_man.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-07-08T19:23:38+0200

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
    | cut -d ' ' -f1,2 \
    | sort \
    | fzf -m -e -i --preview "man {1}{2}" \
        --preview-window "right:70%" \
    | tr -d ' ')

[ -n "$select" ] \
    && man "$select"
