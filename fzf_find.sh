#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_find.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2024-06-09T06:47:26+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# config
w3mimgdisplay="/usr/lib/w3m/w3mimgdisplay"
preview_height=75   # in percent
font_width=10       # in pixel
font_height=19      # in pixel
padding_width=2     # in cursor
padding_height=2    # in cursor

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

preview_pane() {
    width=$1
    height=$2

    # clear preview pane
    printf '6;%d;%d;%d;%d\n4;\n3;' \
                "$((font_width * padding_width))" \
                "$((font_height * padding_height))" \
                "$((width + 2))" \
                "$((height + 2))" \
            | "$w3mimgdisplay" >/dev/null 2>&1 \
        || return

    # mitigate partial previews (fill preview pane with newlines and wait)
    while [ "${i:-0}" -lt "$((height / font_height + padding_height * 2))" ]; do
        printf "\n"
        i=$((i+1))
    done
    sleep .2

    # if no image preview, clear newlines and return
    [ -z "$3" ] \
        && printf '\033[2J' \
        && return 0

    # calculate image dimensions
    image_dimensions=$(printf '5;%s' "$3" | $w3mimgdisplay) 2>/dev/null
    image_width=${image_dimensions%% *}
    image_height=${image_dimensions##* }
    [ "${image_width:-0}" -gt 0 ] && [ "${image_height:-0}" -gt 0 ] || return

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
            "$((font_width * padding_width))" \
            "$((font_height * padding_height))" \
            "$width" \
            "$height" \
            "$3" \
        | $w3mimgdisplay >/dev/null 2>&1
}

extension_preview() {
    case "$(printf "%s" "${3##*.}" | tr '[:upper:]' '[:lower:]')" in
        7z | a | alz | apk | arj | bz | bz2 | bzip2 | cab | cb7 | cbt | chm \
            | chw | cpio | deb | dmg | gz | gzip | hxs | iso | jar | lha | lz \
            | lzh | lzma | lzo | msi | pkg | rar | rpm | swm | tar | taz | tbz \
            | tbz2 | tgz | tlz | txz | tz2 | tzo | tzst | udf | war | wim | xar \
            | xpi | xz | z | zip | zst)
                preview_pane "$1" "$2"
                # requires compressor.sh (https://github.com/mrdotx/shell)
                compressor.sh --list "$3"
            ;;
        issue)
            preview_pane "$1" "$2"
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
        gpg | asc)
            pass_preview() {
                printf "%s\n" "$1" | head -n 4 | sed '1 s/^.*$/***/' \
                    && [ "$(printf "%s\n" "$1" | wc -l)" -gt 4 ] \
                    && printf "\n***"

                return 0
            }

            preview_pane "$1" "$2"
            printf '%s\n' "$(cd "$(dirname "$3")" && pwd -P)/$(basename "$3")" \
                | grep -q "^${PASSWORD_STORE_DIR-$HOME/.password-store}" \
                    && pass_preview "$(gpg --decrypt "$3" 2>/dev/null)" \
                    && exit

            gpg --decrypt "$3" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac \
        && exit
}

mime_preview() {
    case "$5" in
        image/svg*)
            cache_file="$4/$(printf '%s\n' "$3" | sed 's/\//_/g').png"

            [ -s "$cache_file" ] \
                || rsvg-convert \
                    --keep-aspect-ratio \
                    --width 960 "$3" \
                    --output "$cache_file" >/dev/null 2>&1

            preview_pane "$1" "$2" "$cache_file"
            ;;
        image/x-xcf)
            return 1
            ;;
        image/*)
            preview_pane "$1" "$2" "$3"
            ;;
        audio/* | video/*)
            cache_file="$4/$(printf '%s\n' "$3" | sed 's/\//_/g').png"

            [ -s "$cache_file" ] \
                || ffmpegthumbnailer -i "$3" \
                    -o "$cache_file" -s 0 >/dev/null 2>&1

            preview_pane "$1" "$2" "$cache_file"
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

            preview_pane "$1" "$2" "$cache_file"
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

            preview_pane "$1" "$2" "$cache_file"
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

                preview_pane "$1" "$2" "$cache_file"
            ;;
        */csv)
            preview_pane "$1" "$2"
            column --separator '	;,' --table "$3"
            ;;
        *sqlite3)
            preview_pane "$1" "$2"
            sqlite3 -readonly -header -column "$3" \
                "SELECT name, type
                 FROM sqlite_master
                 WHERE type IN ('table','view')
                 AND name NOT LIKE 'sqlite_%'
                 ORDER BY 1;"
            ;;
        */*html*)
            preview_pane "$1" "$2"
            w3m -dump "$3"
            ;;
        */x-bittorrent)
            preview_pane "$1" "$2"
            aria2c --show-files "$3"
            ;;
        */x-executable | */x-pie-executable | */x-sharedlib | */x-object)
            preview_pane "$1" "$2"
            readelf --wide --demangle --all "$3"
            ;;
        text/troff)
            preview_pane "$1" "$2"
            man "$3"
            ;;
        text/* | */javascript | */json | */xml | */x-wine-extension-ini)
            preview_pane "$1" "$2"
            highlight "$3"
            ;;
        *)
            return 1
            ;;
    esac \
        && exit
}

fallback_preview() {
    preview_pane "$1" "$2"
    printf "##### File Type Classification #####\n"
    printf "MIME-Type: %s\n" "$4"
    file --dereference --brief "$3"
    printf "\n##### Exif information #####\n"
    exiftool "$3" \
        && exit 0
}

case $1 in
    -h | --help)
        printf "%s\n" "$help"
        exit
        ;;
    --preview)
        shift

        # file identification
        mime_type="$(file --dereference --brief --mime-type "$1")"

        # preview pane calculation
        # max width - padding width
        preview_width=$((font_width * (COLUMNS - 1) \
            - font_width * padding_width * 2))
        # max height * preview_height (percent) - padding height
        preview_height=$((font_height * (LINES - 1) \
            * preview_height / 100 \
            - font_height * padding_height * 2))

        # preview file
        extension_preview "$preview_width" "$preview_height" "$1"
        mime_preview "$preview_width" "$preview_height" "$1" "$2" "$mime_type"
        fallback_preview "$preview_width" "$preview_height" "$1" "$mime_type"
        ;;
    *)
        cache_folder=$(mktemp -t -d "fzf_find_cache.XXXXXX")

        find "${1:-.}" -type f 2> /dev/null \
            | sed 's/^.\///' \
            | sort \
            | fzf -e -m +s \
                --preview-label="[ $(pwd) ]" \
                --preview-window "up:$preview_height%" \
                --preview "$0 --preview {} $cache_folder"

        # move exit status after cache deletion
        error=$?
        [ -d "$cache_folder" ] \
            && rm -rf "$cache_folder"
        exit $error
        ;;
esac
