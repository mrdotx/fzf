#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_pacman.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2024-03-24T09:53:25+0100

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"

# config
display="$PAGER"
edit="$EDITOR"
aur_helper="paru"
aur_cache="$HOME/.cache/$aur_helper/clone"
aur_folder="$HOME/.config/$aur_helper"
aur_config="$aur_folder/paru.conf"
ala_url="https://archive.archlinux.org/packages"
pacman_cache="/var/cache/pacman/pkg"
pacman_cache_versions=1
pacman_config="/etc/pacman.conf"
pacman_mirrors="/etc/pacman.d/mirrorlist"
pacman_log="/var/log/pacman.log"
pacman_log_days=180
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
    aur_cache             = $aur_cache
    aur_folder            = $aur_folder
    aur_config            = $aur_config
    ala_url               = $ala_url
    pacman_cache          = $pacman_cache
    pacman_cache_versions = $pacman_cache_versions
    pacman_config         = $pacman_config
    pacman_mirrors        = $pacman_mirrors
    pacman_log            = $pacman_log
    pacman_log_days       = $pacman_log_days
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
log_latest_activities() {
    grep "$log_filter" "$pacman_log" \
        | tail -n1 \
        | cut -b 2-11
}

log_clear() {
    printf \
        "Remove data from pacman.log that are older then %s day(s)? [y]es/[N]o: " \
        "$pacman_log_days" \
            && read -r clear_log

    case $clear_log in
        y|Y|yes|Yes)
            pacman_log_bak="/tmp/pacman.log.bak"

            "$auth" mv "$pacman_log" "$pacman_log_bak" \
                && awk -v Date="$(date -d "now-$pacman_log_days days" \
                        "+[%Y-%m-%dT%H:%M:%S+0000]")" \
                        '$1 > Date {print $0}' "$pacman_log_bak" \
                    | "$auth" tee "$pacman_log" >/dev/null
            ;;
    esac
}

get_mirrors() {
    grep "^Server = " "$1" \
        | sed -e "s/^Server = //g" \
            -e "s/\/\$repo.*$//g"
}

get_mirrors_date() {
    date -d "@$(curl -Lfs -m 3.33 "$1")" "+%m-%dT%H:%M" 2>/dev/null \
        || printf "unreachable"
}

get_mirrors_data() {
    output=$(curl -Ls -m 9.99 -w "%{time_total} %{http_code}" -o /dev/null \
        "$1/core/os/$(uname -m)/core.db.tar.gz" \
    )
    [ $? -eq 28 ] \
        && printf "                        timeout" \
        && return

    code=$(printf "%s\n" "$output" \
        | cut -d ' ' -f2 \
    )

    [ "$code" -eq 000 ] \
        && printf "                        unknown" \
        && return
    [ "$code" -ne 200 ] \
        && printf "                       http %s" "$code" \
        && return

    printf "%.5f %s %s\n" \
        "$(printf "%s\n" "$output" | cut -d ' ' -f1)" \
        "$(get_mirrors_date "$url/lastsync")" \
        "$(get_mirrors_date "$url/lastupdate")"
}

get_mirror_status() {
    tag="$1"
    url="$2"
    shift 2

    output=$(printf "%s\n" "$*" \
        | awk -F "\"$url" '{print $2}' \
        | awk -F "\"$tag\": " '{print $2}' \
        | cut -d ',' -f1 \
    )

    { [ -z "$output" ] || [ "$output" = "null" ] ;} \
        && printf "n/a\n" \
        && return

    [ "$(printf "%.0f" "$output")" -gt 99 ] \
        && printf "bad\n" \
        && return

    printf "%.2f\n" "$output"
}

analyze_mirrors() {
    status_data=$(curl -LfsS -m 9.99 -H "Accept: application/json" \
        "https://archlinux.org/mirrors/status/json" \
    )
    header="time    synched     database    rank score mirror"

    printf "%s\n" "$header"
    for url in $(get_mirrors "$1"); do
        order=$((order+1))
        output=$(printf "%s %04s %05s %s\n" \
            "$(get_mirrors_data "$url")" \
            "$order" \
            "$(get_mirror_status "score" "$url" "$status_data")" \
            "$url"
        )
        printf "%s\n" "$output"
        sorted=$(printf "%s\n%s" "$sorted" "$output")
    done

    sorted=$(printf "%s" "$sorted" \
        | sort -b \
    )

    printf "\n%s%s" "$header" "$sorted"

    printf "\n\n## Mirrors %s\n" "$(date -I)"
    printf "%s" "$sorted" \
        | awk '$6{print "Server = "$6"/$repo/os/$arch"}'
    printf "\n"

    unset order sorted
}

pkg_lists_backup() {
    "$aur_helper" -Qq > "$backup_all"
    "$aur_helper" -Qqe > "$backup_explicit"
}

pkg_files() {
    find "$1" -type f \( -iname '*.pkg.tar.*' ! -iname '*.sig' \) -print0 \
        | xargs -0 basename -a 2>/dev/null \
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
        | fzf -m -e \
    )
    [ $? -eq 130 ] \
        && return 130
    [ -n "$select" ] \
        && select="$aur_helper -U $(pkg_fullpath "$1" "$select")" \
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
        | fzf -e \
    )
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
        | fzf -e \
    )
    [ $? -eq 130 ] \
        && return 130
    [ -n "$select" ] \
        && select="$aur_helper -U $url$select" \
        && $select
}

