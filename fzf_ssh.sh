#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_ssh.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/dmenu
# date:   2023-04-25T11:49:09+0200

# config
ssh_config="$HOME/.ssh/config"
edit="$EDITOR"

#help
script=$(basename "$0")
help="$script [-h/--help] -- script to open configured ssh sessions
  Usage:
    $script

  Examples:
    $script"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit 0

while true; do
    # menu
    select=$(printf "%s\n" \
                "== edit config ==" \
                "$(grep "^Host " "$ssh_config" \
                    | cut -d ' ' -f2)" \
                | fzf -m -e -i --cycle --preview "case {1} in
                    \"==\"*)
                        cat \"$ssh_config\"
                        ;;
                    *)
                        sed -n '/^Host {1}$/,/^$/p' \"$ssh_config\"
                        ;;
                    esac" \
                    --preview-window "right:70%" \
    )

    # select executable
    case "$select" in
        "== edit config ==")
            "$edit" "$ssh_config"
            ;;
        *)
            session=$(printf "%s" "$select" | wc -w)

            for host in $select; do
                session=$((session-1))
                [ $session -ge 0 ] && [ -n "$DISPLAY" ] \
                    && $TERMINAL -T "ssh $host" -e ssh "$host"
                [ $session -eq 0 ] && [ -z "$DISPLAY" ] \
                    && ssh "$host"
            done
            break
            ;;
    esac
done
