checkconfig() {
    local cfg_check=${1:-0}
    local cfg_path="$path_cfg"
    local -a cfg_files=()
    local -A cfg_game_names=()

    [ ! -d "$cfg_path" ] && { echo 0; return 1; }

    for file in "$cfg_path"/*; do
        [ -f "$file" ] || continue
        filename="${file##*/}"
        eval "$(parse_config "${cfg_path}/${filename}")"
        cfg_game_names["$filename"]="${cfg_values[0]}"
        cfg_files+=("$filename")
    done
    
    [ "$cfg_check" -eq 1 ] && { echo ${#cfg_files[@]}; return 0; }
    [ ${#cfg_files[@]} -eq 0 ] && return 1

    local -a sorted_cfg_files=()
    local -a manual_configs=()
    for cfg in "${cfg_files[@]}"; do
        [ "${cfg_game_names[$cfg]}" = "Manual" ] && manual_configs+=("$cfg") || sorted_cfg_files+=("$cfg")
    done
    sorted_cfg_files+=("${manual_configs[@]}")

    color_msg "white" "Available Configs\n"
    for i in "${!sorted_cfg_files[@]}"; do
        eval "$(parse_config "${cfg_path}/${sorted_cfg_files[$i]}")"
        color_msg "bblue" " $((i+1)): ${cfg_values[0]} ($(shorten_path "${cfg_values[1]}" "2" "both"))\n"
    done

    while true; do
        color_msg "white" "\nWhich config to use (1-${#sorted_cfg_files[@]}): " "bold"
        read -r choice
        ((choice--))
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "${#sorted_cfg_files[@]}" ]; then
            eval "$(parse_config "${cfg_path}/${sorted_cfg_files[$choice]}")"
            path_hash="$path_hash/${cfg_values[0]}"
            path_game="${cfg_values[1]}"
            autodetect=${cfg_values[2]}
            skip_processed=${cfg_values[3]}
            use_config=1
            break
        else
            color_msg "red" "Invalid choice, please select a number between 1 and ${#sorted_cfg_files[@]}.\n" "bold"
        fi
    done
}

parse_config() {
    local cfg_file="$1"
    local -a cfg_values=()

    [ ! -f "$cfg_file" ] && { echo "Error: Config file '$cfg_file' not found" >&2; return 1; }

    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        if [[ -n "$key" && -n "$value" ]]; then
            key=${key##+([[:space:]])}
            key=${key%%+([[:space:]])}
            value=${value##+([[:space:]])}
            value=${value%%+([[:space:]])}
            value=${value%\"}
            value=${value#\"}
            value=${value%\'}
            value=${value#\'}
            cfg_values+=("$value")
        fi
    done < "$cfg_file"

    [ ${#cfg_values[@]} -eq 0 ] && { echo "Error: No valid key-value pairs found in '$cfg_file'" >&2; return 1; }

    declare -p cfg_values
}

saveconfig() {
    [ $use_config -eq 1 ] && return 0

    local cfg_path="$1"
    local cfg_steam="$2"
    local cfg_auto="$3"
    local cfg_skip="$4"
    local cfg_game="$5"
    local cfg_file="$6"
    local cfg_date="$(date)"

    [ ! -d "$cfg_path" ] || [ -z "$cfg_file" ] && return 1

    cat <<-EOF > "$cfg_path/$cfg_file"
	# $cfg_date
	game="$cfg_game"
	gamepath="$cfg_steam"
	autodetect="$cfg_auto"
	skip_processed="$cfg_skip"
	EOF
}