#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_mount.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2025-07-03T04:18:14+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"

# config
mount_dir="/tmp"
image_dir="$HOME/Downloads"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to un-/mount locations/devices
  Usage:
    $script

  Examples:
    $script

  Config:
    mount_dir = $mount_dir
    image_dir = $image_dir"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit

unmount() {
    case $1 in
        preview)
            findmnt -lo 'target,fstype,source,size' \
                | grep "^TARGET\|/mnt\|$mount_dir/"
            ;;
        *)
            select=$(findmnt -ro 'target' \
                | grep "/mnt\|$mount_dir/" \
                | sort \
            | fzf \
                --bind 'focus:transform-preview-label:echo [ {} ]' \
                --preview-window "right:75%" \
                --preview "findmnt -o 'target,fstype,source,size,label' -T /{1}" \
            )

            [ -z "$select" ] \
                && return 0

            printf "please wait until all write processes are finished...\n" \
                && $auth umount "$select" \
                && printf "%s unmounted\n" "$select" \
                && sleep 1 \
                && rm -d "$select"
            ;;
    esac
}

mount_usb() {
    case $1 in
        preview)
            lsblk -lpo 'name,type,fstype,size,mountpoint' \
                | awk 'NR==1 \
                        || $1!~"/dev/loop"&&$2=="part"&&$5=="" \
                        || $2=="rom"&&$3~"iso"&&$5=="" \
                        || $4=="1,4M"&&$5=="" \
                    {printf "%s\n",$0}'
            ;;
        *)
            select="$(lsblk -nrpo 'name,type,fstype,size,mountpoint' \
                | awk '$1!~"/dev/loop"&&$2=="part"&&$5=="" \
                        || $2=="rom"&&$3~"iso"&&$5=="" \
                        || $4=="1,4M"&&$5=="" \
                    {printf "%s\n",$1}' \
                | fzf \
                    --bind 'focus:transform-preview-label:echo [ {} ]' \
                    --preview-window "right:75%" \
                    --preview "lsblk -po 'name,type,fstype,fsver,size,label' /{1}" \
            )"

            [ -z "$select" ] \
                && return 0

            mount_point="$mount_dir/$(basename "$select")"
            partition_type="$(lsblk -no 'fstype' "$select")"

            [ ! -d "$mount_point" ] \
                && mkdir "$mount_point" \
                && case "$partition_type" in
                    vfat)
                        $auth mount -t "$partition_type" \
                            -o rw,umask=0000 \
                            "$select" \
                            "$mount_point"
                        ;;
                    exfat)
                        $auth mount \
                            -o rw,umask=0000 \
                            "$select" \
                            "$mount_point"
                        ;;
                    iso*)
                        $auth mount \
                            -o ro,loop \
                            "$select" \
                            "$mount_point"
                        ;;
                    *)
                        $auth mount \
                            "$select" \
                            "$mount_point"
                        $auth chown "$(whoami)": "$mount_point"
                        $auth chmod 777 "$mount_point"
                        ;;
                    esac \
                && printf "%s mounted to %s\n" "$select" "$mount_point"
            ;;
    esac
}

mount_rclone() {
    rclone_config="
        # rclone config
        webde;          /
        dropbox;        /
        gmx;            /
        googledrive;    /
        onedrive;       /
    "

    case $1 in
        preview)
            if command -v "rclone" > /dev/null 2>&1; then \
                printf "%s" "$rclone_config" \
                    | grep -v -e "^\s*$" \
                    | sed "s/^ *//g"
            else
                printf "==> this does not work without rclone installed\n"
            fi
            ;;
        *)
            select=$(printf "%s" "$rclone_config" \
                | grep -v -e "#" -e "^\s*$" \
                | cut -d ";" -f1 \
                | tr -d ' ' \
                | fzf \
                    --bind 'focus:transform-preview-label:echo [ {} ]' \
                    --preview-window "right:75%" \
                    --preview "printf \"%s\" \"$rclone_config\" \
                        | grep {1} \
                        | sed \"s/^ *//g\"" \
            )

            [ -z "$select" ] \
                && return 0

            remote_path=$(printf "%s" "$rclone_config" \
                | grep "$select;" \
                | cut -d ";" -f2 \
                | tr -d ' ' \
            )

            mount_point="$mount_dir/$select"

            [ ! -d "$mount_point" ] \
                && mkdir "$mount_point" \
                && rclone mount --daemon \
                    "$select:$remote_path" \
                    "$mount_point" \
                && printf "%s mounted to %s\n" "$select" "$mount_point"
            ;;
    esac
}

mount_image() {
    images=$(find "$image_dir" -maxdepth 1 -type f \
                -iname "*.iso" -o \
                -iname "*.img" -o \
                -iname "*.bin" -o \
                -iname "*.mdf" -o \
                -iname "*.nrg"
    )

    case $1 in
        preview)
            printf "%s" "$images"
            ;;
        *)
            select=$(printf "%s" "$images" \
                | sed "s#$image_dir/##g" \
                | fzf \
                    --bind 'focus:transform-preview-label:echo [ {} ]' \
                    --preview-window "right:75%" \
                    --preview "printf \"%s\" \"$images\" \
                        | grep {1} " \
            )

            [ -z "$select" ] \
                && return 0

            mount_point="$mount_dir/$select"

            [ ! -d "$mount_point" ] \
                && mkdir "$mount_point" \
                && $auth mount \
                    -o ro,loop \
                    "$image_dir/$select" \
                    "$mount_point" \
                && printf "%s mounted to %s\n" "$select" "$mount_point"
            ;;
    esac
}

