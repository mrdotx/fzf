#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_virtualbox.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-05-23T21:26:52+0200

vboxmanage list vms \
    | cut -d '"' -f2 \
    | {
        while IFS= read -r vm; do
            printf "%s [gui]\n" "$vm"
            printf "%s [headless]\n" "$vm"
        done
    } \
    | fzf -m -e \
        --preview-window "up:75%:wrap" \
        --preview "vboxmanage showvminfo {..-2}" \
    | {
        while IFS= read -r vm; do
            case "$vm" in
                *"[headless]")
                    vm=$(printf "%s" "$vm" \
                        | sed "s/ \[headless\]$//")

                    vboxmanage startvm "$vm" --type headless >/dev/null 2>&1
                    ;;
                *"[gui]")
                    vm=$(printf "%s" "$vm" \
                        | sed "s/ \[gui\]$//")

                    vboxmanage startvm "$vm" --type gui >/dev/null 2>&1
                    ;;
            esac
        done
    }

