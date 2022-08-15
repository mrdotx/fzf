#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_mount.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-08-14T20:54:40+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"

#config
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
    && exit 0

unmount() {
    case $1 in
        preview)
            findmnt -lo TARGET,FSTYPE,SOURCE \
                | grep "^TARGET\|/mnt\|$mount_dir/"
            ;;
        *)
            select=$(findmnt -ro TARGET \
                | grep "/mnt\|$mount_dir/" \
                | sort \
            | fzf -e -i --cycle --preview \
                    "findmnt -T /{1}" \
                --preview-window "right:70%" \
            )

            [ -z "$select" ] \
                && return 0

            $auth umount "$select" \
                && printf "%s unmounted\n" "$select" \
                && sleep 1 \
                && rm -d "$select"
            ;;
    esac
}

mount_usb() {
    case $1 in
        preview)
            lsblk -lpo "name,type,fstype,size,mountpoint" \
                | awk 'NR==1 \
                        || $1!~"/dev/loop"&&$2=="part"&&$5=="" \
                        || $2=="rom"&&$3~"iso"&&$5=="" \
                        || $4=="1,4M"&&$5=="" \
                    {printf "%s\n",$0}'
            ;;
        *)
            select="$(lsblk -nrpo "name,type,fstype,size,mountpoint" \
                | awk '$1!~"/dev/loop"&&$2=="part"&&$5=="" \
                        || $2=="rom"&&$3~"iso"&&$5=="" \
                        || $4=="1,4M"&&$5=="" \
                    {printf "%s\n",$1}' \
                | fzf -e -i --cycle --preview \
                        "lsblk -po 'name,type,fstype,fsver,size,label' /{1}" \
                    --preview-window "right:70%" \
            )"

            [ -z "$select" ] \
                && return 0

            mount_point="$mount_dir/$(basename "$select")"
            partition_type="$(lsblk -no "fstype" "$select")"

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
                        user="$(whoami)"
                        user_group="$(groups | cut -d " " -f1)"
                        $auth chown "$user":"$user_group" 741 "$mount_point"
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
            printf "%s" "$rclone_config" \
                | grep -v -e "^\s*$" \
                | sed "s/^ *//g"
            ;;
        *)
            select=$(printf "%s" "$rclone_config" \
                | grep -v -e "#" -e "^\s*$" \
                | cut -d ";" -f1 \
                | tr -d ' ' \
                | fzf -e -i --cycle --preview \
                        "printf \"%s\" \"$rclone_config\" \
                            | grep {1} \
                            | sed \"s/^ *//g\"" \
                    --preview-window "right:70%" \
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
    images=$(find "$image_dir" -type f \
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
                | fzf -e -i --cycle --preview \
                        "printf \"%s\" \"$images\" \
                            | grep {1} " \
                    --preview-window "right:70%" \
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
            simple-mtpfs -l 2>/dev/null
            ;;
        *)
            select=$(simple-mtpfs -l 2>/dev/null \
                | cut -d ":" -f1 \
                | fzf -e -i --cycle --preview \
                        "simple-mtpfs --device {1} -l 2>/dev/null" \
                    --preview-window "right:70%"
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

eject_dvd() {
    case $1 in
        preview)
            lsblk -lpo "name,type,fstype,size,mountpoint" \
                | awk 'NR==1 \
                        || $2=="rom"&&$3~"iso" \
                    {printf "%s\n",$0}'
            ;;
        *)
            select="$(lsblk -nrpo "name,type,fstype" \
                | awk '$2=="rom"&&$3~"iso" \
                    {printf "%s\n",$1}' \
                | fzf -e -i --cycle --preview \
                        "lsblk -po 'name,type,fstype,fsver,size,label' /{1}" \
                    --preview-window "right:70%" \
            )"

            [ -z "$select" ] \
                && return 0

            $auth eject "$select" \
                && printf "%s ejected\n" "$select"
            ;;
    esac
}

# menu
case $(printf "%s\n" \
    "unmount" \
    "usb" \
    "rclone" \
    "image" \
    "android" \
    "eject" \
    | fzf -e -i --cycle --preview "case {1} in
    unmount)
        printf \"%s\" \"$(unmount preview)\"
        ;;
    usb)
        printf \"%s\" \"$(mount_usb preview)\"
        ;;
    rclone)
        printf \"%s\" \"$(mount_rclone preview)\"
        ;;
    image)
        printf \"%s\" \"$(mount_image preview)\"
        ;;
    android)
        printf \"%s\" \"$(mount_android preview)\"
        ;;
    eject)
        printf \"%s\" \"$(eject_dvd preview)\"
        ;;
    esac " \
        --preview-window "right:70%" \
    ) in
    "unmount")
        unmount \
            && "$0"
        ;;
    "usb")
        mount_usb \
            && "$0"
        ;;
    "rclone")
        mount_rclone \
            && "$0"
        ;;
    "image")
        mount_image \
            && "$0"
        ;;
    "android")
        mount_android \
            && "$0"
        ;;
    "eject")
        eject_dvd \
            && "$0"
        ;;
esac