mount_android() {
    case $1 in
        preview)
            if command -v "simple-mtpfs" > /dev/null 2>&1; then \
                simple-mtpfs --list-devices 2>/dev/null
            else
                printf "==> this does not work without simple-mtpfs installed\n"
            fi
            ;;
        *)
            select=$(simple-mtpfs --list-devices 2>/dev/null \
                | cut -d ":" -f1 \
                | fzf \
                    --bind 'focus:transform-preview-label:echo [ {} ]' \
                    --preview-window "right:75%" \
                    --preview "simple-mtpfs --device {1} -l 2>/dev/null" \
            )

            [ -z "$select" ] \
                && return 0

            mount_point="$mount_dir/$select"

            [ ! -d "$mount_point" ] \
                && mkdir "$mount_point" \
                && simple-mtpfs --device "$select" "$mount_point" \
                && printf "%s mounted to %s\n" "$select" "$mount_point"
            ;;
    esac
}

activate_superdrive() {
    case $1 in
        preview)
            if command -v "sg_raw" > /dev/null 2>&1; then \
                lsblk -lpo 'name,type,fstype,size,mountpoint' \
                    | awk 'NR==1 \
                            || $2=="rom" \
                        {printf "%s\n",$0}'
            else
                printf "==> this does not work without sg3-utils installed\n"
            fi
            ;;
        *)
            select="$(lsblk -nrpo 'name,type,fstype' \
                | awk '$2=="rom" \
                    {printf "%s\n",$1}' \
                | fzf \
                    --bind 'focus:transform-preview-label:echo [ {} ]' \
                    --preview-window "right:75%" \
                    --preview "lsblk -po 'name,type,fstype,fsver,size,label' /{1}" \
            )"

            [ -z "$select" ] \
                && return 0

            $auth sg_raw "$select" ea 00 00 00 00 00 01 \
                && printf "%s superdrive activated\n" "$select"
            ;;
    esac
}

eject_disc() {
    case $1 in
        preview)
            lsblk -lpo 'name,type,fstype,size,mountpoint' \
                | awk 'NR==1 \
                        || $2=="rom"&&$3~"iso" \
                    {printf "%s\n",$0}'
            ;;
        *)
            select="$(lsblk -nrpo 'name,type,fstype' \
                | awk '$2=="rom"&&$3~"iso" \
                    {printf "%s\n",$1}' \
                | fzf \
                    --bind 'focus:transform-preview-label:echo [ {} ]' \
                    --preview-window "right:75%" \
                    --preview "lsblk -po 'name,type,fstype,fsver,size,label' /{1}" \
            )"

            [ -z "$select" ] \
                && return 0

            $auth eject "$select" \
                && printf "%s ejected\n" "$select"
            ;;
    esac
}

exit_status() {
    printf "%s" \
        "The command exited with status $?. " \
        "Press ENTER to continue." \
    && read -r select
}

# menu
case $(printf "%s\n" \
        "refresh" \
        "unmount device" \
        "mount usb" \
        "mount rclone" \
        "mount image" \
        "mount android" \
        "activate superdrive" \
        "eject disc" \
    | fzf --cycle \
        --bind 'focus:transform-preview-label:echo [ {} ]' \
        --preview-window "right:75%" \
        --preview "case {} in
            \"refresh\")
                lsblk -o '+label'
                ;;
            \"unmount device\")
                printf \"%s\" \"$(unmount preview)\"
                ;;
            \"mount usb\")
                printf \"%s\" \"$(mount_usb preview)\"
                ;;
            \"mount rclone\")
                printf \"%s\" \"$(mount_rclone preview)\"
                ;;
            \"mount image\")
                printf \"%s\" \"$(mount_image preview)\"
                ;;
            \"mount android\")
                printf \"%s\" \"$(mount_android preview)\"
                ;;
            \"activate superdrive\")
                printf \"%s\" \"$(activate_superdrive preview)\"
                ;;
            \"eject disc\")
                printf \"%s\" \"$(eject_disc preview)\"
                ;;
            esac " \
    ) in
    "refresh")
        "$0"
        ;;
    "unmount device")
        unmount \
            || exit_status
        "$0"
        ;;
    "mount usb")
        mount_usb \
            || exit_status
        "$0"
        ;;
    "mount rclone")
        mount_rclone \
            || exit_status
        "$0"
        ;;
    "mount image")
        mount_image \
            || exit_status
        "$0"
        ;;
    "mount android")
        mount_android \
            || exit_status
        "$0"
        ;;
    "activate superdrive")
        activate_superdrive \
            || exit_status
        "$0"
        ;;
    "eject disc")
        eject_disc \
            || exit_status
        "$0"
        ;;
esac
