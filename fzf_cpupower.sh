#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_cpupower.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2025-06-17T05:42:49+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# auth can be something like sudo -A, doas -- or nothing,
# depending on configuration requirements
auth="${EXEC_AS_USER:-sudo}"

# config
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

# sysfs frequency boost file
boost_path="/sys/devices/system/cpu/cpufreq/boost"

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

    printf "[%b%s%b]" "$blue" "$@" "$reset"
}

write_sysfs_value() {
    printf "%s" "$1" \
        | "$auth" tee "$2" 1>/dev/null
}

exit_status() {
    printf "%s" \
        "The command exited with status $?. " \
        "Press ENTER to continue."
    read -r select
}

cpupower_wrapper() {
    info=$("$auth" cpupower frequency-info "$@")

    [ "$(printf "%s" "$info" | wc -l)" -lt 1 ] \
        && printf "Cannot determine or is not supported.\n" \
        && return

    case "$1" in
        --stats)
            printf "%s" "$info" \
                | cut -d'(' -f1 \
                | sed -e 's/, /\n/g' -e's/:/: /g' \
                | awk 'NR>1 {$1=$1;print}' \
                | column --separator ':' --output-separator ' =' --table
            ;;
        --boost)
            printf "%s" "$info" \
                | awk 'NR>2 {$1=$1;print}' \
                | column --separator ':' --output-separator ' =' --table
            ;;
        --perf)
            printf "%s" "$info" \
                | awk 'NR>2 && NR<7 {$1=$1;print}' \
                | sed -e 's/\. /: /g' -e 's/\.$//g' \
                    -e 's/\( Performance\| Frequency\)//g' \
                | column --separator ':' --output-separator ' |' --table \
                    --table-right 2,4 \
                    --table-columns 'Performance, Scale, Frequency, Hz'
            printf "\n» cppc preferred core capabilities\n"
            printf "%s" "$info" \
                | awk 'NR>6 {$1=$1;print}' \
                | sed -e 's/\. /\n/g' -e 's/\.$//g' \
                    -e 's/Preferred Core //g' \
                | column --separator ':' --output-separator ' =' --table
            ;;
        *)
            printf "%s" "$info" \
                | cut -d':' -f2- \
                | awk 'NR>1 {$1=$1;print}'
            ;;
    esac
}

get_governor_info() {
    highlight_governor=$(highlight_string "$governor")

    printf "» generic scaling governors\n"
    printf "%s\n" \
        "conservative: current load (more gradually than ondemand)" \
        "ondemand: scales cpu frequency according to current load" \
        "userspace: user specified cpu frequency (scaling_setspeed)" \
        "powersave: minimum cpu frequency (scaling_min_freq)" \
        "performance: maximum cpu frequency (scaling_max_freq)" \
        "schedutil: scheduler-driven cpu frequency" \
            | sed "0,/^\b$governor\b/s/^\b$governor\b/$highlight_governor/" \
            | column --separator ':' --output-separator ' =' --table

    printf "\n» available governors\n"
    cpupower_wrapper --governors \
        | tr ' ' '\n' \
        | sed "0,/^\b$governor\b/s/^\b$governor\b/$highlight_governor/"

    printf "\n» currently used cpufreq policy\n"
    cpupower_wrapper --policy \
        | sed "0,/\"\b$governor\b\"/s/\"\b$governor\b\"/$highlight_governor/"

    printf "\n» used cpu kernel driver\n"
    cpupower_wrapper --driver
}

get_epp_info() {
    [ -s "$epp_path" ] \
        && epp=$(cat "$epp_path") \
        && highlight_epp=$(highlight_string "$epp")

    printf "» generic energy performance preferences\n"
    printf "%s\n" \
        "default: balance between performance and energy efficiency" \
        "performance: maximum performance" \
        "balance_performance: higher priority on performance" \
        "balance_power: higher priority on energy efficiency" \
        "power: maximum energy efficiency" \
            | sed "0,/^\b$epp\b/s/^\b$epp\b/$highlight_epp/" \
            | column --separator ':' --output-separator ' =' --table

    printf "\n» available energy performance preferences\n"
    printf "%s\n" "$epp_available" \
        | tr ' ' '\n' \
        | sed "0,/^\b$epp\b/s/^\b$epp\b/$highlight_epp/"
}

get_pp_info() {
    [ -s "$pp_path" ] \
        && pp=$(cat "$pp_path") \
        && highlight_pp=$(highlight_string "$pp")

    printf "» generic platform profiles\n"
    printf "%s\n" \
        "low-power: low power consumption" \
        "cool: cooler operation" \
        "quiet: quieter operation" \
        "balanced: balance between low power consumption and performance" \
        "balanced-performance: balance between performance and low power consumption" \
        "performance: high performance operation" \
            | sed "0,/^\b$pp\b/s/^\b$pp\b/$highlight_pp/" \
            | column --separator ':' --output-separator ' =' --table

    printf "\n» available platform profiles\n"
    printf "%s\n" "$pp_available" \
        | tr ' ' '\n' \
        | sed "0,/^\b$pp\b/s/^\b$pp\b/$highlight_pp/"
}

get_threshold_info() {
    # https://www.ifixit.com/News/31716/how-to-care-for-your-laptops-battery-so-it-lasts-longer
    printf "» recommended battery charge thresholds\n"
    printf "%s\n" \
        "full capacity (on the road): thinkpad: 96: 100" \
        "balanced (capacity and lifespan): tlp: 75: 80" \
        "maximum lifespan (plugged in): : 40: 50" \
            | column --separator ':' --output-separator ' |' --table \
                --table-right 3,4 \
                --table-columns 'description, default, start, end'

    printf "\n» current battery charge thresholds\n"
    printf "start (charging below value) = %s\n" "$threshold_start_value"
    printf "end   (charging above value) = %s\n" "$threshold_end_value"
}

