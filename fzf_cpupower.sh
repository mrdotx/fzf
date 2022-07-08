#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_cpupower.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-07-08T23:18:11+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"
config="/etc/default/cpupower"
service="cpupower.service"
edit="$EDITOR"

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to manage cpupower
  Usage:
    $script

  Examples:
    $script

  Config:
    config  = $config
    service = $service
    edit    = $edit"

[ -n "$1" ] \
    && printf "%s\n" "$help" \
    && exit 0

# helper functions
highlight_string() {
    [ -z "$NO_COLOR" ] \
        && color="\x1b[0;33m" \
        && reset="\x1b[0m"

    printf "[%s%s%s]" "$color" "$1" "$reset"
}

cpupower_wrapper() {
    case "$1" in
        --stats)
            printf "%s" "$("$auth" cpupower frequency-info "$@")" \
                | cut -d'(' -f1 \
                | tr ',' '\n' \
                | sed 's/:/: /g' \
                | awk 'NR>1 {$1=$1;print}'
            ;;
        --boost)
            printf "%s" "$("$auth" cpupower frequency-info "$@")" \
                | awk 'NR>2 {$1=$1;print}'
            ;;
        *)
            printf "%s" "$("$auth" cpupower frequency-info "$@")" \
                | cut -d':' -f2- \
                | awk 'NR>1 {$1=$1;print}'
            ;;
    esac
}

get_cpupower_info() {
    governor=$(cat "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor")

    printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n" \
        "== generic scaling governors ==" \
        "conservative   = cpu load (avoid change cpu frequency over short time)" \
        "ondemand       = cpu load (change cpu frequency over short time)" \
        "userspace      = manual defined cpu frequency (scaling_setspeed)" \
        "powersave      = lowest frequency (scaling_min_freq)" \
        "performance    = highest frequency (scaling_max_freq)" \
        "schedutil      = cpu utilization data available (cpu scheduler)" \
            | sed "s/$governor  /$(highlight_string "$governor")/"

    printf "== available governors ==\n%s\n\n" \
        "$(cpupower_wrapper --governors)" \
            | sed "s/$governor/$(highlight_string "$governor")/"

    printf "== currently used cpufreq policy ==\n%s\n\n" \
        "$(cpupower_wrapper --policy)" \
            | sed "s/\"$governor\"/$(highlight_string "$governor")/"

    printf "== maximum cpu frequency ==\n%s\n\n" \
        "$(cpupower_wrapper --hwlimits --human)"

    printf "== boost state support ==\n%s\n\n" \
        "$(cpupower_wrapper --boost)"

    printf "== current cpu frequency ==\n%s\n\n" \
        "$(cpupower_wrapper --freq --human)"

    printf "== cpu frequency statistics ==\n%s\n\n" \
        "$(cpupower_wrapper --stats --human)"

    printf "== maximum latency on cpu frequency changes ==\n%s\n\n" \
        "$(cpupower_wrapper --latency --human)"

    printf "== used cpu kernel driver ==\n%s\n\n" \
        "$(cpupower_wrapper --driver)"

    printf "== cpus run at the same hardware frequency ==\n%s\n\n" \
        "$(cpupower_wrapper --related-cpus)"

    printf "== cpus need to have their frequency coordinated by software ==\n%s\n\n" \
        "$(cpupower_wrapper --affected-cpus)"
}

set_governor() {
    select=$(for value in $(cpupower_wrapper --governors); do
                printf "%s\n" "$value"
            done \
                | fzf -e -i --cycle \
                    --preview "printf \"%s\" \"$(get_cpupower_info)\"" \
                    --preview-window "right:75%")

    [ -n "$select" ] \
        && select="$auth cpupower frequency-set --governor $select" \
        && $select
}

pause() {
    ! [ $? -ge 1 ] \
        && printf "%s" \
            "The command exited with status $?. " \
            "Press ENTER to continue." \
        && read -r select
}

toggle_cpupower_service() {
    if "$auth" systemctl -q is-active "$service"; then
        "$auth" systemctl -q disable "$service" --now
    else
        "$auth" systemctl -q enable "$service" --now
    fi
}

while true; do
    # menu
    select=$(printf "%s\n" \
                "1) set governor" \
                "2) edit config" \
                "3) toggle service" \
        | fzf -e -i --cycle --preview "case {1} in
                3*)
                    printf \"%s\" \"$($auth systemctl status $service)\"
                    ;;
                2*)
                    cat \"$config\"
                    ;;
                1*)
                    printf \"%s\" \"$(get_cpupower_info)\"
                    ;;
            esac" \
                --preview-window "right:75%" \
    )

    # select executable
    case "$select" in
        3*)
            toggle_cpupower_service
            ;;
        2*)
            "$auth" "$edit" "$config"
            ;;
        1*)
            set_governor \
                || pause
            ;;
        *)
            break
            ;;
    esac
done
