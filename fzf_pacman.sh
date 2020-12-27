#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_pacman.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-12-27T12:44:08+0100

# config
auth="doas"
aur_helper="paru"
pacman_log="/var/log/pacman.log"
pacman_mirrors="/etc/pacman.d/mirrorlist"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to manage packages with aur helper
  Usage:
    $script

  Examples:
    $script

  Config:
    auth can be something like sudo -A, doas -- or nothing,
    depending on configuration requirements
    auth = $auth

    aur_helper = $aur_helper
    pacman_log = $pacman_log
    pacman_mirrors = $pacman_mirrors"

if [ "$1" = "-h" ] \
    || [ "$1" = "--help" ]; then
        printf "%s\n" "$help"
        exit 0
fi

while true; do
    # menu
    select=$(printf "%s\n" \
                "1) install" \
                "2) update" \
                "3) update [manjaro mirrorlist]" \
                "4) remove" \
                "5) remove [explicit installed]" \
                "6) remove [without dependencies]" \
                "7) remove [from aur]" \
                "8) show pacman.log" \
        | fzf -e -i --cycle --preview "case {1} in
                1*)
                    $aur_helper -Slq
                    ;;
                2*)
                    checkupdates
                    $aur_helper -Qua
                    ;;
                3*)
                    cat $pacman_mirrors
                    ;;
                4*)
                    $aur_helper -Qq
                    ;;
                5*)
                    $aur_helper -Qqe
                    ;;
                6*)
                    $aur_helper -Qqt
                    ;;
                7*)
                    $aur_helper -Qmq
                    ;;
                8*)
                    grep \".*\[ALPM\].*(.*)\" $pacman_log \
                        | grep \"$(grep ".*[ALPM].*(.*)" $pacman_log \
                            | tail -n1 \
                            | cut -b 2-11)\" \
                        | tac
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
        "1) install")
            execute "Slq" "Sii" "S"
            ;;
        "2) update")
            $aur_helper -Syu --needed
            pause
            ;;
        "3) update [manjaro mirrorlist]")
            $auth pacman-mirrors -c Germany -t 3 \
                && $auth pacman -Syyu
            pause
            ;;
        "4) remove")
            execute "Qq" "Qlii" "Rsn"
            ;;
        "5) remove [explicit installed]")
            execute "Qqe" "Qlii" "Rsn"
            ;;
        "6) remove [without dependencies]")
            execute "Qqt" "Qlii" "Rsn"
            ;;
        "7) remove [from aur]")
            execute "Qmq" "Qlii" "Rsn"
            ;;
        "8) show pacman.log")
            $PAGER /var/log/pacman.log
            ;;
        *)
            break
            ;;
    esac
done
