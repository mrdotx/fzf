#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_cpupower.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2023-04-26T08:31:21+0200

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
    info=$("$auth" cpupower frequency-info "$@")

    [ "$(printf "%s" "$info" | wc -l)" -lt 1 ] \
        && printf "Cannot determine or is not supported." \
        && return

    case "$1" in
        --stats)
            printf "%s" "$info" \
                | cut -d'(' -f1 \
                | tr ',' '\n' \
                | sed 's/:/: /g' \
                | awk 'NR>1 {$1=$1;print}'
            ;;
        --boost)
            printf "%s" "$info" \
                | awk 'NR>2 {$1=$1;print}'
            ;;
        --perf)
            printf "%s" "$info" \
                | awk 'NR>1 {$1=$1;print}' \
                | sed 's/AMD PSTATE //g'
            ;;
        *)
            printf "%s" "$info" \
                | cut -d':' -f2- \
                | awk 'NR>1 {$1=$1;print}'
            ;;
    esac
}

get_cpupower_info() {
    governor=$(cat "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor")

    printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n" \
        "== generic scaling governors ==" \
        "conservative   = current load (more gradually than ondemand)" \
        "ondemand       = scales cpu frequency according to current load" \
        "userspace      = user specified cpu frequency (scaling_setspeed)" \
        "powersave      = minimum cpu frequency (scaling_min_freq)" \
        "performance    = maximum cpu frequency (scaling_max_freq)" \
        "schedutil      = scheduler-driven cpu frequency" \
            | sed "s/$governor  /$(highlight_string "$governor")/"

    printf "== available governors ==\n%s\n\n" \
        "$(cpupower_wrapper --governors)" \
            | sed "s/$governor/$(highlight_string "$governor")/"

    printf "== currently used cpufreq policy ==\n%s\n\n" \
        "$(cpupower_wrapper --policy)" \
            | sed "s/\"$governor\"/$(highlight_string "$governor")/"

    printf "== maximum cpu frequency ==\n%s\n\n" \
        "$(cpupower_wrapper --hwlimits --human)"

    printf "== current cpu frequency ==\n%s\n\n" \
        "$(cpupower_wrapper --freq --human)"

    printf "== cpu frequency statistics ==\n%s\n\n" \
        "$(cpupower_wrapper --stats --human)"

    printf "== maximum latency on cpu frequency changes ==\n%s\n\n" \
        "$(cpupower_wrapper --latency --human)"

    printf "== boost state support ==\n%s\n\n" \
        "$(cpupower_wrapper --boost)"

    printf "== performances and frequencies capabilities of cppc ==\n%s\n\n" \
        "$(cpupower_wrapper --perf)"

    printf "== cpus run at the same hardware frequency ==\n%s\n\n" \
        "$(cpupower_wrapper --related-cpus)"

    printf "== cpus need to have their frequency coordinated by software ==\n%s\n\n" \
        "$(cpupower_wrapper --affected-cpus)"

    printf "== used cpu kernel driver ==\n%s\n\n" \
        "$(cpupower_wrapper --driver)"
}

set_governor() {
    [ -n "$1" ] \
        && "$auth" cpupower frequency-set --governor \
            "$(printf "%s" "$1" | cut -d' ' -f2)"
}

set_frequency() {
    printf "Frequencies can be passed in Hz, kHz, MHz, GHz, or THz.\n"
    printf "e.g. 1400MHz, leave blank to return to the menu without changes.\n"
    printf "\n\r%s to: " "$1" \
        && read -r frequency
    [ -n "$frequency" ] \
        && "$auth" cpupower frequency-set "$2" "$frequency"
}

exit_status() {
    printf "%s" \
        "The command exited with status $?. " \
        "Press ENTER to continue."
    read -r select
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
            "$(for value in $(cpupower_wrapper --governors); do
                printf "set %s\n" "$value"
            done)" \
            "set frequency" \
            "set min frequency" \
            "set max frequency" \
            "edit config" \
            "toggle service" \
        | fzf -e --cycle \
            --preview "case {1} in
                toggle*)
                    printf \"%s\" \"$($auth systemctl status $service)\"
                    ;;
                edit*)
                    cat \"$config\"
                    ;;
                set*)
                    printf \"%s\" \"$(get_cpupower_info)\"
                    ;;
                esac" \
            --preview-window "right:80%,wrap" \
    )

    # select executable
    case "$select" in
        set*max*frequency)
            set_frequency "$select" "-u" \
                || exit_status
            ;;
        set*min*frequency)
            set_frequency "$select" "-d" \
                || exit_status
            ;;
        set*frequency)
            set_frequency "$select" "-f" \
                || exit_status
            ;;
        set*)
            set_governor "$select" \
                || exit_status
            ;;
        edit*)
            "$auth" "$edit" "$config"
            ;;
        toggle*)
            toggle_cpupower_service
            ;;
        *)
            break
            ;;
    esac
done
