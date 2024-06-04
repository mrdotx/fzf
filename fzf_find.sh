#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_find.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2024-06-03T20:36:08+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# config
w3mimgdisplay="/usr/lib/w3m/w3mimgdisplay"
preview_height=75   # in percent
font_width=10       # in pixel
font_height=19      # in pixel

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to find files with w3m image preview
  Usage:
    $script <path/dir>

  Settings:
    <path/dir> = if empty, the current working directory is used

  Examples:
    $script
    $script $HOME/Pictures"

clear_preview_pane() {
    printf '6;%d;%d;%d;%d\n4;\n3;' \
            "$font_width" \
            "$font_height" \
            "$(($1 + 2))" \
            "$(($2 + 2))" \
        | "$w3mimgdisplay"

    # mitigate w3mimgdisplay newline
    printf "\033[2J"

    # mitigate horizontal black bars
    sleep .2
}

preview_image() {
    width=$1
    height=$2

    # calculate image dimensions
    image_dimensions=$(printf '5;%s' "$3" | $w3mimgdisplay)
    image_width=$(printf '%s' "$image_dimensions" | cut -d' ' -f1)
    image_height=$(printf '%s' "$image_dimensions" | cut -d' ' -f2)

    [ "$image_height" -gt "$height" ] \
        && width=$((image_width * height / image_height)) \
        || width=$image_width

    [ "$width" -gt "$1" ] \
        && width=$1

    [ "$image_width" -gt "$width" ] \
        && height=$((image_height * width / image_width)) \
        || height=$image_height

    # preview image
    printf '0;1;%d;%d;%d;%d;;;;;%s\n4;\n3;' \
            "$font_width" \
            "$font_height" \
            "$width" \
            "$height" \
            "$3" \
        | $w3mimgdisplay
}

preview() {
    mime_type="$(file --dereference --brief --mime-type "$3")"

    case "$mime_type" in
        image/svg*)
            cache_file=$(mktemp "$4/svg_XXXXXX.png")
            rsvg-convert \
                --keep-aspect-ratio \
                --width 960 "$3" \
                --output "$cache_file" >/dev/null 2>&1 \
                && preview_image "$1" "$2" "$cache_file"
            ;;
        image/*)
            preview_image "$1" "$2" "$3"
            ;;
        audio/*)
            cache_file=$(mktemp "$4/audio_XXXXXX.png")
            ffmpeg -y -i "$3" -c:v copy "$cache_file" >/dev/null 2>&1 \
                && preview_image "$1" "$2" "$cache_file"
            ;;
        video/*)
            cache_file=$(mktemp "$4/video_XXXXXXX.png")
            ffmpegthumbnailer -i "$3" -o "$cache_file" -s 0 >/dev/null 2>&1 \
                && preview_image "$1" "$2" "$cache_file"
            ;;
        font/* | *opentype)
            cache_file=$(mktemp "$4/font_XXXXXX.png")
            convert -size '960x960' xc:'#000000' \
                -font "$3" \
                -fill '#cccccc' \
                -gravity Center \
                -pointsize 72 \
                -annotate +0+0 "$( \
                    printf "%s" \
                        'AÄBCDEFGHIJKLMN\n' \
                        'OÖPQRSẞTUÜVWXYZ\n' \
                        'aäbcdefghijklmn\n' \
                        'oöpqrsßtuüvwxyz\n' \
                        '1234567890,.*/+-=\%\n' \
                        '~!?@#§$&(){}[]<>;:' \
                )" \
                -font '' \
                -fill '#4185d7' \
                -gravity SouthWest \
                -pointsize 24 \
                -annotate +0+0 "$( \
                    fc-list \
                        | grep "$3" \
                        | cut -d ':' -f2 \
                        | sed 's/^ //g' \
                        | uniq
                )" \
                -flatten "$cache_file" >/dev/null 2>&1 \
                    && preview_image "$1" "$2" "$cache_file"
            ;;
        */pdf)
            cache_file=$(mktemp "$4/pdf_XXXXXX.png")
            pdftoppm -f 1 -l 1 \
                -scale-to-x 960 \
                -scale-to-y -1 \
                -singlefile \
                -png \
                "$3" "${cache_file%.*}" >/dev/null 2>&1 \
                    && preview_image "$1" "$2" "$cache_file"
            ;;
        */vnd.oasis.opendocument* \
            | */vnd.openxmlformats-officedocument* \
            | *ms-excel | *msword | *mspowerpoint | */rtf)
                cache_file=$(mktemp "$4/office_XXXXXX.png")
                file_name="$(basename "${3%.*}")"
                cache_dir="$4/"
                libreoffice \
                    --convert-to png "$3" \
                    --outdir "$cache_dir" >/dev/null 2>&1 \
                        && mv "$cache_dir$file_name.png" "$cache_file" \
                        && preview_image "$1" "$2" "$cache_file"
            ;;
        */csv)
            column --separator '	;,' --table "$3"
            ;;
        *sqlite3)
            sqlite3 -readonly -header -column "$3" \
                "SELECT name, type
                 FROM sqlite_master
                 WHERE type IN ('table','view')
                 AND name NOT LIKE 'sqlite_%'
                 ORDER BY 1;"
            ;;
        */*html*)
            w3m -dump "$3"
            ;;
        */x-bittorrent)
            aria2c --show-files "$3"
            ;;
        */x-executable | */x-pie-executable | */x-sharedlib)
            readelf --wide --demangle --all "$3"
            ;;
        text/troff)
            man "$3"
            ;;
        text/* | */javascript | */json | */xml)
            highlight "$3"
            ;;
        *)
            printf "##### File Status #####\n"
            stat --dereference "$3"
            printf "\n##### File Type Classification #####\n"
            file --dereference --brief "$3"
            printf "%s\n" "$mime_type"
            ;;
    esac

    # remove cache file
    [ -n "$cache_file" ] \
        && rm -f "$cache_file"
}

case $1 in
    -h | --help)
        printf "%s\n" "$help"
        exit 0
        ;;
    --preview)
        shift

        # preview pane calculation
        max_width=$((font_width * (COLUMNS - 1)))
        max_height=$((font_height * (LINES - 1)))

        padding_width=$((font_width * 2))
        padding_height=$((font_height * 2))

        preview_width=$((max_width - padding_width))
        preview_height=$((max_height * preview_height / 100 - padding_height))

        # preview file
        clear_preview_pane "$preview_width" "$preview_height"
        preview "$preview_width" "$preview_height" "$1" "$2"
        ;;
    *)
        cache_folder=$(mktemp -t -d "fzf_find_cache.XXXXXX")
        directory="$(pwd)"

        find "${1:-.}" -type f 2> /dev/null \
            | sed 's/^.\///' \
            | sort \
            | fzf -e -m +s \
                --preview-label="[ $directory ]" \
                --preview-window "up:$preview_height%" \
                --preview "$0 --preview {} $cache_folder"

        # move find exit status
        error=$?
        rm -rf "$cache_folder"
        exit $error
        ;;
esac