get_frequency_info() {
    printf "» maximum cpu frequency\n"
    cpupower_wrapper --hwlimits --human

    printf "\n» current cpu frequency\n"
    cpupower_wrapper --freq --human

    printf "\n» cpu frequency statistics\n"
    cpupower_wrapper --stats --human

    printf "\n» maximum latency on cpu frequency changes\n"
    cpupower_wrapper --latency --human

    printf "\n» cpus run at the same hardware frequency\n"
    cpupower_wrapper --related-cpus

    printf "\n» cpus need to have their frequency coordinated by software\n"
    cpupower_wrapper --affected-cpus

    printf "\n» cppc performance and frequency capabilities\n"
    cpupower_wrapper --perf
}

get_boost_info() {
    printf "» boost state support\n"
    cpupower_wrapper --boost
}

set_governor() {
    [ -n "$1" ] \
        && "$auth" cpupower frequency-set --governor \
            "$(printf "%s" "$1" | cut -d' ' -f3)" 1>/dev/null
}

set_epp() {
    [ -n "$1" ] \
        && "$auth" cpupower set --epp \
            "$(printf "%s" "$1" | cut -d' ' -f3)" 1>/dev/null
}

set_pp() {
    [ -n "$1" ] \
        && set_pp_value=$(printf "%s" "$1" | cut -d' ' -f3) \
        && write_sysfs_value "$set_pp_value" "$pp_path"
}

set_threshold() {
    [ -n "$1" ] \
        && set_threshold_value=$(printf "%s" "$1" | cut -d' ' -f4)

    [ -z "$set_threshold_value" ] \
        && printf "%s\n" \
            "Specify the start/end value in percent (e.g. 75/80)." \
            "Values below 40 percent are not recommended." \
            "Leave blank to avoid making changes." \
        && printf "\n\r%s from %s/%s to: " \
            "$1" "$threshold_start_value" "$threshold_end_value"\
        && read -r set_threshold_value

    set_threshold_start_value=$(printf "%s" "$set_threshold_value" \
        | cut -d'/' -f1)
    set_threshold_end_value=$(printf "%s" "$set_threshold_value" \
        | cut -d'/' -f2)

    [ -z "$set_threshold_start_value" ] \
        && set_threshold_start_value="$threshold_start_value"
    [ -z "$set_threshold_end_value" ] \
        && set_threshold_end_value="$threshold_end_value"

    if [ "$set_threshold_start_value" -gt "$threshold_end_value" ]; then
        write_sysfs_value "$set_threshold_end_value" "$threshold_end_path"
        write_sysfs_value "$set_threshold_start_value" "$threshold_start_path"
    else
        write_sysfs_value "$set_threshold_start_value" "$threshold_start_path"
        write_sysfs_value "$set_threshold_end_value" "$threshold_end_path"
    fi
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

toggle_boost() {
    [ "$boost" -eq 0 ] \
        && turbo_boost=1 \
        || turbo_boost=0
    "$auth" cpupower set --turbo-boost "$turbo_boost" 1>/dev/null
}

toggle_cpupower_service() {
    if "$auth" systemctl -q is-active "$service"; then
        "$auth" systemctl -q disable "$service" --now
    else
        "$auth" systemctl -q enable "$service" --now
    fi
}

get_menu_entries() {
    for entry in $(cpupower_wrapper --governors); do
        printf "set governor %s\n" "$entry"
    done
    for entry in $epp_available; do
        printf "set epp %s\n" "$entry"
    done
    for entry in $pp_available; do
        printf "set pp %s\n" "$entry"
    done
    [ -s "$threshold_start_path" ] \
        && printf "%s\n" \
            "set battery threshold 96/100" \
            "set battery threshold 75/80" \
            "set battery threshold 40/50" \
            "set battery threshold"
    printf "%s\n" \
        "set frequency min" \
        "set frequency max"
    [ "$governor" = 'userspace' ] \
        && printf "set frequency\n"
    [ -s "$boost_path" ] \
        && printf "toggle frequency boost\n"
    printf "toggle service\n"
    printf "edit config\n"
}

while true; do
    [ -s "$governor_path" ] \
        && governor=$(cat "$governor_path")
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
    [ -s $boost_path ] \
        && boost=$(cat "$boost_path")

    # menu
    select=$(get_menu_entries \
        | fzf --cycle \
            --bind 'focus:transform-preview-label:echo [ {} ]' \
            --preview-window "right:75%,wrap" \
            --preview "case {} in
                \"set governor\"*)
                    printf \"%s\" \"$(get_governor_info)\"
                    ;;
                \"set epp\"*)
                    printf \"%s\" \"$(get_epp_info)\"
                    ;;
                \"set pp\"*)
                    printf \"%s\" \"$(get_pp_info)\"
                    ;;
                \"set battery threshold\"*)
                    printf \"%s\" \"$(get_threshold_info)\"
                    ;;
                \"set frequency\"*)
                    printf \"%s\" \"$(get_frequency_info)\"
                    ;;
                \"toggle frequency boost\")
                    printf \"%s\" \"$(get_boost_info)\"
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
        "set battery threshold"*)
            set_threshold "$select" \
                || exit_status
            ;;
        "set frequency min")
            set_frequency "$select" "--min" \
                || exit_status
            ;;
        "set frequency max")
            set_frequency "$select" "--max" \
                || exit_status
            ;;
        "set frequency")
            set_frequency "$select" "--freq" \
                || exit_status
            ;;
        "toggle frequency boost")
            toggle_boost
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
