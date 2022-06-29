#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_cpupower.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-06-29T18:48:14+0200

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
cpupower_wrapper() {
    printf "%s\n" "$("$auth" cpupower frequency-info "$@")" \
        | cut -d':' -f2- \
        | awk 'NR>1 {$1=$1;print}'
}

get_active_governor() {
    governor=$(cat "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor")

    printf "%s\n" "$1" \
        | sed "s/$governor/[$governor]/"

    printf "\n%s" \
        "conservative = cpu load (avoid change cpu frequency over short time)" \
        "ondemand     = cpu load (change cpu frequency over short time)" \
        "userspace    = manual defined cpu frequency (scaling_setspeed)" \
        "powersave    = lowest frequency (scaling_min_freq)" \
        "performance  = highest frequency (scaling_max_freq)" \
        "schedutil    = cpu utilization data available (cpu scheduler)"
}

get_cpupower_info() {
    printf "== used cpu kernel driver ==\n%s\n\n" \
        "$(cpupower_wrapper --driver)"

    printf "== cpus run at the same hardware frequency ==\n%s\n\n" \
        "$(cpupower_wrapper --related-cpus)"

    printf "== cpus need to have their frequency coordinated by software ==\n%s\n\n" \
        "$(cpupower_wrapper --affected-cpus)"

    printf "== maximum cpu frequency ==\n%s\n\n" \
        "$(cpupower_wrapper --hwlimits --human)"

    printf "== maximum latency on cpu frequency changes ==\n%s\n\n" \
        "$(cpupower_wrapper --latency --human)"

    printf "== current cpu frequency ==\n%s\n\n" \
        "$(cpupower_wrapper --freq --human)"

    printf "== currently used cpufreq policy ==\n%s\n\n" \
        "$(cpupower_wrapper --policy)"

    printf "== available governors ==\n"
    get_active_governor "$(cpupower_wrapper --governors)"
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
