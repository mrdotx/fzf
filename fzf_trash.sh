#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_trash.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-12-02T10:48:10+0100

script=$(basename "$0")
help="$script [-h/--help] -- script to manage files/folders with trash-cli
  Usage:
    $script

  Examples:
    $script"

if [ "$1" = "-h" ] \
    || [ "$1" = "--help" ]; then
        printf "%s\n" "$help"
        exit 0
fi

# menu
select=$(printf "%s\n" \
            "1) restore from trash" \
            "2) empty trash" \
            "3) select objects to remove from trash" \
            "4) remove trash older than 7 days" \
            "5) remove trash older than 30 days" \
            "6) put to trash" \
    | fzf -e -i --preview "trash-list" \
        --preview-window "right:60%:wrap" \
)

# remove selected files/folders from trash
trash_remove() {
    objects=$(trash-list | cut -d ' ' -f3 \
        | fzf -m -e -i --preview "trash-list \
            | grep {1}$" --preview-window "right:60%:wrap" \
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
                --preview-window "right:60%" \
    )

    for entry in $objects; do
        trash-put "$(pwd)/$entry"
    done
}

# select executables
case "$select" in
    "1) restore from trash")
        trash-restore
        ;;
    "2) empty trash")
        trash-empty
        ;;
    "3) select objects to remove from trash")
        trash_remove
        ;;
    "4) remove trash older than 7 days")
        trash-empty 7
        ;;
    "5) remove trash older than 30 days")
        trash-empty 30
        ;;
    "6) put to trash")
        trash_put
        ;;
    *)
        exit 0
        ;;
esac
