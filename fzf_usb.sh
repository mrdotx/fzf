#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_usb.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-05-27T11:53:17+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to manage usb devices
  Usage:
    $script [--bind] [--unbind] [--rebind]

  Settings:
    [--bind]   = try to bind logical device
    [--unbind] = try to unbind logical device
    [--rebind] = try to unbind and bind logical device

  Examples:
    $script
    $script --bind \"Bus 003 Device 001\"
    $script --unbind \"Bus 003 Device 001\"
    $script --rebind \"Bus 003 Device 001\""

logical_device() {
    path_devices="/sys/bus/usb/devices"
    path_drivers="/sys/bus/usb/drivers/usb"

    ports=$(find "$path_devices" -type l \
        | sort \
        | cut -d '/' -f6 \
    )

    device() {
        for port in $ports; do
            get_info() {
                [ -e "$path_devices/$port/$1" ] \
                    && cat "$path_devices/$port/$1"
            }

            printf "Bus %03d Device %03d:%s\n" \
                "$(get_info "busnum")" \
                "$(get_info "devnum")" \
                "$port" \
                    | awk '{$1=$1;print}'
        done \
            | grep -m1 "$1" \
            | cut -d':' -f2
    }

    $auth sh -c "printf '%s' \"$(device "$1")\" \
        > \"$path_drivers/$2\"" 2>/dev/null \
        || return 0
}

usb() {
    [ -n "$2" ] \
        && select=$(lsusb \
            | grep -m1 "$2" \
            | cut -d ':' -f1 \
        )

    case "$1" in
        rebind)
            logical_device "$select" "unbind"
            sleep 1
            logical_device "$select" "bind"
            ;;
        *bind)
            logical_device "$select" "$1"
            ;;
        *)
            exit 0
            ;;
    esac
}

select_usb() {
    device_info="$(lsusb -v 2>/dev/null)"

    select=$(lsusb \
        | cut -d ':' -f1 \
        | sort -k 2,4\
        | fzf -e --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%,wrap" \
            --preview "printf '%s\n\n' '$device_info' \
                | sed \
                    -e '/./{H;$!d;}' \
                    -e 'x;/{1} {2} {3} {4}/!d;' \
                | sed '/^$/d'" \
    )

    [ -n "$select" ] \
        && bind=$(printf "%s\n" \
                    "bind" \
                    "unbind" \
                    "rebind" \
        | fzf -e --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%,wrap" \
            --preview "printf '%s\n\n' '$device_info' \
                | sed \
                    -e '/./{H;$!d;}' \
                    -e 'x;/$select/!d;' \
                | sed '/^$/d'" \
        )

    [ -n "$bind" ] \
        && usb "$bind"
}

case "$1" in
    -h | --help)
        printf "%s\n" "$help" \
        && exit 0
        ;;
    --*)
        usb "${1##*--}" "$2"
        ;;
    *)
        select_usb \
            && sleep 1 \
            && "$0" \
                || exit 0
        ;;
esac
