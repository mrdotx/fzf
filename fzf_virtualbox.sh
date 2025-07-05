#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_virtualbox.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2025-07-05T04:47:21+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to start virtualbox vm
  Usage:
    $script

  Examples:
    $script"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit

vboxmanage list vms \
    | grep -v '^"<inaccessible>"' \
    | cut -d '"' -f2 \
    | {
        while IFS= read -r vm; do
            printf "%s [gui]\n" "$vm"
            printf "%s [headless]\n" "$vm"
        done
    } \
    | fzf -m --query="[gui] " \
        --preview-window "up:75%:wrap" \
        --preview "vboxmanage showvminfo {..-2}" \
    | while IFS= read -r vm; do
        printf "starting %s, please wait..." "$vm"
        case "$vm" in
            *"[headless]")
                vm=$(printf "%s" "$vm" \
                    | sed "s/ \[headless\]$//" \
                )

                vboxmanage startvm "$vm" --type headless >/dev/null 2>&1
                ;;
            *"[gui]")
                vm=$(printf "%s" "$vm" \
                    | sed "s/ \[gui\]$//" \
                )

                vboxmanage startvm "$vm" --type gui >/dev/null 2>&1
                ;;
        esac
    done
