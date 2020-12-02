#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_aur.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-12-02T11:42:58+0100

script=$(basename "$0")
help="$script [-h/--help] -- script to install/remove packages from aur
  Usage:
    $script

  Examples:
    $script"

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
    | fzf -e -i --cycle --preview "grep \"$(tail -n1 /var/log/pacman.log \
        | cut -d'T' -f1 \
        | tr -d '\[')\" /var/log/pacman.log \
        | tac" --preview-window "right:70%" \
)

# packages
execute() {
    paru -"$1" \
        | fzf -m -e -i --preview "paru -$2 {1}" --preview-window "right:70%" \
        | xargs -ro paru -"$3"
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
    *)
        exit 0
        ;;
esac
