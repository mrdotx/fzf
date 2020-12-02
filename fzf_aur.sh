#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_aur.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-12-02T10:50:53+0100

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
            "1) show pacman.log in pager" \
            "2) install packages" \
            "3) remove installed packages" \
            "4) remove explicit installed packages" \
            "5) remove installed packages without dependencies" \
            "6) remove installed packages from aur" \
    | fzf -e -i --cycle --preview "grep \"$(tail -n1 /var/log/pacman.log \
        | cut -d'T' -f1 \
        | tr -d '\[')\" /var/log/pacman.log \
        | tac" --preview-window "right:70%" \
)

# packages
execute() {
    search_options="$1"
    process_options="$2"
    paru -"$search_options" \
        | fzf -m -e -i --preview "paru -Si {1}" --preview-window "right:70%" \
        | xargs -ro paru -"$process_options"
}

# select executables
case "$select" in
    "1) show pacman.log in pager")
        $PAGER /var/log/pacman.log
        ;;
    "2) install packages")
        execute "Slq" "S"
        ;;
    "3) remove installed packages")
        execute "Qq" "Rsn"
        ;;
    "4) remove explicit installed packages")
        execute "Qqe" "Rsn"
        ;;
    "5) remove installed packages without dependencies")
        execute "Qqt" "Rsn"
        ;;
    "6) remove installed packages from aur")
        execute "Qmq" "Rsn"
        ;;
    *)
        exit 0
        ;;
esac
