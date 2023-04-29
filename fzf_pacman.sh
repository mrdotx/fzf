#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_pacman.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-04-29T10:46:04+0200

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"

# config
display="$PAGER"
edit="$EDITOR"
aur_helper="paru"
aur_folder="$HOME/.config/paru"
aur_config="$aur_folder/paru.conf"
aur_cache="$HOME/.cache/paru/clone"
ala_url="https://archive.archlinux.org/packages"
pacman_log="/var/log/pacman.log"
pacman_cache="/var/cache/pacman/pkg"
pacman_cache_versions=2
pacman_config="/etc/pacman.conf"
pacman_mirrors="/etc/pacman.d/mirrorlist"
backup_all="$aur_folder/pkgs_all.txt"
backup_explicit="$aur_folder/pkgs_explicit.txt"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to manage packages with pacman and $aur_helper
  Usage:
    $script

  Examples:
    $script

  Config:
    display               = $display
    edit                  = $edit
    aur_helper            = $aur_helper
    aur_folder            = $aur_folder
    aur_config            = $aur_config
    aur_cache             = $aur_cache
    ala_url               = $ala_url
    pacman_log            = $pacman_log
    pacman_cache          = $pacman_cache
    pacman_cache_versions = $pacman_cache_versions
    pacman_config         = $pacman_config
    pacman_mirrors        = $pacman_mirrors
    backup_all            = $backup_all
    backup_explicit       = $backup_explicit

  Backup:
    To reinstall the packages from the backup list, use the following command:
    $aur_helper -S --needed - < \"$backup_explicit\""

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit 0

# helper functions
log_filter=".*\[ALPM\].*(.*)"
log_last_action() {
    grep "$log_filter" "$pacman_log" \
        | tail -n1 \
        | cut -b 2-11
}

get_mirrors() {
    grep "^Server = " "$1" \
        | sed -e "s/^Server = //g" \
            -e "s/\/\$repo.*$//g"
}

get_mirrors_date() {
    date -d "@$(curl -fs "$1")" "+%d.%m.%Y_%H:%M" 2>/dev/null \
        || printf "unreachable     "
}

get_mirrors_time() {
    curl -s -m 5 -w "%{time_total} %{http_code}" -o /dev/null \
        "$1/core/os/$(uname -m)/core.db.tar.gz"
}

analyze_mirrors() {
    header="time     code synchronized     updated          mirror"

    printf "%s\n" "$header"
    for url in $(get_mirrors "$1"); do
        output=$(printf "%s  %s %s %s\n" \
            "$(get_mirrors_time "$url")" \
            "$(get_mirrors_date "$url/lastsync")" \
            "$(get_mirrors_date "$url/lastupdate")" \
            "$url"
        )
        printf "%s\n" "$output"
        sorted=$(printf "%s\n%s" "$sorted" "$output")
    done

    printf "\n%s%s\n" "$header" "$sorted" \
        | sort -n
    unset sorted
}

pkg_lists_backup() {
    "$aur_helper" -Qq > "$backup_all"
    "$aur_helper" -Qqe > "$backup_explicit"
}

pkg_files() {
    find "$1" -type f \( -iname '*.pkg.tar.*' ! -iname '*.sig' \) -print0 \
        | xargs -0 basename -a \
        | sort
}

pkg_fullpath() {
    path="$1"
    shift
    files="$*"
    for file in $files; do
        find "$path" -iname "$file"
    done
}

aur_helper_downgrade() {
    select=$(pkg_files "$1" \
        | fzf -m -e --cycle)
    [ $? -eq 130 ] \
        && return 130
    [ -n "$select" ] \
        && select="$auth $aur_helper -U $(pkg_fullpath "$1" "$select")" \
        && $select
}

ala_files() {
    curl -fsS "$1" \
        | grep "^<a href=" \
        | sed -e "/.sig\"/d" \
            -e "s/<a href=\"$2/$2/g" \
            -e "s/\">$2.*$//g"
}

