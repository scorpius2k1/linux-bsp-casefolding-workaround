prompt() {
    local default_value="${1,,}"
    local default_response=$([[ -z "$default_value" ]] && echo "1" || { [[ "$default_value" == "n" ]] && echo "0" || echo "1"; })

    read -p "" response
    case "${response,,}" in
        y) echo '1' ;;
        n) echo '0' ;;
        *) echo "$default_response" ;;
    esac
}

color_msg() {
    [ "${use_steam:-0}" -eq 1 ] && return 0
    local color="$1"
    local text="$2"
    local style="${3:-normal}"
    local style_code=""
    case "$style" in
        bold) style_code="\033[1m" ;;
        underline) style_code="\033[4m" ;;
    esac
    local color_code="${color_codes[$color]:-}"
    printf "$style_code$color_code$text\033[0m"
}

shorten_path() {
    local path="$1"
    local depth="${2:-5}"
    local direction="${3:-last}"

    path="${path#/}"
    path="${path%/}"

    IFS='/' read -r -a segments <<< "$path"
    local total=${#segments[@]}

    [ "$total" -eq 0 ] && { echo "/"; return; }

    if [ "$total" -le "$depth" ]; then
        IFS=/; echo "/${segments[*]}"
        return
    fi

    local short=""
    if [ "$direction" = "first" ]; then
        IFS=/; short="/${segments[*]:0:depth}/..."
    elif [ "$direction" = "both" ]; then
        if [ "$total" -le $((depth * 2)) ]; then
            IFS=/; echo "/${segments[*]}"
            return
        fi
        IFS=/; short="/${segments[*]:0:depth}/.../${segments[*]: -$depth}"
    else
        IFS=/; short=".../${segments[*]: -$depth}"
    fi

    echo "$short"
}

process_time() {
    local input="$1"
    local time_string=""
    
    [[ "$input" == "start" ]] && { start_time=$(date +%s); return 0; }
    [[ -z "$start_time" || $start_time -le 0 ]] && return 1

    local -i end_time=$(date +%s)
    local -i total_seconds=$((end_time - start_time))
    
    [[ $total_seconds -lt 0 ]] && return 1

    local -i hours=$((total_seconds / 3600))
    local -i minutes=$(((total_seconds % 3600) / 60))
    local -i seconds=$((total_seconds % 60))

    [ $hours -gt 0 ] && time_string="${hours}h "
    [ $minutes -gt 0 ] && time_string+="${minutes}m "
    time_string+="${seconds}s"

    echo "$time_string"
}

show_logo() {
    [ -z "$1" ] && { [ "$use_service" = 1 ] || [ "$use_steam" = 1 ]; } && return
    clear
    color_msg "bcyan" "$logo\n\n" "bold"
    color_msg "bcyan" ":: Linux BSP Case Folding Workaround ::\n"
    color_msg "bcyan" "=======================================\n\n"
}

rm_dir() {
    [ ! -d "$1" ] && return 0
    if [[ "$1" == */ ]]; then
        rm -rf "$1"/* || { color_msg "red" "Error: Failed to remove contents of $1" "bold"; exit 1; }
    else
        rm -rf "$1" || { color_msg "red" "Error: Failed to remove $1" "bold"; exit 1; }
    fi
    return 0
}

rm_file() {
    [ ! -f "$1" ] && return 0
    rm -f "$1" || { color_msg "red" "Error: Failed to remove file $1" "bold"; exit 1; }
    return 0
}

mk_dir() {
    mkdir -p "$1" || { color_msg "red" "Error: Failed to create $1\n" "bold"; exit 1; }
    return 0
}