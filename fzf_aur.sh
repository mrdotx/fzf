#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_aur.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-12-23T15:36:28+0100

# config
aur_helper="paru"
pacman_log="/var/log/pacman.log"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to install/remove/update packages with aur helper
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

# menu
select=$(printf "%s\n" \
            "1) install packages" \
            "2) remove installed packages" \
            "3) remove explicit installed packages" \
            "4) remove installed packages without dependencies" \
            "5) remove installed packages from aur" \
            "6) show pacman.log in pager" \
            "7) update packages" \
    | fzf -e -i --cycle --preview "case {1} in
            7*)
                checkupdates
                $aur_helper -Qua
                ;;
            6*)
                grep \"$(tail -n1 $pacman_log \
                    | cut -d'T' -f1 \
                    | tr -d '\[')\" $pacman_log \
                    | tac
                ;;
            5*)
                $aur_helper -Qmq
                ;;
            4*)
                $aur_helper -Qqt
                ;;
            3*)
                $aur_helper -Qqe
                ;;
            2*)
                $aur_helper -Qq
                ;;
        esac" --preview-window "right:70%" \
)

# packages
execute() {
    $aur_helper -"$1" \
        | fzf -m -e -i --preview "$aur_helper -$2 {1}" --preview-window "right:70%" \
        | xargs -ro $aur_helper -"$3"
}

# select executables
case "$select" in
    "1) install packages")
        execute "Slq" "Sii" "S"
        ;;
    "2) remove installed packages")
        execute "Qq" "Qlii" "Rsn"
        ;;
    "3) remove explicit installed packages")
        execute "Qqe" "Qlii" "Rsn"
        ;;
    "4) remove installed packages without dependencies")
        execute "Qqt" "Qlii" "Rsn"
        ;;
    "5) remove installed packages from aur")
        execute "Qmq" "Qlii" "Rsn"
        ;;
    "6) show pacman.log in pager")
        $PAGER /var/log/pacman.log
        ;;
    "7) update packages")
        $aur_helper -Syu --needed
        ;;
    *)
        exit 0
        ;;
esac
