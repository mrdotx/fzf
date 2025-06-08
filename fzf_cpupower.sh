#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_cpupower.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2025-06-08T05:32:17+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"
config="/etc/default/cpupower"
service="cpupower.service"
edit="$EDITOR"

# sysfs policy control files
policies_path="/sys/devices/system/cpu/cpufreq"
governor_path="$policies_path/policy0/scaling_governor"
epp_available_path="$policies_path/policy0/energy_performance_available_preferences"
epp_path="$policies_path/policy0/energy_performance_preference"

# sysfs platform profile files
pp_available_path="/sys/firmware/acpi/platform_profile_choices"
pp_path="/sys/firmware/acpi/platform_profile"

# sysfs battery threshold files
threshold_path="/sys/devices"
threshold_start="/power_supply/BAT0/charge_control_start_threshold"
threshold_end="/power_supply/BAT0/charge_control_end_threshold"

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
    # color variables
    reset="\033[0m"
    blue="\033[0;94m"

    printf "[%b%s%b]" "$blue" "$1" "$reset"
}

print_table() {
    cat \
        | column --separator ':' --output-separator "$1" --table
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
                | sed -e 's/, /\n/g' -e's/:/: /g' \
                | awk 'NR>1 {$1=$1;print}' \
                | print_table ' ='
            ;;
        --boost)
            printf "%s" "$info" \
                | awk 'NR>2 {$1=$1;print}' \
                | print_table ' ='
            ;;
        --perf)
            printf "%s" "$info" \
                | awk 'NR>1 {$1=$1;print}' \
                | sed -e 's/AMD PSTATE //g' -e 's/\. /\n/g' -e 's/Hz\./Hz/g' \
                | print_table ' ='
            ;;
        *)
            printf "%s" "$info" \
                | cut -d':' -f2- \
                | awk 'NR>1 {$1=$1;print}'
            ;;
    esac
}

get_governor_info() {
    governor=$(cat "$governor_path")

    printf "» generic scaling governors\n"
    printf "%s\n" \
        "conservative: current load (more gradually than ondemand)" \
        "ondemand: scales cpu frequency according to current load" \
        "userspace: user specified cpu frequency (scaling_setspeed)" \
        "powersave: minimum cpu frequency (scaling_min_freq)" \
        "performance: maximum cpu frequency (scaling_max_freq)" \
        "schedutil: scheduler-driven cpu frequency" \
            | sed "0,/^\b$governor\b/s/^\b$governor\b/$(highlight_string "$governor")/" \
            | print_table ' ='

    printf "\n» available governors\n"
    cpupower_wrapper --governors \
        | tr ' ' '\n' \
        | sed "0,/^\b$governor\b/s/^\b$governor\b/$(highlight_string "$governor")/"

    printf "\n» currently used cpufreq policy\n"
    cpupower_wrapper --policy \
        | sed "0,/\"\b$governor\b\"/s/\"\b$governor\b\"/$(highlight_string "$governor")/"
}

get_epp_info() {
    [ -s "$epp_path" ] \
        && epp=$(cat "$epp_path")

    printf "» generic energy performance preferences\n"
    printf "%s\n" \
        "default: balance between performance and energy efficiency" \
        "performance: maximum performance" \
        "balance_performance: higher priority on performance" \
        "balance_power: higher priority on energy efficiency" \
        "power: maximum energy efficiency" \
            | sed "0,/^\b$epp\b/s/^\b$epp\b/$(highlight_string "$epp")/" \
            | print_table ' ='

    printf "\n» available energy performance preferences\n"
    printf "%s\n" "$epp_available" \
        | tr ' ' '\n' \
        | sed "0,/^\b$epp\b/s/^\b$epp\b/$(highlight_string "$epp")/"
}

get_frequency_info() {
    printf "» current cpu frequency\n%s\n" \
        "$(cpupower_wrapper --freq --human)"

    printf "\n» maximum cpu frequency\n%s\n" \
        "$(cpupower_wrapper --hwlimits --human)"

    printf "\n» boost state support\n%s\n" \
        "$(cpupower_wrapper --boost)"

    printf "\n» cpu frequency statistics\n%s\n" \
        "$(cpupower_wrapper --stats --human)"

    printf "\n» cpus run at the same hardware frequency\n%s\n" \
        "$(cpupower_wrapper --related-cpus)"

    printf "\n» cpus need to have their frequency coordinated by software\n%s\n" \
        "$(cpupower_wrapper --affected-cpus)"

    printf "\n» maximum latency on cpu frequency changes\n%s\n" \
        "$(cpupower_wrapper --latency --human)"

    printf "\n» performance and frequency capabilities of cppc\n%s\n" \
        "$(cpupower_wrapper --perf)"

    printf "\n» used cpu kernel driver\n%s\n" \
        "$(cpupower_wrapper --driver)"
}

get_pp_info() {
    [ -s "$pp_path" ] \
        && pp=$(cat "$pp_path")

    printf "» generic platform profiles\n"
    printf "%s\n" \
        "low-power: low power consumption" \
        "cool: cooler operation" \
        "quiet: quieter operation" \
        "balanced: balance between low power consumption and performance" \
        "balanced-performance: balance between performance and low power consumption" \
        "performance: high performance operation" \
            | sed "0,/^\b$pp\b/s/^\b$pp\b/$(highlight_string "$pp")/" \
            | print_table ' ='

    printf "\n» available platform profiles\n"
    printf "%s\n" "$pp_available" \
        | tr ' ' '\n' \
        | sed "0,/^\b$pp\b/s/^\b$pp\b/$(highlight_string "$pp")/"
}

