#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_aur.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-12-26T20:51:49+0100

# config
aur_helper="paru"
pacman_log="/var/log/pacman.log"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to manage packages with aur helper
  Usage:
    $script

  Examples:
    $script

  Config:
    aur_helper = $aur_helper
    pacman_log = $pacman_log"

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
                "3) remove" \
                "4) remove [explicit installed]" \
                "5) remove [without dependencies]" \
                "6) remove [from aur]" \
                "7) show pacman.log" \
        | fzf -e -i --cycle --preview "case {1} in
                1*)
                    $aur_helper -Slq
                    ;;
                2*)
                    checkupdates
                    $aur_helper -Qua
                    ;;
                3*)
                    $aur_helper -Qq
                    ;;
                4*)
                    $aur_helper -Qqe
                    ;;
                5*)
                    $aur_helper -Qqt
                    ;;
                6*)
                    $aur_helper -Qmq
                    ;;
                7*)
                    grep \"$(tail -n1 $pacman_log \
                        | cut -d'T' -f1 \
                        | tr -d '\[')\" $pacman_log \
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
        "3) remove")
            execute "Qq" "Qlii" "Rsn"
            ;;
        "4) remove [explicit installed]")
            execute "Qqe" "Qlii" "Rsn"
            ;;
        "5) remove [without dependencies]")
            execute "Qqt" "Qlii" "Rsn"
            ;;
        "6) remove [from aur]")
            execute "Qmq" "Qlii" "Rsn"
            ;;
        "7) show pacman.log")
            $PAGER /var/log/pacman.log
            ;;
        *)
            break
            ;;
    esac
done
