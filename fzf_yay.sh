#!/bin/sh

# path:       /home/klassiker/.local/share/repos/fzf/fzf_yay.sh
# author:     klassiker [mrdotx]
# github:     https://github.com/mrdotx/shell
# date:       2020-08-06T08:26:01+0200

script=$(basename "$0")
help="$script [-h/--help] -- script to install or remove packages with yay
  Usage:
    $script [-s/-r/-e/-d/-a]

  Settings:
    [-s] = install packages from pacman or aur
    [-r] = remove installed packages from pacman or aur
    [-e] = remove explicit installed packages from pacman or aur
    [-d] = remove installed packages without dependencies from pacman or aur
    [-a] = remove installed packages from aur

  Examples:
    $script -s
    $script -r
    $script -e
    $script -d
    $script -a"

execute() {
    search_options="$1"
    process_options="$2"
    yay -"$search_options" \
        | fzf -m -e -i --preview "cat <(yay -Si {1}) <(yay -Fl {1} \
            | awk \"{print \$2}\")" --preview-window "right:70%" \
        | xargs -ro yay -"$process_options"
}

case "$1" in
    -s)
        execute "Slq" "S"
        ;;
    -r)
        execute "Qq" "Rsn"
        ;;
    -e)
        execute "Qqe" "Rsn"
        ;;
    -a)
        execute "Qmq" "Rsn"
        ;;
    -d)
        execute "Qqt" "Rsn"
        ;;
    *)
        printf "%s\n" "$help"
        exit 0
        ;;
esac
