#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_trash.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2024-06-20T17:17:21+0200

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
        | sort -u -fV \
        | fzf -m +s \
            --preview-window "up:75%:wrap" \
            --preview "trash-list | grep {}$" \
        | while IFS= read -r entry; do
                trash-rm "$entry"
        done
}

trash_put() {
    find . -maxdepth 1 \
        | sed -e 1d -e 's/^.\///' \
        | sort -fV \
        | fzf -m +s \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%" \
            --preview "highlight {}" \
        | while IFS= read -r entry; do
                trash-put "$(pwd)/$entry"
        done
}

while true; do
    # menu
    select=$(printf "%s\n" \
                "restore from trash" \
                "put to trash" \
                "remove from trash" \
                "empty trash" \
        | fzf --cycle \
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
