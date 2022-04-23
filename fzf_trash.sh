#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_trash.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-04-23T16:47:53+0200

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
                "1) restore from trash" \
                "2) empty trash" \
                "3) remove from trash" \
                "4) put to trash" \
        | fzf -e -i --preview "trash-list" \
            --preview-window "right:75%:wrap" \
    )

    # remove selected files/folders from trash
    trash_remove() {
        objects=$(trash-list | cut -d ' ' -f3 \
            | fzf -m -e -i --preview "trash-list | grep {1}$" \
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
                | fzf -m -e -i --preview "highlight {1}" \
                    --preview-window "right:75%" \
        )

        for entry in $objects; do
            trash-put "$(pwd)/$entry"
        done
    }

    # select executables
    case "$select" in
        4*)
            trash_put
            ;;
        3*)
            trash_remove
            ;;
        2*)
            trash-empty
            ;;
        1*)
            trash-restore
            ;;
        *)
            break
            ;;
    esac
done
