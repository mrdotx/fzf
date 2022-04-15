#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_pacman.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-04-14T21:16:38+0200

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"

# config
display="$PAGER"
edit="$EDITOR"
aur_helper="paru"
aur_cache="$HOME/.cache/paru/clone"
aur_config="$HOME/.config/paru/paru.conf"
aur_backup="$HOME/.config/paru"
ala_url="https://archive.archlinux.org/packages"
pacman_log="/var/log/pacman.log"
pacman_cache="/var/cache/pacman/pkg"
pacman_cache_versions=2
pacman_config="/etc/pacman.conf"
pacman_mirrors="/etc/pacman.d/mirrorlist"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to manage packages with pacman and aur helper
  Usage:
    $script

  Examples:
    $script

  Config:
    display               = $display
    edit                  = $edit
    aur_helper            = $aur_helper
    aur_cache             = $aur_cache
    aur_config            = $aur_config
    aur_backup            = $aur_backup
    ala_url               = $ala_url
    pacman_log            = $pacman_log
    pacman_cache          = $pacman_cache
    pacman_cache_versions = $pacman_cache_versions
    pacman_config         = $pacman_config
    pacman_mirrors        = $pacman_mirrors"

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
    [ -z "$ala_pkg" ] \
        && return

    url=$(printf "%s/%s/%s/\n" \
        "$1" \
        "${ala_pkg%"${ala_pkg#?}"}" \
        "$ala_pkg" \
    )

    select=$(ala_files "$url" "$ala_pkg" \
        | fzf -e -i)
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
    [ -n "$select" ] \
        && select="$aur_helper -$3 $select" \
        && $select
}

pause() {
    printf "%s" "The command exited with status $?. "
    printf "%s" "Press ENTER to continue."
    read -r "select"
}

while true; do
    # menu
    select=$(printf "%s\n" \
                "1) view pacman.log" \
                "2) update packages" \
                "3) install packages" \
                "3.1) pacman" \
                "3.2) aur" \
                "4) remove packages" \
                "4.1) aur" \
                "4.2) explicit installed" \
                "4.3) without dependencies" \
                "5) downgrade packages" \
                "5.1) aur" \
                "5.2) ala" \
                "6) config" \
                "6.1) aur" \
                "6.2) mirrorlist" \
                "6.3) packages diff" \
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
        "1) view pacman.log")
            tac "$pacman_log" | "$display"
            ;;
        "2) update packages")
            "$aur_helper" -Syu
            pause
            ;;
        "3) install packages")
            aur_execute "Slq" "Sii" "S"
            pause
            ;;
        "3.1) pacman")
            aur_execute "Slq --repo" "Sii" "S"
            pause
            ;;
        "3.2) aur")
            aur_execute "Slq --aur" "Sii" "S"
            pause
            ;;
        "4) remove packages")
            aur_execute "Qq" "Qlii" "Rsn"
            pause
            ;;
        "4.1) aur")
            aur_execute "Qmq" "Qlii" "Rsn"
            pause
            ;;
        "4.2) explicit installed")
            aur_execute "Qqe" "Qlii" "Rsn"
            pause
            ;;
        "4.3) without dependencies")
            aur_execute "Qqt" "Qlii" "Rsn"
            pause
            ;;
        "5) downgrade packages")
            pacman_downgrade "$pacman_cache"
            pause
            ;;
        "5.1) aur")
            pacman_downgrade "$aur_cache"
            pause
            ;;
        "5.2) ala")
            ala_downgrade "$ala_url"
            pause
            ;;
        "6) config")
            "$auth" "$edit" "$pacman_config"
            ;;
        "6.1) aur")
            "$edit" "$aur_config"
            ;;
        "6.2) mirrorlist")
            "$auth" "$edit" "$pacman_mirrors"
            ;;
        "6.3) packages diff")
            "$auth" pacdiff -f
            ;;
        "7) clear cache")
            "$auth" paccache -rvk$pacman_cache_versions
            "$auth" paccache -rvuk0
            "$aur_helper" -c
            ;;
        *)
            # create backup lists to reinstall packages
            # to reinstall the packages:
            # "aur_helper" -S --needed - < "$aur_backup/explicit_installed_packages.txt"
            "$aur_helper" -Qq > "$aur_backup/installed_packages.txt"
            "$aur_helper" -Qqe > "$aur_backup/explicit_installed_packages.txt"

            break
            ;;
    esac
done
