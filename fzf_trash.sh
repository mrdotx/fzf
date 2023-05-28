#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_trash.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-05-27T12:13:32+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to manage files/folders with trash-cli
  Usage:
    $script

  Examples:
    $script"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit 0

trash_remove() {
    trash-list \
        | cut -d ' ' -f3- \
        | LC_COLLATE=C sort -u \
        | fzf -m -e \
            --preview-window "up:75%:wrap" \
            --preview "trash-list | grep {}$" \
        | {
            while IFS= read -r entry; do
                trash-rm "$entry"
            done
        }
}

trash_put() {
    find . -maxdepth 1 \
        | sed 1d \
        | cut -b3- \
        | LC_COLLATE=C sort \
        | fzf -m -e \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%" \
            --preview "highlight {}" \
        | {
            while IFS= read -r entry; do
                trash-put "$(pwd)/$entry"
            done
        }
}

while true; do
    # menu
    select=$(printf "%s\n" \
                "restore from trash" \
                "put to trash" \
                "remove from trash" \
                "empty trash" \
        | fzf -e --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%:wrap" \
            --preview "trash-list" \
    )

    # select executables
    case "$select" in
        "restore from trash")
            trash-restore
            ;;
        "put to trash")
            trash_put
            ;;
        "remove from trash")
            trash_remove
            ;;
        "empty trash")
            trash-empty
            ;;
        *)
            break
            ;;
    esac
done
