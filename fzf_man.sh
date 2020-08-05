#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_man.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/shell
# date:       2020-08-05T13:29:26+0200

script=$(basename "$0")
help="$script [-h/--help] -- script to search and open man pages
  Usage:
    $script

  Examples:
    $script"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    printf "%s\n" "$help"
    exit 0
fi

apropos -l '' \
    | awk '{print $1, $2}' \
    | sort \
    | fzf -m -e -i --preview "man {1}" \
    | tr -d ' ' \
    | xargs -ro man
