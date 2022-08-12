#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_alsa.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-08-09T09:47:42+0200

# use standard c to identify the playback device
LC_ALL=C
LANG=C

# config
config_path="$HOME/.config/alsa"
config_file="asoundrc"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to set the default alsa playback device
  Usage:
    $script

  Examples:
    $script"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit 0

set_asoundrc() {
    mkdir -p "$config_path"

    aplay_data=$(aplay -l \
        | grep "$1"
    )

    card=$(printf "%s" "$aplay_data" \
        | cut -d':' -f1 \
        | sed 's/card //' \
    )

    device=$(printf "%s" "$aplay_data" \
        | cut -d':' -f2 \
        | cut -d',' -f2 \
        | sed 's/ device //' \
    )

    printf "%s\n" \
        "defaults.pcm {" \
        "    type hw" \
        "    card $card" \
        "    device $device" \
        "}" \
        "defaults.ctl {" \
        "    card $card" \
        "}" > "$config_path/$config_file"
}

select=$(aplay -l \
    | grep '^card' \
    | cut -d'[' -f3 \
    | tr -d ']' \
    | fzf -m -e -i --preview "printf '%s\n\n**** %s ****\n%s' \
            \"$(aplay -l)\" \
            \"$config_file\" \
            \"$(cat "$config_path/$config_file")\"" \
        --preview-window "right:70%,wrap" \
)

[ -n "$select" ] \
    && set_asoundrc "$select" \
    && "$0" \
        || exit 0