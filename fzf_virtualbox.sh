#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_virtualbox.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-05-18T08:36:20+0200

vboxmanage list vms \
    | cut -d '"' -f2 \
    | fzf -m -e \
        --preview-window "up:75%:wrap" \
        --preview "vboxmanage showvminfo {}" \
    | {
        while IFS= read -r vm; do
            vboxmanage startvm "$vm" >/dev/null 2>&1
        done
    }
