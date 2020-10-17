#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_yay.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/fzf
# date:       2020-10-17T11:27:48+0200

script=$(basename "$0")
help="$script [-h/--help] -- script to install/remove packages with yay
  Usage:
    $script

  Examples:
    $script"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
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
    | fzf -e -i --cycle \
)

# yay package lists
execute() {
    search_options="$1"
    process_options="$2"
    yay -"$search_options" \
        | fzf -m -e -i --preview "yay -Si {1}" --preview-window "right:70%" \
        | xargs -ro yay -"$process_options"
}

# select executables
case "$select" in
    "1) install packages")
        execute "Slq" "S"
        ;;
    "2) remove installed packages")
        execute "Qq" "Rsn"
        ;;
    "3) remove explicit installed packages")
        execute "Qqe" "Rsn"
        ;;
    "4) remove installed packages without dependencies")
        execute "Qqt" "Rsn"
        ;;
    "5) remove installed packages from aur")
        execute "Qmq" "Rsn"
        ;;
    *)
        exit 0
        ;;
esac