ala_downgrade() {
    ala_pkg=$("$aur_helper" -Qq \
        | fzf -e --cycle)
    [ $? -eq 130 ] \
        && return 130
    [ -z "$ala_pkg" ] \
        && return

    url=$(printf "%s/%s/%s/\n" \
        "$1" \
        "${ala_pkg%"${ala_pkg#?}"}" \
        "$ala_pkg" \
    )

    select=$(ala_files "$url" "$ala_pkg" \
        | fzf -e --cycle)
    [ $? -eq 130 ] \
        && return 130
    [ -n "$select" ] \
        && select="$auth $aur_helper -U $url$select" \
        && $select
}

aur_execute() {
    select=$( \
        eval $aur_helper -"$1" \
        | fzf -m -e --cycle \
            --preview-window "up:75%:wrap" \
            --preview "$aur_helper -$2 {1}" \
    )
    [ $? -eq 130 ] \
        && return 130
    [ -n "$select" ] \
        && select="$aur_helper -$3 $select" \
        && $select
}

exit_status() {
    ! [ $? -eq 130 ] \
        && printf "%s" \
            "The command exited with status $?. " \
            "Press ENTER to continue." \
        && read -r select
}

while true; do
    # menu
    select=$(printf "%s\n" \
                "view pacman.log" \
                "system upgrade" \
                "install packages" \
                "install arch packages" \
                "install aur packages" \
                "remove arch packages" \
                "remove aur packages" \
                "remove explicit installed packages" \
                "remove packages without dependencies" \
                "downgrade arch packages" \
                "downgrade aur packages" \
                "downgrade ala packages" \
                "edit pacman config" \
                "edit $aur_helper config" \
                "edit pacman mirrorlist" \
                "analyze pacman mirrors" \
                "diff package config" \
                "clear package cache" \
        | fzf -e --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%" \
            --preview "case {} in
                \"clear package cache\")
                    printf \":: old packages\n\"
                    \"$auth\" paccache -dvk$pacman_cache_versions
                    printf \":: uninstalled packages\n\"
                    \"$auth\" paccache -dvuk0
                    printf \":: orphan packages\n\"
                    \"$aur_helper\" -Qdtq
                    ;;
                \"diff package config\")
                    printf \":: pacorig, pacnew and pacsav files\n\"
                    \"$auth\" pacdiff -f -o
                    ;;
                \"analyze pacman mirrors\")
                    printf \":: currently used mirrors\n\"
                    printf \"%s\" \"$(get_mirrors "$pacman_mirrors")\"
                    ;;
                \"edit pacman mirrorlist\")
                    printf \"%s\" \"$(sed "s/\/\$repo.*$//g" "$pacman_mirrors")\"
                    ;;
                \"edit $aur_helper config\")
                    cat \"$aur_config\"
                    ;;
                \"edit pacman config\")
                    cat \"$pacman_config\"
                    ;;
                \"downgrade ala packages\")
                    \"$aur_helper\" -Qq
                    ;;
                \"downgrade aur packages\")
                    printf \"%s\" \"$(pkg_files "$aur_cache")\"
                    ;;
                \"downgrade arch packages\")
                    printf \"%s\" \"$(pkg_files "$pacman_cache")\"
                    ;;
                \"remove packages without dependencies\")
                    \"$aur_helper\" -Qqt
                    ;;
                \"remove explicit installed packages\")
                    \"$aur_helper\" -Qqe
                    ;;
                \"remove aur packages\")
                    \"$aur_helper\" -Qmq
                    ;;
                \"remove arch packages\")
                    \"$aur_helper\" -Qq
                    ;;
                \"install aur packages\")
                    \"$aur_helper\" -Slq --aur
                    ;;
                \"install arch packages\")
                    \"$aur_helper\" -Slq --repo
                    ;;
                \"install packages\")
                    \"$aur_helper\" -Slq
                    ;;
                \"system upgrade\")
                    printf \":: packages to update\n\"
                    checkupdates
                    \"$aur_helper\" -Qua
                    ;;
                \"view pacman.log\")
                    printf \":: today's activities\n\"
                    grep \"$log_filter\" \"$pacman_log\" \
                        | grep \"$(log_last_action)\" \
                        | cut -d ' ' -f3- \
                        | tac
                    ;;
            esac" \
    )

    # select executable
    case "$select" in
        "clear package cache")
            "$auth" paccache -rvk$pacman_cache_versions
            "$auth" paccache -rvuk0
            "$aur_helper" -c
            ;;
        "diff package config")
            "$auth" pacdiff -f
            ;;
        "analyze pacman mirrors")
            analyze_mirrors "$pacman_mirrors"
            exit_status
            ;;
        "edit pacman mirrorlist")
            "$auth" "$edit" "$pacman_mirrors"
            ;;
        "edit $aur_helper config")
            "$edit" "$aur_config"
            ;;
        "edit pacman config")
            "$auth" "$edit" "$pacman_config"
            ;;
        "downgrade ala packages")
            ala_downgrade "$ala_url"
            exit_status
            ;;
        "downgrade aur packages")
            aur_helper_downgrade "$aur_cache"
            exit_status
            ;;
        "downgrade arch packages")
            aur_helper_downgrade "$pacman_cache"
            exit_status
            ;;
        "remove packages without dependencies")
            aur_execute "Qqt" "Qlii" "Rsn"
            exit_status
            ;;
        "remove explicit installed packages")
            aur_execute "Qqe" "Qlii" "Rsn"
            exit_status
            ;;
        "remove aur packages")
            aur_execute "Qmq" "Qlii" "Rsn"
            exit_status
            ;;
        "remove arch packages")
            aur_execute "Qq" "Qlii" "Rsn"
            exit_status
            ;;
        "install aur packages")
            aur_execute "Slq --aur" "Sii" "S"
            exit_status
            ;;
        "install arch packages")
            aur_execute "Slq --repo" "Sii" "S"
            exit_status
            ;;
        "install packages")
            aur_execute "Slq" "Sii" "S"
            exit_status
            ;;
        "system upgrade")
            "$aur_helper" -Syu
            exit_status
            ;;
        "view pacman.log")
            tac "$pacman_log" | "$display"
            ;;
        *)
            pkg_lists_backup
            break
            ;;
    esac
done
