#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_pacman.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-12-28T13:35:49+0100

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="doas"

# config
aur_helper="paru"
pacman_log="/var/log/pacman.log"
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
    pacman_mirrors = $pacman_mirrors"

if [ "$1" = "-h" ] \
    || [ "$1" = "--help" ]; then
        printf "%s\n" "$help"
        exit 0
fi

while true; do
    # menu
    select=$(printf "%s\n" \
                "1) update packages" \
                "2) install packages" \
                "3) remove packages" \
                "3.1) explicit installed" \
                "3.2) without dependencies" \
                "3.3) from aur" \
                "3.4) orphan" \
                "4) mirrorlist" \
                "5) clean cache" \
                "6) view pacman.log" \
        | fzf -e -i --cycle --preview "case {1} in
                6*)
                    grep \".*\[ALPM\].*(.*)\" $pacman_log \
                        | grep \"$(grep ".*[ALPM].*(.*)" $pacman_log \
                            | tail -n1 \
                            | cut -b 2-11)\" \
                        | tac
                    ;;
                5*)
                    $auth paccache -dvk2
                    $auth paccache -dvuk0
                    ;;
                4*)
                    cat $pacman_mirrors
                    ;;
                3.4*)
                    $aur_helper -Qdt
                    ;;
                3.3*)
                    $aur_helper -Qmq
                    ;;
                3.2*)
                    $aur_helper -Qqt
                    ;;
                3.1*)
                    $aur_helper -Qqe
                    ;;
                3*)
                    $aur_helper -Qq
                    ;;
                2*)
                    $aur_helper -Slq
                    ;;
                1*)
                    checkupdates
                    $aur_helper -Qua
                    ;;
            esac" \
                --preview-window "right:70%" \
    )

    # wait for keypress
    pause() {
        printf "%s" "Press ENTER to continue"
        read -r "select"
    }

    # execute aur helper
    execute() {
        $aur_helper -"$1" \
            | fzf -m -e -i --preview "$aur_helper -$2 {1}" \
                --preview-window "right:70%:wrap" \
            | xargs -ro $aur_helper -"$3"
        pause
    }

    # select executable
    case "$select" in
        "1) update packages")
            $aur_helper -Syu --needed
            pause
            ;;
        "2) install packages")
            execute "Slq" "Sii" "S"
            ;;
        "3) remove packages")
            execute "Qq" "Qlii" "Rsn"
            ;;
        "3.1) explicit installed")
            execute "Qqe" "Qlii" "Rsn"
            ;;
        "3.2) without dependencies")
            execute "Qqt" "Qlii" "Rsn"
            ;;
        "3.3) from aur")
            execute "Qmq" "Qlii" "Rsn"
            ;;
        "3.4) orphan")
            execute "Qdt" "Qlii" "Rsn"
            ;;
        "4) mirrorlist")
            if command -v pacman-mirrors > /dev/null 2>&1; then
                $auth pacman-mirrors -c Germany -t 3 \
                    && $auth pacman -Syyu
                pause
            else
                $auth "$EDITOR" $pacman_mirrors
            fi
            ;;
        "5) clean cache")
            $auth paccache -rvk2
            $auth paccache -rvuk0
            ;;
        "6) view pacman.log")
            $PAGER /var/log/pacman.log
            ;;
        *)
            break
            ;;
    esac
done