aur_execute() {
    select=$( \
        eval $aur_helper -"$1" \
        | fzf -m -e \
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
                "remove packages" \
                "remove explicit installed packages" \
                "remove packages without dependencies" \
                "remove aur packages" \
                "downgrade arch packages" \
                "downgrade aur packages" \
                "downgrade ala packages" \
                "edit pacman config" \
                "edit $aur_helper config" \
                "edit pacman mirrorlist" \
                "analyze pacman mirrors" \
                "diff package config" \
                "clear pacman.log" \
                "clear package cache" \
        | fzf -e --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%" \
            --preview "case {} in
                \"view pacman.log\")
                    printf \":: latest activities\n\"
                    grep \"$log_filter\" \"$pacman_log\" \
                        | grep \"$(log_latest_activities)\" \
                        | cut -d ' ' -f3- \
                        | tac
                    ;;
                \"system upgrade\")
                    printf \":: packages to update\n\"
                    checkupdates --nocolor
                    \"$aur_helper\" -Qua
                    ;;
                \"install packages\")
                    \"$aur_helper\" -Slq
                    ;;
                \"install arch packages\")
                    \"$aur_helper\" -Slq --repo
                    ;;
                \"install aur packages\")
                    \"$aur_helper\" -Slq --aur
                    ;;
                \"remove packages\")
                    \"$aur_helper\" -Qq
                    ;;
                \"remove explicit installed packages\")
                    \"$aur_helper\" -Qqe
                    ;;
                \"remove packages without dependencies\")
                    \"$aur_helper\" -Qqt
                    ;;
                \"remove aur packages\")
                    \"$aur_helper\" -Qmq
                    ;;
                \"downgrade arch packages\")
                    printf \"%s\" \"$(pkg_files "$pacman_cache")\"
                    ;;
                \"downgrade aur packages\")
                    printf \"%s\" \"$(pkg_files "$aur_cache")\"
                    ;;
                \"downgrade ala packages\")
                    \"$aur_helper\" -Qq
                    ;;
                \"edit pacman config\")
                    cat \"$pacman_config\"
                    ;;
                \"edit $aur_helper config\")
                    cat \"$aur_config\"
                    ;;
                \"edit pacman mirrorlist\")
                    printf \"%s\" \"$(sed "s/\/\$repo.*$//g" "$pacman_mirrors")\"
                    ;;
                \"analyze pacman mirrors\")
                    printf \":: currently used mirrors\n\"
                    printf \"%s\" \"$(get_mirrors "$pacman_mirrors")\"
                    ;;
                \"diff package config\")
                    printf \":: pacorig, pacnew and pacsav files\n\"
                    \"$auth\" pacdiff -f -o
                    ;;
                \"clear pacman.log\")
                    cat \"$pacman_log\"
                    ;;
                \"clear package cache\")
                    printf \":: old packages\n\"
                    \"$auth\" paccache -dvk$pacman_cache_versions
                    printf \":: uninstalled packages\n\"
                    \"$auth\" paccache -dvuk0
                    printf \":: orphan packages\n\"
                    \"$aur_helper\" -Qdtq
                    ;;
            esac" \
    )

    # select executable
    case "$select" in
        "view pacman.log")
            tac "$pacman_log" | "$display"
            ;;
        "system upgrade")
            "$aur_helper" -Syu
            exit_status
            ;;
        "install packages")
            aur_execute "Slq" "Sii" "S"
            exit_status
            ;;
        "install arch packages")
            aur_execute "Slq --repo" "Sii" "S"
            exit_status
            ;;
        "install aur packages")
            aur_execute "Slq --aur" "Sii" "S"
            exit_status
            ;;
        "remove packages")
            aur_execute "Qq" "Qlii" "Rsn"
            exit_status
            ;;
        "remove explicit installed packages")
            aur_execute "Qqe" "Qlii" "Rsn"
            exit_status
            ;;
        "remove packages without dependencies")
            aur_execute "Qqt" "Qlii" "Rsn"
            exit_status
            ;;
        "remove aur packages")
            aur_execute "Qmq" "Qlii" "Rsn"
            exit_status
            ;;
        "downgrade arch packages")
            aur_helper_downgrade "$pacman_cache"
            exit_status
            ;;
        "downgrade aur packages")
            aur_helper_downgrade "$aur_cache"
            exit_status
            ;;
        "downgrade ala packages")
            ala_downgrade "$ala_url"
            exit_status
            ;;
        "edit pacman config")
            "$auth" "$edit" "$pacman_config"
            ;;
        "edit $aur_helper config")
            "$edit" "$aur_config"
            ;;
        "edit pacman mirrorlist")
            "$auth" "$edit" "$pacman_mirrors"
            ;;
        "analyze pacman mirrors")
            analyze_mirrors "$pacman_mirrors"
            exit_status
            ;;
        "diff package config")
            "$auth" pacdiff -f
            ;;
        "clear pacman.log")
            log_clear
            "$auth" "$edit" "$pacman_log"
            ;;
        "clear package cache")
            "$auth" paccache -rvk$pacman_cache_versions
            "$auth" paccache -rvuk0
            "$aur_helper" -c
            ;;
        *)
            pkg_lists_backup
            break
            ;;
    esac
done
