#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_find.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2024-06-05T22:20:18+0200

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

image_preview() {
    width=$1
    height=$2

    # calculate image dimensions
    image_dimensions=$(printf '5;%s' "$3" | $w3mimgdisplay) 2>/dev/null
    image_width=$(printf '%s' "$image_dimensions" | cut -d' ' -f1)
    image_height=$(printf '%s' "$image_dimensions" | cut -d' ' -f2)
    [ "${image_width:-0}" -gt 0 ] && [ "${image_height:-0}" -gt 0 ] || return 1

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

clear_preview_pane() {
    printf '6;%d;%d;%d;%d\n4;\n3;' \
                "$font_width" \
                "$font_height" \
                "$(($1 + 2))" \
                "$(($2 + 2))" \
            | "$w3mimgdisplay" 2>/dev/null \
        || return

    # mitigate w3mimgdisplay newline
    printf "\033[2J"

    # mitigate horizontal black bars
    sleep .2
}

extension_preview() {
    case "$(printf "%s" "${3##*.}" | tr '[:upper:]' '[:lower:]')" in
        7z | a | alz | apk | arj | bz | bz2 | bzip2 | cab | cb7 | cbt | chm \
            | chw | cpio | deb | dmg | gz | gzip | hxs | iso | jar | lha | lz \
            | lzh | lzma | lzo | msi | pkg | rar | rpm | swm | tar | taz | tbz \
            | tbz2 | tgz | tlz | txz | tz2 | tzo | tzst | udf | war | wim | xar \
            | xpi | xz | z | zip | zst)
                # requires compressor.sh (https://github.com/mrdotx/shell)
                compressor.sh --list "$3"
            ;;
        issue)
            printf "%b\nhost login: _" "$(sed \
                -e 's/\\4{/INTERFACE{/g' \
                -e 's/\\4/11.11.11.11/g' \
                -e 's/\\6{/INTERFACE{/g' \
                -e 's/\\6/::ffff:0b0b:0b0b/g' \
                -e 's/\\b/38400/g' \
                -e 's/\\d/Fri Nov 11  2011/g' \
                -e 's/\\l/tty1/g' \
                -e 's/\\m/x86_64/g' \
                -e 's/\\n/host/g' \
                -e 's/\\o/(none)/g' \
                -e 's/\\O/unknown_domain/g' \
                -e 's/\\r/2.4.37-arch1-1/g' \
                -e 's/\\s/Linux/g' \
                -e 's/\\S{/VARIABLE{/g' \
                -e 's/\\S/Arch Linux/g' \
                -e 's/\\t/11:11:11/g' \
                -e 's/\\u/1/g' \
                -e 's/\\U/1 user/g' \
                -e 's/\\v/#1 SMP PREEMPT_DYNAMIC Fri, 11 Nov 2011 11:11:11 +0000/g' \
                -e 's/\\e/\\033/g' \
                "$3" \
            )"
            ;;
        *)
            return 1
            ;;
    esac
}

mime_preview() {
    case "$5" in
        image/svg*)
            cache_file="$4/$(printf '%s\n' "$3" | sed 's/\//_/g').png"

            [ -s "$cache_file" ] \
                || rsvg-convert1 \
                    --keep-aspect-ratio \
                    --width 960 "$3" \
                    --output "$cache_file" >/dev/null 2>&1

            image_preview "$1" "$2" "$cache_file"
            ;;
        image/x-xcf)
            return 1
            ;;
        image/*)
            image_preview "$1" "$2" "$3"
            ;;
        audio/* | video/*)
            cache_file="$4/$(printf '%s\n' "$3" | sed 's/\//_/g').png"

            [ -s "$cache_file" ] \
                || ffmpegthumbnailer -i "$3" -m \
                    -o "$cache_file" -s 0 >/dev/null 2>&1

            image_preview "$1" "$2" "$cache_file"
            ;;
        font/* | *opentype)
            cache_file="$4/$(printf '%s\n' "$3" | sed 's/\//_/g').png"

            [ -s "$cache_file" ] \
                || convert -size '960x960' xc:'#000000' \
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
                            | uniq \
                    )" \
                    -flatten "$cache_file" >/dev/null 2>&1

            image_preview "$1" "$2" "$cache_file"
            ;;
        */pdf)
            cache_file="$4/$(printf '%s\n' "$3" | sed 's/\//_/g').png"

            [ -s "$cache_file" ] \
                || pdftoppm -f 1 -l 1 \
                    -scale-to-x 960 \
                    -scale-to-y -1 \
                    -singlefile \
                    -png \
                    "$3" "${cache_file%.*}" >/dev/null 2>&1

            image_preview "$1" "$2" "$cache_file"
            ;;
        */vnd.oasis.opendocument* \
            | */vnd.openxmlformats-officedocument* \
            | *ms-excel | *msword | *mspowerpoint | */rtf)
                cache_file="$4/$(printf '%s\n' "$3" | sed 's/\//_/g').png"

                [ -s "$cache_file" ] \
                    || (libreoffice \
                            --convert-to png "$3" \
                            --outdir "$4/" >/dev/null 2>&1 \
                        && mv "$4/$(basename "${3%.*}").png" "$cache_file")

                image_preview "$1" "$2" "$cache_file"
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
        */x-executable | */x-pie-executable | */x-sharedlib | */x-object)
            readelf --wide --demangle --all "$3"
            ;;
        text/troff)
            man "$3"
            ;;
        text/* | */javascript | */json | */xml | */x-wine-extension-ini)
            highlight "$3"
            ;;
        *)
            return 1
            ;;
    esac
}

fallback_preview() {
    printf "##### File Type Classification #####\n"
    printf "MIME-Type: %s\n" "$2"
    file --dereference --brief "$1"
    printf "\n##### Exif information #####\n"
    exiftool "$1"
    return 0
}

case $1 in
    -h | --help)
        printf "%s\n" "$help"
        exit 0
        ;;
    --preview)
        shift

        # file identification
        mime_type="$(file --dereference --brief --mime-type "$1")"

        # preview pane calculation
        max_width=$((font_width * (COLUMNS - 1)))
        max_height=$((font_height * (LINES - 1)))

        padding_width=$((font_width * 2))
        padding_height=$((font_height * 2))

        preview_width=$((max_width - padding_width))
        preview_height=$((max_height * preview_height / 100 - padding_height))

        # preview file
        clear_preview_pane "$preview_width" "$preview_height"
        extension_preview "$preview_width" "$preview_height"\
                "$1" \
            || mime_preview "$preview_width" "$preview_height" \
                "$1" "$2" "$mime_type" \
            || fallback_preview "$1" "$mime_type"
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

        # move exit status after cache deletion
        error=$?
        [ -d "$cache_folder" ] \
            && rm -rf "$cache_folder"
        exit $error
        ;;
esac
