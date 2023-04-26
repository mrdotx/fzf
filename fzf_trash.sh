#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_trash.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-04-26T08:40:39+0200

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

while true; do
    # menu
    select=$(printf "%s\n" \
                "restore from trash" \
                "put to trash" \
                "remove from trash" \
                "empty trash" \
        | fzf -e --cycle \
            --preview "trash-list" \
            --preview-window "right:75%:wrap" \
    )

    # remove selected files/folders from trash
    trash_remove() {
        objects=$(trash-list | cut -d ' ' -f3 \
            | fzf -m -e --cycle \
                --preview "trash-list | grep {1}$" \
                --preview-window "right:75%:wrap" \
        )

        for entry in $objects; do
            trash-rm "$entry"
        done
    }

    # put to trash
    trash_put() {
        objects=$(find . -maxdepth 1 \
                | sed 1d \
                | cut -b3- \
                | sort \
                | fzf -m -e --cycle \
                    --preview "highlight {1}" \
                    --preview-window "right:75%" \
        )

        for entry in $objects; do
            trash-put "$(pwd)/$entry"
        done
    }

    # select executables
    case "$select" in
        put*)
            trash_put
            ;;
        remove*)
            trash_remove
            ;;
        empty*)
            trash-empty
            ;;
        restore*)
            trash-restore
            ;;
        *)
            break
            ;;
    esac
done
