#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_mount.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-08-13T12:02:57+0200

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"

#config
mount_dir="/tmp"
image_folder="$HOME/Downloads"

unmount() {
    case $1 in
        preview)
            findmnt -r -o TARGET,FSTYPE,SOURCE\
                | grep "/mnt\|$mount_dir/"
            ;;
        *)
            select=$(findmnt -r -o TARGET \
                | grep "/mnt\|$mount_dir/" \
                | sort \
            | fzf -m -e -i --preview \
                    "findmnt -o TARGET,FSTYPE,SOURCE -T /{1}" \
                --preview-window "right:70%" \
            )

            [ -z "$select" ] \
                && return 0

            $auth umount "$select" \
                && printf "%s unmounted\n" "$select" \
                && rm -d "$select"
            ;;
    esac
}

mount_usb() {
    case $1 in
        preview)
            lsblk -nrpo "name,type,fstype,fsver,label,size,mountpoint" \
                | awk '{if ($2=="part"&&$7=="" \
                            || $2=="rom"&&$7=="" \
                            || $6=="1,4M"&&$7=="") \
                        printf "%s %s %s %s %s %s %s\n",$1,$2,$3,$4,$5,$6,$7}'
            ;;
        *)
            select="$(lsblk -nrpo "name,type,size,mountpoint" \
                | awk '{if ($2=="part"&&$4=="" \
                            || $2=="rom"&&$4=="" \
                            || $3=="1,4M"&&$4=="") \
                        printf "%s\n",$1}' \
                | fzf -m -e -i --preview \
                        "lsblk -po 'name,type,fstype,fsver,label,size' /{1}" \
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
                            "$select" \
                            "$mount_point" \
                            -o rw,umask=0000 \
                        ;;
                    exfat)
                        $auth mount \
                            "$select" \
                            "$mount_point" \
                            -o rw,umask=0000 \
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

mount_remote() {
    remote_config="
        # rclone config
        webde;          /
        dropbox;        /
        gmx;            /
        googledrive;    /
        onedrive;       /
    "

    case $1 in
        preview)
            printf "%s" "$remote_config" \
                | grep -v -e "^\s*$" \
                | sed "s/^ *//g"
            ;;
        *)
            select=$(printf "%s" "$remote_config" \
                | grep -v -e "#" -e "^\s*$" \
                | cut -d ";" -f1 \
                | tr -d ' ' \
                | fzf -m -e -i --preview \
                        "printf \"%s\" \"$remote_config\" \
                            | grep {1} \
                            | sed \"s/^ *//g\"" \
                    --preview-window "right:70%" \
            )

            [ -z "$select" ] \
                && return 0

            remote_directory=$(printf "%s" "$remote_config" \
                | grep "$select;" \
                | cut -d ";" -f2 \
                | tr -d ' ' \
            )

            mount_point="$mount_dir/$select"

            [ ! -d "$mount_point" ] \
                && mkdir "$mount_point" \
                && sleep 1 \
                && rclone mount --daemon \
                    "$select:$remote_directory" \
                    "$mount_point" \
                && printf "%s mounted to %s\n" "$select" "$mount_point"
            ;;
    esac
}

mount_image() {
    images=$(find "$image_folder" -type f \
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
            select=$(printf "%s" "${images##*/}" \
                | fzf -m -e -i --preview \
                        "printf \"%s\" \"$images\" \
                            | grep {1} " \
                    --preview-window "right:70%" \
            )

            [ -z "$select" ] \
                && return 0

            mount_point="$mount_dir/$select"

            [ ! -d "$mount_point" ] \
                && mkdir "$mount_point" \
                && $auth mount -r \
                    "$image_folder/$select" \
                    "$mount_point" \
                    -o loop \
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
                | fzf -m -e -i --preview \
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
            lsblk -nrpo "name,type,fstype,fsver,label,size,mountpoint" \
                | awk '$2=="rom" \
                    {printf "%s %s %s %s %s %s %s\n",$1,$2,$3,$4,$5,$6,$7}'
            ;;
        *)
            select="$(lsblk -nrpo "name,type,size,mountpoint" \
                | awk '$2=="rom" \
                    {printf "%s\n",$1}' \
                | fzf -m -e -i --preview \
                        "lsblk -po 'name,type,fstype,fsver,label,size' /{1}" \
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
    "mount usb" \
    "mount remote" \
    "mount image" \
    "mount android" \
    "eject dvd" \
    | fzf -m -e -i --preview "case {1}{2} in
    unmount)
        printf \"%s\" \"$(unmount preview)\"
        ;;
    mount*usb)
        printf \"%s\" \"$(mount_usb preview)\"
        ;;
    mount*remote)
        printf \"%s\" \"$(mount_remote preview)\"
        ;;
    mount*image)
        printf \"%s\" \"$(mount_image preview)\"
        ;;
    mount*android)
        printf \"%s\" \"$(mount_android preview)\"
        ;;
    eject*dvd)
        printf \"%s\" \"$(eject_dvd preview)\"
        ;;
    esac " \
        --preview-window "right:70%" \
    ) in
    "unmount")
        unmount \
            && "$0"
        ;;
    "mount usb")
        mount_usb \
            && "$0"
        ;;
    "mount remote")
        mount_remote \
            && "$0"
        ;;
    "mount image")
        mount_image \
            && "$0"
        ;;
    "mount android")
        mount_android \
            && "$0"
        ;;
    "eject dvd")
        eject_dvd \
            && "$0"
        ;;
esac
