#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_alsa.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2025-07-03T04:15:48+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"

# config
alsa_config="$HOME/.config/alsa/asoundrc"
alsa_state="/var/lib/alsa/asound.state"
event_cache="$HOME/.cache/event-sound-cache.tdb.*"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to set the default alsa playback device
  Usage:
    $script

  Examples:
    $script"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit

# helper funcitons
exit_status() {
    printf "%s" \
        "The command exited with status $?. " \
        "Press ENTER to continue."
    read -r select
}

set_asoundrc() {
    mkdir -p "$(dirname "$alsa_config")"

    aplay_data=$(aplay -l \
        | grep "$(printf "%s" "$1" | cut -d' ' -f3-)"
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
        "}" > "$alsa_config"
}

get_file_info() {
    [ -e "$alsa_state" ] \
        && stat "$alsa_state" \
        && printf "\n"
    for tdb in $event_cache; do
        [ -e "$tdb" ] \
            && stat "$tdb" \
            && printf "\n"
    done
}

get_menu_entries() {
    printf "%s\n" "$devices" \
        | while IFS= read -r entry; do
            printf "set device %s\n" "$entry"
        done
    printf "%s\n" \
        "driver state init" \
        "driver state store" \
        "driver state restore" \
        "driver state remove"
}

while true; do
    devices=$(aplay -l \
        | grep '^card' \
        | cut -d'[' -f3 \
        | tr -d ']'
    )

    #menu
    select=$(get_menu_entries \
        | fzf --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%,wrap" \
            --preview "case {} in
            \"driver state remove\")
                printf \"%s\" \"$(get_file_info)\"
                ;;
            \"driver state\"*)
                printf \"**** %s ****\n%s\" \
                    \"$alsa_state\" \
                    \"$([ -e "$alsa_state" ] && cat "$alsa_state")\"
                ;;
            \"set device\"*)
                printf '%s\n\n**** %s ****\n%s' \
                    \"$(aplay -l)\" \
                    \"$alsa_config\" \
                    \"$(cat "$alsa_config")\"
                ;;
        esac" \
    )

    # select executable
    case "$select" in
        "driver state remove")
            [ -e "$alsa_state" ] \
                && "$auth" rm -i "$alsa_state"
            for tdb in $event_cache; do
                [ -e "$tdb" ] \
                    && rm -i "$tdb"
            done
            ;;
        "driver state"*)
            "$auth" alsactl "$(printf "%s" "$select" | cut -d' ' -f3-)" \
                || exit_status
            ;;
        "set device"*)
            set_asoundrc "$select" \
                || exit_status
            ;;
        *)
            break
            ;;
    esac
done
