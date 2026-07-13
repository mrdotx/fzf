#!/bin/sh

# path:   /home/klassiker/Projects/repos/fzf/fzf_ssh.sh
# author: klassiker [mrdotx]
# url:    https://github.com/mrdotx/fzf
# date:   2026-07-13T03:37:21+0200

# config
ssh_config="$HOME/.ssh/config"
edit="$EDITOR"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to open configured ssh sessions
  Usage:
    $script [-e/--exec] <hostname> <command>

  Settings:
    without given settings, load ssh menu
    [-e/--exec] = execute command by hostname locally or remotely

  Examples:
    $script
    $script -e m625q wiki2web.sh
    $script --exec m625q wiki2web.sh"

case "$1" in
    -h | --help)
        printf "%s\n" "$help"
        ;;
    -e | --exec)
        remote_host="$2"
        shift 2

        case "$remote_host" in
            "$(uname -n)")
                "$@"
                ;;
            *)
                ssh -t "$remote_host" "$@"
                ;;
        esac
        ;;
    *)
        while true; do
            # menu
            select=$(printf "%s\n" \
                    "$(grep "^Host " "$ssh_config" \
                        | cut -d ' ' -f2 \
                    )" \
                    "edit config" \
                | fzf -m --cycle \
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
                    for host in $select; do
                        ssh "$host"
                    done
                    break
                    ;;
            esac
        done
        ;;
esac
