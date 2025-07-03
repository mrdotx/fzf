#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_trash.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2025-07-03T04:18:55+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# config
edit="$EDITOR"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to manage files/folders with trash-cli
  Usage:
    $script

  Examples:
    $script"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit

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

delete_meta_files() {
    # config
    cmd="trash-put -v"

    # create cache
    cache_file=$(mktemp -t delete_metafiles.XXXXXX)

    # create delete script
    printf "%b" \
        "#!/bin/sh\n\n" \
        "# This script will be executed when you close the editor.\n" \
        "# Please check everything! Clear the file to abort.\n\n" \
            > "$cache_file"

    find . \! -path "*/Trash/files/*" \
        \( \
        -name ".DS_Store" \
        -o -name ".AppleDB" \
        -o -name ".AppleDouble" \
        -o -name ".@__qini" \
        -o -name ".@__thumb" \
        -o -name "._*" \
        -o -name ":2e*" \
        \) -exec printf "$cmd \"{}\"\n" \; \
            | sed  -e "s/$cmd \".\//$cmd \"/" \
            | sort -fV >> "$cache_file"

    # check delete script
    "$edit" "$cache_file"

    # execute delete script
    chmod 755 "$cache_file"
    "$cache_file"

    # delete cache
    [ -f "$cache_file" ] \
        && rm -f "$cache_file"
}

while true; do
    # menu
    select=$(printf "%s\n" \
                "restore from trash" \
                "put to trash" \
                "delete meta files" \
                "remove from trash" \
                "empty trash" \
        | fzf --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%:wrap" \
            --preview "case {} in
                'delete meta files')
                    printf '» create script to delete meta files like:\n\n'
                    printf '  %s\n' \
                        '.DS_Store' \
                        '.AppleDB' \
                        '.AppleDouble' \
                        '.@__qini' \
                        '.@__thumb' \
                        '._*' \
                        ':2e*'
                    printf '\n» working directory: %s\n' \"$(pwd)\"
                    ;;
                *)
                    trash-list
                    ;;
                esac" \
    )

    # select executables
    case "$select" in
        "restore from trash")
            trash-restore
            ;;
        "put to trash")
            trash_put
            ;;
        "delete meta files")
            delete_meta_files
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
