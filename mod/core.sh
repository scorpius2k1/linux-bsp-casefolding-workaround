prompt() {
    local default_value="${1,,}"
    local default_response=$([[ -z "$default_value" ]] && echo "1" || { [[ "$default_value" == "n" ]] && echo "0" || echo "1"; })

    if ! read -r response; then
        echo "$default_response"
        return
    fi

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
    printf "%b" "${style_code}${color_code}${text}\033[0m"
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
        local start=$((total - depth))
        IFS=/; short="/${segments[*]:0:depth}/.../${segments[*]:start:depth}"
    else
        local start=$((total - depth))
        IFS=/; short=".../${segments[*]:start:depth}"
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
    [ "$IN_DOCKER" == "1" ] && color_msg "magenta" " 🐳 [CONTAINERIZED ENVIRONMENT]\n\n"
}

mk_dir() {
    local target="$1"
    [ -z "$target" ] && return 1
    [ -d "$target" ] && return 0
    
    if [ -e "$target" ] || [ -L "$target" ]; then
        color_msg "red" "Error: Cannot create directory '$target'. A file or symlink already exists at this path." "bold"
        exit 1
    fi
    
    mkdir -p -- "$target" || { 
        color_msg "red" "Error: Failed to create $target" "bold"; 
        exit 1; 
    }
    
    return 0
}

rm_dir() {
    local target="$1"
    [ -z "$target" ] && return 1

    local contents_only=false
    [[ "$target" == */ ]] && contents_only=true

    local clean_target="${target%/}"

    case "$clean_target" in
        ""|"/"|"/home"|"/root"|"/bin"|"/etc"|"/usr"|"/var"|"/boot"|"/dev")
            color_msg "red" "Error: Protection triggered for system path: $target" "bold"
            exit 1
            ;;
        *)
            [ ! -d "$clean_target" ] && return 0

            local target_dev parent_dev
            target_dev=$(stat -c %d "$clean_target" 2>/dev/null)
            parent_dev=$(stat -c %d "$(dirname "$clean_target")" 2>/dev/null)

            if [ "$target_dev" != "$parent_dev" ] && [ "$contents_only" = false ]; then
                color_msg "yellow" "Warning: $clean_target is a mount point. Switching to 'contents only' mode."
                contents_only=true
            fi

            if [ "$contents_only" = true ]; then
                find "$clean_target" -xdev -mindepth 1 -delete || { 
                    color_msg "red" "Error: Failed to clear $clean_target" "bold"; exit 1; 
                }
            else
                rm -rf -- "$clean_target" || { 
                    color_msg "red" "Error: Failed to remove $clean_target" "bold"; exit 1; 
                }
            fi
            ;;
    esac
    return 0
}

rm_file() {
    local target="$1"
    [ -z "$target" ] && return 1
    
    [ -d "$target" ] && [ ! -L "$target" ] && { 
        color_msg "red" "Error: '$target' is a directory, not a file." "bold"; 
        return 1; 
    }
    
    [ ! -e "$target" ] && [ ! -L "$target" ] && return 0
    
    rm -f -- "$target" || { 
        color_msg "red" "Error: Failed to remove file $target" "bold"; 
        exit 1; 
    }
    
    return 0
}