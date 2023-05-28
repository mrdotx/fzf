#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_ssh.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-05-27T11:52:25+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# config
ssh_config="$HOME/.ssh/config"
edit="$EDITOR"

# help
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
            "$(grep "^Host " "$ssh_config" \
                | cut -d ' ' -f2 \
            )" \
            "edit config" \
        | fzf -m -e --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%" \
            --preview "case {} in
                \"edit config\")
                    cat \"$ssh_config\"
                    ;;
                *)
                    sed -n '/^Host {}$/,/^$/p' \"$ssh_config\"
                    ;;
                esac" \
    )

    # select executable
    case "$select" in
        "edit config")
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
