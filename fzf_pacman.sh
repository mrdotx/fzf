#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_pacman.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-04-14T08:24:46+0200

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

pacman_downgrade() {
    select=$(pkg_files "$1" \
        | fzf -m -e -i)
    [ $? -eq 130 ] \
        && return 130
    [ -n "$select" ] \
        && select="$auth pacman -U $(pkg_fullpath "$1" "$select")" \
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
        | fzf -e -i)
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
        | fzf -e -i)
    [ $? -eq 130 ] \
        && return 130
    [ -n "$select" ] \
        && select="$auth pacman -U $url$select" \
        && $select
}

aur_execute() {
    select=$( \
        eval $aur_helper -"$1" \
        | fzf -m -e -i --preview "$aur_helper -$2 {1}" \
            --preview-window "right:70%:wrap" \
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
                "1) view pacman.log" \
                "2) system upgrade" \
                "3) install packages" \
                "3.1) pacman" \
                "3.2) aur" \
                "4) remove packages" \
                "4.1) aur" \
                "4.2) explicit installed" \
                "4.3) without dependencies" \
                "5) change packages" \
                "5.1) aur" \
                "5.2) ala" \
                "6) config" \
                "6.1) aur" \
                "6.2) mirrorlist" \
                "6.3) diff packages" \
                "7) clear cache" \
        | fzf -e -i --cycle --preview "case {1} in
                7*)
                    printf \":: old packages\n\"
                    \"$auth\" paccache -dvk$pacman_cache_versions
                    printf \":: uninstalled packages\n\"
                    \"$auth\" paccache -dvuk0
                    printf \":: orphan packages\n\"
                    \"$aur_helper\" -Qdtq
                    ;;
                6.3*)
                    \"$auth\" pacdiff -f -o
                    ;;
                6.2*)
                    rankmirrors -n 0 -t \"$pacman_mirrors\"
                    printf \"\n%s\" \"$(cat "$pacman_mirrors")\"
                    ;;
                6.1*)
                    cat \"$aur_config\"
                    ;;
                6*)
                    cat \"$pacman_config\"
                    ;;
                5.2*)
                    \"$aur_helper\" -Qq
                    ;;
                5.1*)
                    printf \"%s\" \"$(pkg_files "$aur_cache")\"
                    ;;
                5*)
                    printf \"%s\" \"$(pkg_files "$pacman_cache")\"
                    ;;
                4.3*)
                    \"$aur_helper\" -Qqt
                    ;;
                4.2*)
                    \"$aur_helper\" -Qqe
                    ;;
                4.1*)
                    \"$aur_helper\" -Qmq
                    ;;
                4*)
                    \"$aur_helper\" -Qq
                    ;;
                3.2*)
                    \"$aur_helper\" -Slq --aur
                    ;;
                3.1*)
                    \"$aur_helper\" -Slq --repo
                    ;;
                3*)
                    \"$aur_helper\" -Slq
                    ;;
                2*)
                    checkupdates
                    \"$aur_helper\" -Qua
                    ;;
                1*)
                    grep \"$log_filter\" \"$pacman_log\" \
                        | grep \"$(log_last_action)\" \
                        | tac
                    ;;
            esac" \
                --preview-window "right:70%" \
    )

    # select executable
    case "$select" in
        7*)
            "$auth" paccache -rvk$pacman_cache_versions
            "$auth" paccache -rvuk0
            "$aur_helper" -c
            ;;
        6.3*)
            "$auth" pacdiff -f
            ;;
        6.2*)
            "$auth" "$edit" "$pacman_mirrors"
            ;;
        6.1*)
            "$edit" "$aur_config"
            ;;
        6*)
            "$auth" "$edit" "$pacman_config"
            ;;
        5.2*)
            ala_downgrade "$ala_url"
            exit_status
            ;;
        5.1*)
            pacman_downgrade "$aur_cache"
            exit_status
            ;;
        5*)
            pacman_downgrade "$pacman_cache"
            exit_status
            ;;
        4.3*)
            aur_execute "Qqt" "Qlii" "Rsn"
            exit_status
            ;;
        4.2*)
            aur_execute "Qqe" "Qlii" "Rsn"
            exit_status
            ;;
        4.1*)
            aur_execute "Qmq" "Qlii" "Rsn"
            exit_status
            ;;
        4*)
            aur_execute "Qq" "Qlii" "Rsn"
            exit_status
            ;;
        3.2*)
            aur_execute "Slq --aur" "Sii" "S"
            exit_status
            ;;
        3.1*)
            aur_execute "Slq --repo" "Sii" "S"
            exit_status
            ;;
        3*)
            aur_execute "Slq" "Sii" "S"
            exit_status
            ;;
        2*)
            "$aur_helper" -Syu
            exit_status
            ;;
        1*)
            tac "$pacman_log" | "$display"
            ;;
        *)
            pkg_lists_backup
            break
            ;;
    esac
done
