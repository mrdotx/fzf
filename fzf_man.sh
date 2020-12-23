#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_man.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-12-23T15:33:46+0100

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to search and open man pages
  Usage:
    $script

  Examples:
    $script"

if [ "$1" = "-h" ] \
    || [ "$1" = "--help" ]; then
        printf "%s\n" "$help"
        exit 0
fi

# execute
apropos -l '' \
    | cut -d ' ' -f1,2 \
    | sort \
    | fzf -m -e -i --preview "man {1}{2}" --preview-window "right:70%" \
    | tr -d ' ' \
    | xargs -ro man
