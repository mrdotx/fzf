#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_man.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-10-19T19:47:25+0200

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

apropos -l '' \
    | cut -d ' ' -f1,2 \
    | sort \
    | fzf -m -e -i --preview "man {1}" --preview-window "right:70%" \
    | tr -d ' ' \
    | xargs -ro man
