#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_pix.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2024-05-31T22:19:54+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# config
w3mimgdisplay="/usr/lib/w3m/w3mimgdisplay"
preview_width=100   # in percent
preview_height=75   # in percent
font_width=10       # in pixel
font_height=19      # in pixel

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to search for pictures
  Usage:
    $script <path/dir>

  Settings:
    <path/dir> = if empty, the current working directory is used

  Examples:
    $script
    $script $HOME/Pictures"

preview() {
    # calculate dimensions
    image_dimensions=$(printf '5;%s' "$1" | $w3mimgdisplay)
    image_width=$(printf '%s' "$image_dimensions" | cut -d' ' -f1)
    image_height=$(printf '%s' "$image_dimensions" | cut -d' ' -f2)

    max_width=$((font_width * (COLUMNS - 1)))
    max_height=$((font_height * (LINES - 1)))

    padding_width=$((font_width * 2))
    padding_height=$((font_height * 2))

    preview_width=$((max_width * preview_width / 100 - padding_width))
    preview_height=$((max_height * preview_height / 100 - padding_height))

    width=$preview_width
    height=$preview_height

    [ "$image_height" -gt "$height" ] \
        && width=$((image_width * height / image_height)) \
        || width=$image_width

    [ "$width" -gt "$preview_width" ] \
        && width=$preview_width

    [ "$image_width" -gt "$width" ] \
        && height=$((image_height * width / image_width)) \
        || height=$image_height

    # clear preview pane
    printf '6;%s;%s;%s;%s\n4;\n3;' \
            "$font_width" \
            "$font_height" \
            "$((preview_width + 10))" \
            "$((preview_height + 10))" \
        | "$w3mimgdisplay"

    # preview picture
    printf '0;1;%s;%s;%s;%s;;;;;%s\n4;\n3;' \
            "$font_width" \
            "$font_height" \
            "$width" \
            "$height" \
            "$1" \
        | $w3mimgdisplay
}

case $1 in
    -h | --help)
        printf "%s\n" "$help"
        exit 0
        ;;
    --preview)
        shift
        preview "$1"
        ;;
    *)
        directory="$(pwd)"
        find "${1:-.}" \
                -type f \
                \( -iname '*.jpg' \
                -o -iname '*.jpeg' \
                -o -iname '*.png' \
                -o -iname '*.gif' \
                -o -iname '*.webp' \
                -o -iname '*.tiff' \
                -o -iname '*.bmp' \
                \) 2> /dev/null \
            | sed 's/^.\///' \
            | sort \
            | fzf -e -m +s \
                --bind "focus:transform-preview-label:echo [ $directory ]" \
                --preview-window "up:$preview_height%" \
                --preview "$0 --preview {}" \
        ;;
esac
