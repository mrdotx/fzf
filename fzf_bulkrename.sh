#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_bulkrename.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2024-10-21T08:15:14+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# config
edit="$EDITOR"
cmd="mv -vi"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to bulk rename files with a text editor
  Usage:
    $script [--files] <file> [file1] [file2]

  Settings:
    [--files] = files to rename

  Examples:
    $script
    $script --files file.md file1.csv file2.sh

  Config:
    edit = $edit
    cmd  = $cmd"

bulkrename() {
    original_file="original"
    modify_file="modify"
    script_file="bulkrename.sh"

    # create cache
    cache_folder=$(mktemp -t -d "fzf_bulkrename.XXXXXX")
    cat > "$cache_folder/$original_file"
    [ -s "$cache_folder/$original_file" ] \
        || return

    # modify file names
    cp -f "$cache_folder/$original_file" "$cache_folder/$modify_file"
    "$edit" "$cache_folder/$modify_file"

    # create bulk rename script
    printf "%b" \
        "#!/bin/sh\n\n" \
        "# This script will be executed when you close the editor.\n" \
        "# Please check everything! Clear the file to abort.\n\n" \
            > "$cache_folder/$script_file"

    awk -v cmd="$cmd" 'NR==FNR { a[NR]=$0; next }
        $0!=a[FNR] { print cmd" \\\n\t\""$0"\" \\\n\t\""a[FNR]"\"" }' \
        "$cache_folder/$modify_file" "$cache_folder/$original_file" \
            >> "$cache_folder/$script_file"

    # check bulk rename script
    "$edit" "$cache_folder/$script_file"

    # execute bulk rename script
    chmod 755 "$cache_folder/$script_file"
    "$cache_folder/$script_file"

    # delete cache
    [ -d "$cache_folder" ] \
        && rm -rf "$cache_folder"
}

case $1 in
    -h | --help)
        printf "%s\n" "$help"
        exit
        ;;
    --files)
        shift

        for file_name in "$@"; do
            printf "%s\n" "$file_name"
        done | bulkrename
        ;;
    *)
        find . -maxdepth 1 2> /dev/null \
            | sed -e 1d -e 's/^.\///' \
            | sort -fV \
            | fzf -m +s \
                | bulkrename
        ;;
esac
