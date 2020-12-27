#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_pacman.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-12-27T16:04:55+0100

# config
auth="doas"
show="$PAGER"
edit="$EDITOR"
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
                " 1) install" \
                " 2) update" \
                " 3) remove" \
                " 4) remove [explicit installed]" \
                " 5) remove [without dependencies]" \
                " 6) remove [from aur]" \
                " 7) remove [orphan]" \
                " 8) mirrorlist [update]" \
                " 9) clean cache" \
                "10) show pacman.log" \
        | fzf -e -i --cycle --preview "case {1} in
                10*)
                    grep \".*\[ALPM\].*(.*)\" $pacman_log \
                        | grep \"$(grep ".*[ALPM].*(.*)" $pacman_log \
                            | tail -n1 \
                            | cut -b 2-11)\" \
                        | tac
                    ;;
                9*)
                    $auth paccache -dvk2
                    $auth paccache -dvuk0
                    ;;
                8*)
                    cat $pacman_mirrors
                    ;;
                7*)
                    $aur_helper -Qdt
                    ;;
                6*)
                    $aur_helper -Qmq
                    ;;
                5*)
                    $aur_helper -Qqt
                    ;;
                4*)
                    $aur_helper -Qqe
                    ;;
                3*)
                    $aur_helper -Qq
                    ;;
                2*)
                    checkupdates
                    $aur_helper -Qua
                    ;;
                1*)
                    $aur_helper -Slq
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
        " 1) install")
            execute "Slq" "Sii" "S"
            ;;
        " 2) update")
            $aur_helper -Syu --needed
            pause
            ;;
        " 3) remove")
            execute "Qq" "Qlii" "Rsn"
            ;;
        " 4) remove [explicit installed]")
            execute "Qqe" "Qlii" "Rsn"
            ;;
        " 5) remove [without dependencies]")
            execute "Qqt" "Qlii" "Rsn"
            ;;
        " 6) remove [from aur]")
            execute "Qmq" "Qlii" "Rsn"
            ;;
        " 7) remove [orphan]")
            execute "Qdt" "Qlii" "Rsn"
            ;;
        " 8) mirrorlist [update]")
            if command -v pacman-mirrors >/dev/null 2>&1; then
                $auth pacman-mirrors -c Germany -t 3 \
                    && $auth pacman -Syyu
                pause
            else
                $auth "$edit" $pacman_mirrors
            fi
            ;;
        " 9) clean cache")
            $auth paccache -rvk2
            $auth paccache -rvuk0
            ;;
        "10) show pacman.log")
            $show /var/log/pacman.log
            ;;
        *)
            break
            ;;
    esac
done
