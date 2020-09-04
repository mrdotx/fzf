#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_yay.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/shell
# date:       2020-09-04T18:37:32+0200

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
select=$(printf "install packages\nremove installed packages\nremove explicit installed packages\nremove installed packages without dependencies\nremove installed packages from aur" \
    | fzf -e -i --cycle)

# yay package lists
execute() {
    search_options="$1"
    process_options="$2"
    yay -"$search_options" \
        | fzf -m -e -i --preview "cat <(yay -Si {1}) <(yay -Fl {1} \
            | awk \"{print \$2}\")" --preview-window "right:70%" \
        | xargs -ro yay -"$process_options"
}

# select executables
case "$select" in
    "install packages")
        execute "Slq" "S"
        ;;
    "remove installed packages")
        execute "Qq" "Rsn"
        ;;
    "remove explicit installed packages")
        execute "Qqe" "Rsn"
        ;;
    "remove installed packages without dependencies")
        execute "Qqt" "Rsn"
        ;;
    "remove installed packages from aur")
        execute "Qmq" "Rsn"
        ;;
    *)
        exit 0
        ;;
esac

# back to menu
fzf_yay.sh