get_threshold_info() {
    # https://www.ifixit.com/News/31716/how-to-care-for-your-laptops-battery-so-it-lasts-longer
    printf "» recommended battery charge thresholds\n"
    printf "%s\n" \
        "description: application: start: end" \
        "maximum runtime (thinkpad default): on the road: 96: 100" \
        "minimum lifespan improvement: : 85: 90" \
        "medium lifespan improvement (tlp default): : 75: 80" \
        "maximum lifespan improvement: plugged in: 40: 50" \
            | print_table ' |'

    printf "\n» current battery charge thresholds\n"
    printf "start (charging below value) = %s\n" "$threshold_start_value"
    printf "end   (charging above value) = %s\n" "$threshold_end_value"
}

set_governor() {
    [ -n "$1" ] \
        && "$auth" cpupower frequency-set --governor \
            "$(printf "%s" "$1" | cut -d' ' -f3)" 1>/dev/null
}

set_epp() {
    [ -n "$1" ] \
        && for policy in $(find "$policies_path" -maxdepth 1 -type d | sed 1d); do
            printf "%s\n" "$1" \
                | cut -d' ' -f3 \
                | "$auth" tee "$policy/energy_performance_preference" 1>/dev/null
        done
}

set_frequency() {
    printf "%s\n" \
        "Frequencies can be passed in Hz, kHz, MHz, GHz, or THz (e.g. 1400MHz)." \
        "Leave blank to avoid making changes."
    printf "\n\r%s to: " "$1" \
        && read -r frequency
    [ -z "$frequency" ] \
        || "$auth" cpupower frequency-set "$2" "$frequency"
}

set_pp() {
    [ -n "$1" ] \
        && printf "%s\n" "$1" \
            | cut -d' ' -f3 \
            | "$auth" tee "$pp_path" 1>/dev/null
}

set_threshold() {
    printf "%s\n" \
        "Specify the value in percent (0-100). " \
        "Leave blank to avoid making changes."
    printf "\n\r%s start from %s to: " "$1" "$threshold_start_value" \
        && read -r threshold_start_value_new
    printf "\r%s end from %s to: " "$1" "$threshold_end_value" \
        && read -r threshold_end_value_new
    [ -z "$threshold_start_value_new" ] \
        || printf "%s\n" "$threshold_start_value_new" \
            | "$auth" tee "$threshold_start_path" 1>/dev/null
    [ -z "$threshold_end_value_new" ] \
        || printf "%s\n" "$threshold_end_value_new" \
            | "$auth" tee "$threshold_end_path" 1>/dev/null
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

get_menu_entries() {
    printf "%s\n" \
            "set frequency" \
            "set frequency min" \
            "set frequency max" \
            "$(for value in $(cpupower_wrapper --governors); do
                printf "set governor %s\n" "$value"
            done)" \
            "$(for value in $epp_available; do
                printf "set epp %s\n" "$value"
            done)" \
            "$(for value in $pp_available; do
                printf "set pp %s\n" "$value"
            done)" \
            "$([ -s "$threshold_start_path" ] \
                && printf "set battery threshold\n"
                )" \
            "toggle service" \
            "edit config" \
        | sed '/^$/d'
}

while true; do
    [ -s "$epp_available_path" ] \
        && epp_available=$(cat "$epp_available_path")
    [ -s "$pp_available_path" ] \
        && pp_available=$(cat "$pp_available_path")
    threshold_start_path=$(find "$threshold_path" -path "*$threshold_start")
    [ -s "$threshold_start_path" ] \
        && threshold_start_value=$(cat "$threshold_start_path")
    threshold_end_path=$(find "$threshold_path" -path "*$threshold_end")
    [ -s "$threshold_end_path" ] \
        && threshold_end_value=$(cat "$threshold_end_path")

    # menu
    select=$(get_menu_entries \
        | fzf --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%,wrap" \
            --preview "case {} in
                \"set frequency\"*)
                    printf \"%s\" \"$(get_frequency_info)\"
                    ;;
                \"set governor\"*)
                    printf \"%s\" \"$(get_governor_info)\"
                    ;;
                \"set epp\"*)
                    printf \"%s\" \"$(get_epp_info)\"
                    ;;
                \"set pp\"*)
                    printf \"%s\" \"$(get_pp_info)\"
                    ;;
                \"set battery threshold\")
                    printf \"%s\" \"$(get_threshold_info)\"
                    ;;
                \"toggle service\")
                    printf \"%s\" \"$($auth systemctl status $service)\"
                    ;;
                \"edit config\")
                    cat \"$config\"
                    ;;
                esac" \
    )

    # select executable
    case "$select" in
        "set frequency")
            set_frequency "$select" "-f" \
                || exit_status
            ;;
        "set frequency min")
            set_frequency "$select" "-d" \
                || exit_status
            ;;
        "set frequency max")
            set_frequency "$select" "-u" \
                || exit_status
            ;;
        "set governor"*)
            set_governor "$select" \
                || exit_status
            ;;
        "set epp"*)
            set_epp "$select" \
                || exit_status
            ;;
        "set pp"*)
            set_pp "$select" \
                || exit_status
            ;;
        "set battery threshold")
            set_threshold "$select" \
                || exit_status
            ;;
        "toggle service")
            toggle_cpupower_service
            ;;
        "edit config")
            "$auth" "$edit" "$config"
            ;;
        *)
            break
            ;;
    esac
done
