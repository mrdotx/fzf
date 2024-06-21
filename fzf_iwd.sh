#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_iwd.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2024-06-20T17:17:01+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to connect to wlan with iwd
  Usage:
    $script

  Examples:
    $script"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit 0

remove_escape_sequences() {
    tail -n +5 \
        | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g;/^\s*$/d'
}

read_secret() {
    stty -echo
    trap 'stty echo' EXIT

    read "$@"

    stty echo
    trap - EXIT

    printf "\n"
}

get_device_power() {
    printf "%s" "$devices" \
        | awk -v device="$1" '$1 == device {print $3}'
}

get_ssid_security() {
    iwctl station "$1" get-networks \
        | remove_escape_sequences \
        | sed 's/>//' \
        | awk -v ssid="$2" '$1 == ssid {print $2}'
}

scan_ssids() {
    timer=3

    iwctl station "$1" scan \
        && printf "scan for ssids with device %s, please wait %s seconds\n" \
            "$1" \
            "$timer" \
        && sleep $timer

    ssids=$(iwctl station "$1" get-networks \
        | remove_escape_sequences \
        | sed 's/>//' \
        | awk '{print $1}' \
    )
}

connect_ssid() {
    case "$2" in
        open)
            printf "try to connect to \"%s\"\n" "$3"
            iwctl station "$1" connect "$3"
            ;;
        *)
            printf "enable password feedback [y]es/[N]o: " \
                && read -r feedback \
                && printf "leave blank if passphrase is already known!\n" \
                && printf "passphrase: " \
                && case "$feedback" in
                    y|Y|yes|Yes)
                        read -r psk
                        ;;
                    *)
                        read_secret -r psk
                        ;;
                esac
            printf "try to connect to \"%s\" with psk\n" "$3"
            iwctl station "$1" connect "$3" -P "$psk"
            ;;
    esac
}

select_device() {
    devices=$(iwctl device list \
        | remove_escape_sequences \
    )

    device=$(printf "%s" "$devices" \
        | awk '{print $1"\n» toggle power"}' \
        | fzf --cycle \
            --preview-window "up:75%" \
            --preview-label "[ device ]" \
            --preview "case {} in
                \"» toggle power\")
                    iwctl device list
                    ;;
                *)
                    iwctl station {} show
                    ;;
            esac" \
    )

    [ "$device" = "» toggle power" ] \
        || [ "$(get_device_power "$device")" = "off" ] \
        && select_device_power

    [ -n "$device" ] \
        || exit 1
}

select_device_power() {
    device_power=$(printf "%s" "$devices" \
        | awk '{print $1}' \
        | fzf --cycle \
            --preview-window "up:75%" \
            --preview-label "[ toggle power ]" \
            --preview "iwctl device {} show" \
    )

    [ -n "$device_power" ] \
        && case "$(get_device_power "$device_power")" in
            on)
                iwctl device "$device_power" set-property Powered off
                ;;
            off)
                iwctl device "$device_power" set-property Powered on
                ;;
        esac

    select_device
}

select_ssid() {
    ssid=$(printf "%s\n" \
            "$ssids" \
            "» enter ssid" \
            "» disconnect" \
            "» rescan" \
        | fzf --cycle \
            --preview-window "up:75%" \
            --preview-label "[ connect ]" \
            --preview "iwctl known-networks {} show >/dev/null 2>&1 \
                        && iwctl known-networks {} show \
                        || iwctl station \"$1\" get-networks" \
    )

    [ -n "$ssid" ] \
        && case "$ssid" in
            "» disconnect")
                iwctl station "$1" disconnect
                select_ssid "$1"
                ;;
            "» rescan")
                scan_ssids "$1"
                select_ssid "$1"
                ;;
            *)
                [ "$ssid" = "» enter ssid" ] \
                    && printf "leave blank to exit!\n" \
                    && printf "ssid: " \
                    && read -r ssid

                iwctl station "$1" disconnect
                connect_ssid "$1" "$(get_ssid_security "$1" "$ssid")" "$ssid"
                ;;
        esac
}

select_device \
    && scan_ssids "$device" \
    && select_ssid "$device"
