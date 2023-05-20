#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_iwd.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-05-20T17:41:19+0200

remove_escape_sequences() {
    tail -n +5 \
        | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g;/^\s*$/d'
}

read_secret() {
    stty -echo
    trap 'stty echo' EXIT

    # shellcheck disable=SC2162
    read "$@"

    stty echo
    trap - EXIT

    printf "\n"
}

connect_ssid() {
    case "$1" in
        open)
            printf "try to connect to \"%s\"" "$ssid"
            iwctl station "$device" connect "$ssid"
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
            printf "try to connect to \"%s\" with psk" "$ssid"
            iwctl station "$device" connect "$ssid" -P "$psk"
            ;;
    esac
}

select_device_power() {
    interface=$(iwctl device list \
        | remove_escape_sequences \
    )

    device=$(printf "%s" "$interface" \
        | awk '{print $1}' \
        | fzf -e --cycle \
            --preview-window "up:75%" \
            --preview-label "[ toggle power ]" \
            --preview "iwctl device {} show" \
    )

    power=$(printf "%s" "$interface" \
        | grep "$device" \
        | awk '{print $3}' \
    )

    [ -n "$device" ] \
        && case $power in
            on)
                iwctl device "$device" set-property Powered off
                ;;
            off)
                iwctl device "$device" set-property Powered on
                ;;
        esac

    select_device
}

select_device() {
    interface=$(iwctl device list \
        | remove_escape_sequences \
    )

    device=$(printf "%s" "$interface" \
        | awk '{print $1"\n== toggle power =="}' \
        | fzf -e --cycle \
            --preview-window "up:75%" \
            --preview-label "[ device ]" \
            --preview "case {} in
                \"== toggle power ==\")
                    iwctl device list
                    ;;
                *)
                    iwctl station {} show
                    ;;
            esac" \
    )

    power=$(printf "%s" "$interface" \
        | grep "$device" \
        | awk '{print $3}' \
    )

    [ "$device" = "== toggle power ==" ] \
        || [ "$power" = "off" ] \
        && select_device_power

    [ -n "$device" ] \
        || exit 1
}

scan_ssids() {
    timer=3

    iwctl station "$device" scan \
        && printf "scan for ssids with device %s, please wait %s seconds\n" \
            "$device" \
            "$timer" \
        && sleep $timer

    ssids=$(iwctl station "$device" get-networks \
        | remove_escape_sequences \
        | sed 's/>//' \
        | awk '{print $1}' \
    )
}

select_ssid() {
    ssid=$(printf "%s\n" \
            "$ssids" \
            "== enter ssid ==" \
            "== disconnect ==" \
            "== rescan ==" \
        | fzf -e --cycle \
            --preview-window "up:75%" \
            --preview-label "[ connect ]" \
            --preview "iwctl known-networks {} show >/dev/null 2>&1 \
                        && iwctl known-networks {} show \
                        || iwctl station \"$device\" get-networks" \
    )

    security=$(iwctl station "$device" get-networks \
        | remove_escape_sequences \
        | sed 's/>//' \
        | awk '{print $2}' \
    )

    [ -n "$ssid" ] \
        && case "$ssid" in
            "== disconnect ==")
                iwctl station "$device" disconnect
                select_ssid
                ;;
            "== rescan ==")
                scan_ssids
                select_ssid
                ;;
            *)
                [ "$ssid" = "== enter ssid ==" ] \
                    && printf "leave blank to exit!\n" \
                    && printf "ssid: " \
                    && read -r ssid

                iwctl station "$device" disconnect
                connect_ssid "$security"
                ;;
        esac
}

select_device \
    && scan_ssids \
    && select_ssid
