#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_trash.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-10-03T20:23:09+0200

script=$(basename "$0")
help="$script [-h/--help] -- script to manage deleted files/folders with trash-cli
  Usage:
    $script

  Examples:
    $script"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    printf "%s\n" "$help"
    exit 0
fi

# menu
select=$(printf "1) restore from trash\n2) remove selected files/folders from trash\n3) remove trash older than 7 days\n4) remove trash older then 30 days\n5) empty trash" \
    | fzf -e -i --cycle --preview "trash-list" --preview-window "right:70%")

# remove selected files/folders from trash
trash_remove() {
    objects=$(trash-list | cut -d ' ' -f3 \
        | fzf -m -e -i --cycle --preview "trash-list | grep {1}" --preview-window "right:70%")

    [ -z "$objects" ] \
        && exit 1

    for f in $objects; do
        trash-rm "$f"
    done
}

# select executables
case "$select" in
    "1) restore from trash")
        trash-restore
        ;;
    "2) remove selected files/folders from trash")
        trash_remove
        ;;
    "3) remove trash older then 7 days")
        trash-empty 7
        ;;
    "4) remove trash older then 30 days")
        trash-empty 30
        ;;
    "5) empty trash")
        trash-empty
        ;;
    *)
        exit 0
        ;;
esac
