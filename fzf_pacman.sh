#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_pacman.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2021-04-29T13:09:37+0200

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="doas"

# config
aur_helper="paru"
pacman_log="/var/log/pacman.log"
pacman_cache="/var/cache/pacman/pkg"
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
    aur_helper     = $aur_helper
    pacman_log     = $pacman_log
    pacman_cache   = $pacman_cache
    pacman_config  = $pacman_config
    pacman_mirrors = $pacman_mirrors"

if [ "$1" = "-h" ] \
    || [ "$1" = "--help" ]; then
        printf "%s\n" "$help"
        exit 0
fi

# helper functions
log_filter=".*[ALPM].*(.*)"
log_last_action() {
    grep "$log_filter" $pacman_log \
        | tail -n1 \
        | cut -b 2-11
}

list_filenames() {
    find . -iname '*.*' \
        | sed 1d \
        | cut -b3- \
        | sort
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
        | xargs -ro $aur_helper -"$3"
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
                "4.4) orphan" \
                "5) downgrade packages" \
                "6) mirrorlist" \
                "7) clear cache" \
        | fzf -e -i --cycle --preview "case {1} in
                7*)
                    $auth paccache -dvk2
                    $auth paccache -dvuk0
                    ;;
                6*)
                    cat $pacman_mirrors
                    ;;
                5*)
                    printf \"%s\" \"$( \
                        cd $pacman_cache \
                            || exit
                        list_filenames \
                    )\"
                    ;;
                4.4*)
                    $aur_helper -Qdt
                    ;;
                4.3*)
                    $aur_helper -Qmq
                    ;;
                4.2*)
                    $aur_helper -Qqt
                    ;;
                4.1*)
                    $aur_helper -Qqe
                    ;;
                4*)
                    $aur_helper -Qq
                    ;;
                3.2*)
                    $aur_helper -Slq --aur
                    ;;
                3.1*)
                    $aur_helper -Slq --repo
                    ;;
                3*)
                    $aur_helper -Slq
                    ;;
                2*)
                    checkupdates
                    $aur_helper -Qua
                    ;;
                1*)
                    grep \"$log_filter\" $pacman_log \
                        | grep \"$(log_last_action)\" \
                        | tac
                    ;;
            esac" \
                --preview-window "right:70%" \
    )

    # select executable
    case "$select" in
        "1) view pacman.log")
            $PAGER $pacman_log
            ;;
        "2) update packages")
            $aur_helper -Syu --needed
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
        "4.4) orphan")
            execute "Qdt" "Qlii" "Rsn"
            pause
            ;;
        "5) downgrade packages")
            cd $pacman_cache \
                || exit
            list_filenames \
                | fzf -m -e -i --preview "cat $pacman_config" \
                    --preview-window "right:70%:wrap" \
                | xargs -ro $aur_helper -U
            pause
            ;;
        "6) mirrorlist")
            if command -v pacman-mirrors > /dev/null 2>&1; then
                $auth pacman-mirrors -c Germany \
                    && $auth pacman -Syyu
                pause
            else
                $auth "$EDITOR" $pacman_mirrors
            fi
            ;;
        "7) clear cache")
            $auth paccache -rvk2
            $auth paccache -rvuk0
            $aur_helper -c
            ;;
        *)
            break
            ;;
    esac
done
