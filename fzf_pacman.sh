#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_pacman.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2021-06-24T06:35:30+0200

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="$EXEC_AS_USER"

# config
display="$PAGER"
edit="$EDITOR"
aur_helper="paru"
aur_cache="$HOME/.cache/paru/clone"
aur_config="$HOME/.config/paru/paru.conf"
aur_backup="$HOME/.config/paru"
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
    pacman_log            = $pacman_log
    pacman_cache          = $pacman_cache
    pacman_cache_versions = $pacman_cache_versions
    pacman_config         = $pacman_config
    pacman_mirrors        = $pacman_mirrors"

if [ "$1" = "-h" ] \
    || [ "$1" = "--help" ]; then
        printf "%s\n" "$help"
        exit 0
fi

# helper functions
log_filter=".*\[ALPM\].*(.*)"
log_last_action() {
    grep "$log_filter" "$pacman_log" \
        | tail -n1 \
        | cut -b 2-11
}

list_pkg_files() {
    find . -iname '*.pkg.tar.*' \
        | sed 1d \
        | cut -b3- \
        | sort
}

downgrade_preview() {
    cd "$1" \
        || exit
    list_pkg_files
}

downgrade() {
    cd "$1" \
        || exit
    list_pkg_files \
        | fzf -m -e -i --preview "printf '%s' $1/{1}" \
            --preview-window "right:70%:wrap" \
        | xargs -ro "$auth" pacman -U
}

pause() {
    printf "%s" "The command exited with status $?. "
    printf "%s" "Press ENTER to continue."
    read -r "select"
}

execute() {
    eval "$aur_helper -$1" \
        | fzf -m -e -i --preview "$aur_helper -$2 {1}" \
            --preview-window "right:70%:wrap" \
        | xargs -ro "$aur_helper" -"$3"
}

while true; do
    # menu
    select=$(printf "%s\n" \
                "1) view pacman.log" \
                "2) update packages" \
                "3) install packages" \
                "3.1) from pacman" \
                "3.2) from aur" \
                "4) remove packages" \
                "4.1) explicit installed" \
                "4.2) without dependencies" \
                "4.3) from aur" \
                "5) downgrade packages" \
                "5.1) from aur" \
                "6) mirrorlist" \
                "7) pacman config" \
                "8) aur config" \
                "9) clear cache" \
        | fzf -e -i --cycle --preview "case {1} in
                9*)
                    printf \":: old packages\n\"
                    \"$auth\" paccache -dvk$pacman_cache_versions
                    printf \":: uninstalled packages\n\"
                    \"$auth\" paccache -dvuk0
                    printf \":: orphan packages\n\"
                    \"$aur_helper\" -Qdtq
                    ;;
                8*)
                    < \"$aur_config\"
                    ;;
                7*)
                    < \"$pacman_config\"
                    ;;
                6*)
                    < \"$pacman_mirrors\"
                    ;;
                5.1*)
                    printf \"%s\" \"$(downgrade_preview "$aur_cache")\"
                    ;;
                5*)
                    printf \"%s\" \"$(downgrade_preview "$pacman_cache")\"
                    ;;
                4.3*)
                    \"$aur_helper\" -Qmq
                    ;;
                4.2*)
                    \"$aur_helper\" -Qqt
                    ;;
                4.1*)
                    \"$aur_helper\" -Qqe
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
            "$aur_helper" -Syu --needed
            pause
            ;;
        "3) install packages")
            execute "Slq" "Sii" "S"
            pause
            ;;
        "3.1) from pacman")
            execute "Slq --repo" "Sii" "S"
            pause
            ;;
        "3.2) from aur")
            execute "Slq --aur" "Sii" "S"
            pause
            ;;
        "4) remove packages")
            execute "Qq" "Qlii" "Rsn"
            pause
            ;;
        "4.1) explicit installed")
            execute "Qqe" "Qlii" "Rsn"
            pause
            ;;
        "4.2) without dependencies")
            execute "Qqt" "Qlii" "Rsn"
            pause
            ;;
        "4.3) from aur")
            execute "Qmq" "Qlii" "Rsn"
            pause
            ;;
        "5) downgrade packages")
            downgrade "$pacman_cache"
            pause
            ;;
        "5.1) from aur")
            downgrade "$aur_cache"
            pause
            ;;
        "6) mirrorlist")
            if command -v pacman-mirrors > /dev/null 2>&1; then
                "$auth" pacman-mirrors -c Germany \
                    && "$auth" pacman -Syyu
                pause
            else
                "$auth" "$edit" "$pacman_mirrors"
            fi
            ;;
        "7) pacman config")
            "$auth" "$edit" "$pacman_config"
            ;;
        "8) aur config")
            "$edit" "$aur_config"
            ;;
        "9) clear cache")
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
