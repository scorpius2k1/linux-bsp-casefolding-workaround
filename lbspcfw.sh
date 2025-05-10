#!/usr/bin/env bash

#
# Info    : Workaround for case folding issues for BSP map files with custom assets in Steam games on Linux
# Author  : Scorp (https://github.com/scorpius2k1)
# Repo    : https://github.com/scorpius2k1/linux-bsp-casefolding-workaround
# License : https://www.gnu.org/licenses/gpl-3.0.en.html#license-text
#

version="1.03"
logo="$(cat <<EOF
  _ _                     __          
 | | |                   / _|         
 | | |__  ___ _ __   ___| |___      __
 | | '_ \/ __| '_ \ / __|  _\ \ /\ / /
 | | |_) \__ \ |_) | (__| |  \ V  V / 
 |_|_.__/|___/ .__/ \___|_|   \_/\_/  
             | |                      
             |_| v${version} by Scorp 
EOF
)"

declare path_script="$(dirname "$(realpath "$0")")"
cd "$path_script"

declare path_bsp="$PWD/bsp"
declare path_data="$PWD/.data"
declare path_manual="$PWD/fix"
declare path_log="$PWD/log"
declare path_hash="$PWD/hash"
declare path_config="$PWD/cfg"
declare vpkeditcli="$PWD/vpkeditcli"
declare dependencies=(curl unzip rsync parallel)
declare -i bsp_processed=0
declare -i autodetect=0
declare -i skip_processed=0
declare -i use_config=0

prompt() {
    local default_value="${1,,}"
    local default_response=$([[ -z "$default_value" ]] && echo "1" || { [[ "$default_value" == "n" ]] && echo "0" || echo "1"; })

    while true; do
        read -p "" response
        case "${response,,}" in
            y) echo '1'; return ;;
            n) echo '0'; return ;;
            *) echo "$default_response"; return ;;
        esac
    done
}

color_msg() {
    local color="$1"
    local text="$2"
    local style="${3:-normal}"

    local style_code=""
    case "$style" in
        bold)      style_code="\033[1m" ;;
        underline) style_code="\033[4m" ;;
        *)         style_code="" ;;
    esac

    local color_code=""
    case "$color" in
        red)          color_code="\033[31m" ;;
        green)        color_code="\033[32m" ;;
        yellow)       color_code="\033[33m" ;;
        blue)         color_code="\033[34m" ;;
        magenta)      color_code="\033[35m" ;;
        cyan)         color_code="\033[36m" ;;
        white)        color_code="\033[37m" ;;
        black)        color_code="\033[30m" ;;
        bred)         color_code="\033[91m" ;;
        bgreen)       color_code="\033[92m" ;;
        byellow)      color_code="\033[93m" ;;
        bblue)        color_code="\033[94m" ;;
        bmagenta)     color_code="\033[95m" ;;
        bcyan)        color_code="\033[96m" ;;
        bwhite)       color_code="\033[97m" ;;
        "red bg")     color_code="\033[41m" ;;
        "green bg")   color_code="\033[42m" ;;
        "yellow bg")  color_code="\033[43m" ;;
        "blue bg")    color_code="\033[44m" ;;
        *)            color_code="" ;;
    esac

    printf "$style_code$color_code$text\033[0m"
}

checkdeps() {
    local missing=0

    for app in "${dependencies[@]}"; do
        if ! command -v "$app" &>/dev/null; then
            color_msg "red" "=> dependency '$app' is required, but not installed.\n" "bold"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        echo "Please check your distribution's documentation for further instructions."
        exit 1
    fi
}

checkupdate() {
    local repo_url="https://github.com/scorpius2k1/linux-bsp-casefolding-workaround.git"
    local latest_tag="https://api.github.com/repos/scorpius2k1/linux-bsp-casefolding-workaround/releases/latest"
    local latest="$(curl -s "$latest_tag" | grep '"tag_name":' | sed -E 's/.*"tag_name": "v?([0-9.]+)".*/\1/')"
    local path_update="$path_script/.update"

    if [ -n "$latest" ] && [ "$(printf '%s\n' "$version" "$latest" | sort -V | tail -n1)" = "$latest" ] && [ "$version" != "$latest" ]; then
        color_msg "white" "A newer version of LBSPCFW is available ($latest), update now? [Y/n] " "bold"
        if [ $(prompt) -eq 1 ]; then
            rm -rf "$path_update"
            if ! git clone "$repo_url" "$path_update" > /dev/null 2>&1; then
                color_msg "red" "Error: Failed to clone repository" "bold" >&2
                exit 1
            else
                rsync -aAHX "$path_update/" "$path_script"
                rm -rf "$path_update" 
                chmod +x "$path_script/lbspcfw.sh"

                color_msg "green" "Update successful, restarting script..."
                sleep 2
                exec "$path_script/lbspcfw.sh" "$@"
            fi
        fi
    fi
}

checkvpk() {
    local repo_url="https://api.github.com/repos/craftablescience/VPKEdit/releases/latest"
    local vpkedit_file="vpkedit"
    local timestamp_file=".vpkedit"
    local download_needed=1
    local current_time=$(date +%s)

    if [ -f "$vpkedit_file" ] && [ -f "$timestamp_file" ]; then
        local last_modified=$(cat "$timestamp_file" 2>/dev/null)
        if [ -n "$last_modified" ]; then
            local time_diff=$((current_time - last_modified))
            if [ "$time_diff" -lt 604800 ]; then
                download_needed=0
                return 0
            fi
        fi
    fi

    if [ "$download_needed" -eq 1 ]; then
        color_msg "white" "Updating 'vpkedit' to latest release\n(https://github.com/craftablescience/VPKEdit)..."
        printf "\n"
        local latest_url=$(curl -s $repo_url \
            | grep "browser_download_url.*.zip" \
            | grep "Linux-Binaries" \
            | cut -d '"' -f 4)
        if [ -z "$latest_url" ]; then
            color_msg "red" "Error: Failed to fetch latest VPKEdit release URL\n" "bold"
            exit 1
        fi
        local filename=$(basename "$latest_url")
        curl -s -L -o "$filename" "$latest_url" || { color_msg "red" "Error: Failed to download VPKEdit\n" "bold"; exit 1; }

        if ! unzip -t "$filename" &>/dev/null; then
            color_msg "red" "Error: Downloaded VPKEdit archive is corrupt\n" "bold"
            exit 1
        fi
        
        unzip -o "$filename" &>/dev/null || { color_msg "red" "Error: Failed to unzip VPKEdit\n" "bold"; exit 1; }
        rm -f "$filename"

        echo "$current_time" > "$timestamp_file"
    fi

    if [ ! -f "$vpkeditcli" ] || [ ! -x "$vpkeditcli" ]; then
        color_msg "red" "Error: '$vpkeditcli' not found or not executable. Please check the path and permissions.\n" "bold"
        exit 1
    fi    
}

game_root() {
    local search_path="${1%/}"
    local -a folders=()

    if [ ! -d "$search_path" ]; then
        return 1
    fi

    while IFS= read -r -d '' folder; do
        local folder_name=$(basename "$folder")
        if [[ -d "$folder" && "$folder" != "$search_path" && ! "${folder_name,,}" =~ proton && ! "${folder_name,,}" =~ steam ]]; then
            folders+=("$folder")
        fi
    done < <(find "$search_path" -maxdepth 1 -type d -print0 2>/dev/null)

    if [ ${#folders[@]} -eq 0 ]; then
        return 1
    fi

    printf '%s\n' "${folders[@]}" | sort
}

game_folder() {
    local root_path="${1%/}"
    if [ ! -d "$root_path" ]; then
        printf "Error: '%s' is not a valid directory\n" "$root_path" >&2
        return 1
    fi

    local -a validate=("cfg" "maps" "download" "gameinfo.txt")
    local current_parent=""
    declare -A found_items

    while IFS= read -r -d '' item; do
        local parent=$(dirname "$item")
        local item_name=$(basename "$item")

        if [ "$parent" != "$current_parent" ]; then
            if [ -n "$current_parent" ]; then
                local all_found=1
                for target in "${validate[@]}"; do
                    if [ -z "${found_items[$target]}" ]; then
                        all_found=0
                        break
                    fi
                done
                if [ "$all_found" -eq 1 ]; then
                    printf '%s\n' "$current_parent"
                    return 0
                fi
            fi
            declare -A found_items
            current_parent="$parent"
        fi

        if [ "$(dirname "$item")" = "$current_parent" ]; then
            for target in "${validate[@]}"; do
                if [ "${item_name,,}" = "${target,,}" ]; then
                    if [ -d "$item" ] || [ -f "$item" ]; then
                        found_items["$target"]=1
                    fi
                    break
                fi
            done
        fi
    done < <(find "$root_path" -maxdepth 2 -print0 2>/dev/null)

    if [ -n "$current_parent" ]; then
        local all_found=1
        for target in "${validate[@]}"; do
            if [ -z "${found_items[$target]}" ]; then
                all_found=0
                break
            fi
        done
        if [ "$all_found" -eq 1 ]; then
            printf '%s\n' "$current_parent"
            return 0
        fi
    fi

    return 1
}

process_bsp() {
    local -i cursor_index=0
    local -i max_jobs=$(( $(nproc) / 2 ))
    local -a cursors=("/" "-" "\\" "|")
    local -a map_hash
    local -A hash_seen
    local hash_parallel=""

    export vpkeditcli="$vpkeditcli"
    export path_data="$path_data"
    export steampath="$steampath"
    export path_log="$path_log"

    local fifo=$(mktemp -u)
    mkfifo "$fifo"
    trap 'rm -f "$fifo"' EXIT

    path_hash="$path_hash/hash.dat"

    if [ "$skip_processed" -eq 1 ]; then
        if [ -f "$path_hash" ]; then
            while IFS= read -r line; do
                [[ -n "$line" ]] && map_hash+=("$line") && hash_seen["$line"]=1
            done < "$path_hash" 2>/dev/null
        fi
    fi

    [ "$(ulimit -n)" -lt 8192 ] && ulimit -n 8192

    [ "$max_jobs" -lt 4 ] && max_jobs=4
    [ "$max_jobs" -gt 12 ] && max_jobs=12

    color_msg "blue" "Initializing..." "bold"
   
    hash_parallel=$(declare -p hash_seen)

    export hash_parallel
    export skip_processed
    export -f hash_check
    export -f hash_create

    parallel --tmpdir "$path_data/tmp" --jobs $max_jobs --line-buffer --keep-order --quote bash -c '   
        bsp="$1"
        bsp_name=$(basename "$bsp")

        eval "$hash_parallel"

        echo "=> Processing $bsp" >&2
        if [ "$skip_processed" -eq 1 ] && matched_hash=$(hash_check hash_seen "$bsp"); then
            echo "Skipping $bsp_name, previously processed (hash: $matched_hash)" >&2
            echo "SKIPPED: $bsp"
        elif "$vpkeditcli" --no-progress --output "$path_data" --extract / "$bsp" 2> "$path_log/${bsp_name}.log"; then
            echo "Extraction succeeded for $bsp_name" >&2
            materials="$path_data/${bsp_name%.*}/materials"
            models="$path_data/${bsp_name%.*}/models"
            sound="$path_data/${bsp_name%.*}/sound"
            [ -d "$materials" ] && rsync -aAHX "$materials" "$steampath"
            [ -d "$models" ] && rsync -aAHX "$models" "$steampath"
            [ -d "$sound" ] && rsync -aAHX "$sound" "$steampath"
            echo "Successfully synchronized extracted data for $bsp_name" >&2
            echo "Completed processing for $bsp_name" >&2
            rm -f "$path_log/${bsp_name}.log"
            echo "SUCCESS: $bsp"
        else
            echo "Failed extraction for $bsp_name" >&2
            echo "FAILED: $bsp"
        fi
    ' bash ::: "${bsp_files[@]}" > "$fifo" 2> "$path_log/process.log" &

    local parallel_pid=$!
    
    map_hash=()
    while IFS= read -r result || [ -n "$result" ]; do
        state=0
        if [[ "$result" =~ ^SUCCESS:\ (.+)$ ]]; then
            state=0
        elif [[ "$result" =~ ^SKIPPED:\ (.+)$ ]]; then
            state=1
        elif [[ "$result" =~ ^FAILED:\ (.+)$ ]]; then
            state=2
        else
            continue
        fi

        bsp="${BASH_REMATCH[1]}"
        local cursor="${cursors[cursor_index]}"
        local bsp_name=$(basename "$bsp")
        ((cursor_index = (cursor_index + 1) % 4))
        ((bsp_processed++))

        if [ "$state" -eq 0 ]; then
            color_msg "blue" "\r\033[K [$cursor] Processing $bsp_processed/$bsp_total ($((bsp_processed * 100 / bsp_total))%%) \033[36m${bsp_name%.*}..." "bold"
            [ "$skip_processed" -eq 1 ] && map_hash+=("$(hash_create "$bsp")")
        elif [ "$state" -eq 1 ]; then
            color_msg "blue" "\r\033[K [$cursor] Processing $bsp_processed/$bsp_total ($(((bsp_processed) * 100 / bsp_total))%%) \033[35mSkipping ${bsp_name%.*} (already processed)..." "bold"
        elif [ "$state" -eq 2 ]; then
            color_msg "yellow" "Warning: Failed to extract '$bsp_name', skipping. Check error log at $path_log/${bsp_name}.log"
            sleep 1
        fi
    done < "$fifo"

    wait "$parallel_pid"
    printf "\n"

    rm -rf "$fifo"

    if [ "$skip_processed" -eq 1 ]; then
        for hash in "${map_hash[@]}"; do
            [[ -z "${hash_seen[$hash]}" ]] && echo "$hash" >> "$path_hash"
        done
    fi
}

hash_check() {
    [[ "$skip_processed" -eq 0 ]] && return 1

    local -n hashes=$1
    local filename="$2"

    [[ -z "$filename" || ! -f "$filename" ]] && return 1

    local hash=$(hash_create "$filename")

    if [[ ${hashes["$hash"]} -eq 1 ]]; then
        echo "$hash"
        return 0
    fi

    return 1
}

hash_create() {
    stat --format="%d %s %Y %Z %n" "$1" | sha1sum | awk '{print $1}'
}

shorten_path() {
    local path="$1"
    local depth="${2:-5}"
    local direction="${3:-last}"

    path="${path#/}"
    path="${path%/}"

    IFS='/' read -r -a segments <<< "$path"
    local total=${#segments[@]}

    [ "$total" -eq 0 ] && { echo "$path"; return; }

    if [ "$total" -le "$depth" ]; then
        local result=""
        for ((i=0; i<total; i++)); do
            [ $i -eq 0 ] && result="${segments[i]}" || result="$result/${segments[i]}"
        done
        echo "/$result"
        return
    fi

    local short=""
    if [ "$direction" = "first" ]; then
        for ((i=0; i<depth; i++)); do
            [ $i -eq 0 ] && short="${segments[i]}" || short="$short/${segments[i]}"
        done
        short="$short/..."
    else
        local start=$((total - depth))
        short="..."
        for ((i=start; i<total; i++)); do
            short="$short/${segments[i]}"
        done
    fi

    echo "$short"
}

check_steampath() {
    local steamroot=(
        "$HOME/.steam/debian-installation/steamapps/common"
        "$HOME/.local/share/Steam/steamapps/common"
        "$HOME/.steam/steam/steamapps/common"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common"
        "$HOME/snap/steam/common/.local/share/Steam/steamapps/common"
    )
    local steamtype=(
        "System"
        "System"
        "System"
        "Flatpak"
        "Snap"
    )

    for ((i = 0; i < ${#steamroot[@]}; i++)); do
        if [ -d "${steamroot[$i]}" ]; then
            steampath="${steamroot[$i]}"
            color_msg "green" "${steamtype[$i]} Steam Install Detected\n"
            return 0
        fi
    done
}

find_steam_libraries() {
    local array_name="$1"
    if [ -z "$array_name" ]; then
        return 1
    fi

    eval "declare -ag $array_name"
    eval "$array_name=()"

    local found_paths=()
    while IFS=' ' read -r _ mount_point _; do
        case "$mount_point" in
            /proc*|/sys*|/dev*|/run*|/snap*|/var/lib/docker*|/tmp*) continue ;;
        esac
        [ -d "$mount_point" ] || continue
        while IFS= read -r path; do
            [ -n "$path" ] && found_paths+=("$path")
        done < <(find "$mount_point" -type d -path "*/steamapps/common" 2>/dev/null)
    done < /proc/mounts

    while IFS= read -r path; do
        [ -n "$path" ] && found_paths+=("$path")
    done < <(find "$HOME" -type d -path "*/steamapps/common" 2>/dev/null)

    declare -A unique_paths
    for path in "${found_paths[@]}"; do
        unique_paths["$path"]=1
    done

    for path in "${!unique_paths[@]}"; do
        if find "$path" -maxdepth 1 -type d -not -path "$path" | read -r _; then
            eval "$array_name+=(\"$path\")"
        fi
    done
}

checkconfig() {
    local cfg_check=${1:-0}
    local cfg_path="$path_config"
    local -a cfg_files=()
    local -A cfg_game_names=()

    [ ! -d "$cfg_path" ] && { return 1; }

    for file in "$cfg_path"/*; do
        [ -f "$file" ] || continue
        filename=$(basename "$file")
        eval "$(parse_config "${cfg_path}/${filename}")"
        cfg_game_names["$filename"]="${cfg_values[0]}"
        cfg_files+=("$filename")
    done

    [ "$cfg_check" -eq 1 ] && { echo ${#cfg_files[@]}; return 0; }
    [ ${#cfg_files[@]} -eq 0 ] && { return 1; }

    local -a sorted_cfg_files=()
    local -a manual_configs=()
    for cfg in "${cfg_files[@]}"; do
        if [ "${cfg_game_names[$cfg]}" = "Manual" ]; then
            manual_configs+=("$cfg")
        else
            sorted_cfg_files+=("$cfg")
        fi
    done

    sorted_cfg_files+=("${manual_configs[@]}")

    color_msg "white" "Available Configs\n"
    for i in "${!sorted_cfg_files[@]}"; do
        eval "$(parse_config "${cfg_path}/${sorted_cfg_files[$i]}")"
        color_msg "bblue" "$((i+1)): ${cfg_values[0]} ($(shorten_path "${cfg_values[1]}" "3" "first"))\n"
    done

    while true; do
        color_msg "white" "\nWhich config to use (1-${#sorted_cfg_files[@]}): " "bold"
        read -r choice
        ((choice--))
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "${#sorted_cfg_files[@]}" ]; then
            eval "$(parse_config "${cfg_path}/${sorted_cfg_files[$choice]}")"
            path_hash="$path_hash/${cfg_values[0]}"
            steampath="${cfg_values[1]}"
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
            key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

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
    local cfg_path="$1"
    local cfg_steam="$2"
    local cfg_auto="$3"
    local cfg_skip="$4"
    local cfg_game="$5"
    local cfg_file="$6"
    local cfg_date="$(date)"

    [ ! -d "$cfg_path" ] && { return 1; }

    cat <<-EOF > "$cfg_path/$cfg_file"
	# $cfg_date
	game="$cfg_game"
	steampath="$cfg_steam"
	autodetect="$cfg_auto"
	skip_processed="$cfg_skip"
	EOF
}

checkargs() {
    ARGS="$#"
    POSITIONAL_ARGS=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                use_config=1
                shift
                shift
            ;;
            -h|--help)
                color_msg "white" "Usage: $0 [--config] [--help]\n\nLinux BSP Case Folding Workaround\n- Workaround for Valve Source1 engine games case folding issue on Linux\n- Options:\n  --config: Use a saved configuration\n  --help: Show this message\n"
                exit 0
            ;;            
            -*|--*|*)
                echo "Unknown option '$1'"
                exit 0
            ;;
            *)
                POSITIONAL_ARGS+=("$1")
                shift
            ;;
        esac
    done
    set -- "${POSITIONAL_ARGS[@]}"
}

show_logo() {
    clear
    color_msg "bcyan" "$logo\n\n" "bold"
    color_msg "bcyan" ":: Linux BSP Case Folding Workaround ::\n"
    color_msg "bcyan" "=======================================\n\n"
}

# Init
show_logo
mkdir -p "$path_bsp"
mkdir -p "$path_data"
mkdir -p "$path_manual"
mkdir -p "$path_log"
mkdir -p "$path_hash"
mkdir -p "$path_config"

checkdeps
checkupdate
checkvpk
checkargs "$@"

if [ "$use_config" -eq 0 ] && [ "$(checkconfig 1)" -ne 0 ]; then
    color_msg "white" "Use configuration preset? [Y/n] " "bold"
    use_config=$(prompt)
fi

if [ "$use_config" -eq 1 ]; then
    checkconfig
    [ "$autodetect" -eq 0 ] && steampath="$path_manual"
    color_msg "white" "Skip previously processed maps? [Y/n] " "bold"
    skip_processed=$(prompt)

else
    color_msg "white" "Attempt to auto-detect game folders/maps? [Y/n] " "bold"
    autodetect=$(prompt)

    if [ "$autodetect" -eq 1 ]; then
        local -a steamexternal

        show_logo
        check_steampath

        if [ ! -d "$steampath" ]; then
            color_msg "red" "Error: Steam path invalid or not found! ($steampath)\n" "bold"
            color_msg "white" "=> Enter valid path to your Steam Install root path (../Steam/steamapps/common): " "bold"
            read -r steampath
            if [ ! -d "$steampath" ]; then
                color_msg "red" "Error: No Steam Install found ($steampath), aborting.\n" "bold"
                exit 1
            fi
        fi

        color_msg "bblue" "${steampath}\n"
        color_msg "white" "\nSearch for additional Steam Libraries? [y/N] " "bold"
        if [ $(prompt "n") -eq 1 ]; then
            color_msg "white" "Searching for Steam Library folders..."   
            find_steam_libraries steamexternal;

            color_msg "white" "\n\nAvailable Steam Libraries:\n"
            for i in "${!steamexternal[@]}"; do
                color_msg "bblue" "$((i+1)): ${steamexternal[$i]}\n"
            done

            color_msg "white" "\nWhich library to use (1-${#steamexternal[@]}): " "bold"
            read -r choice
            ((choice--))
            if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -ge "${#steamexternal[@]}" ]; then
                color_msg "red" "Invalid choice, exiting.\n" "bold"
                exit 1
            fi

            steampath="${steamexternal[$choice]}"      
        fi

        mapfile -t gamepath < <(game_root "$steampath")
        if [ "${#gamepath[@]}" -eq 0 ]; then
            color_msg "red" "\nNo Steam Libraries found, exiting.\n" "bold"
            exit 1
        fi
        
        show_logo
        color_msg "white" "Available Games\n"
        for i in "${!gamepath[@]}"; do
            color_msg "bblue" "$((i+1)): ${gamepath[$i]##*/}\n"
        done

        while true; do
            color_msg "white" "\nWhich game to apply workaround (1-${#gamepath[@]}): " "bold"
            read -r choice
            ((choice--))
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "${#gamepath[@]}" ]; then
                steampath=$(game_folder "${gamepath[$choice]}")
                if [ -n "$steampath" ]; then
                    steampath="$steampath/download"
                    color_msg "green" "Game set to '$(echo "${steampath##*/common/}" | cut -d'/' -f1)'\n\n"
                    break
                else
                    color_msg "red" "Error: Failed to validate game, retrying.\n" "bold"
                fi
            else
                color_msg "red" "Invalid choice, please select a number between 1 and ${#gamepath[@]}.\n" "bold"
            fi
        done

        path_hash="$path_hash/$(basename "${gamepath[$choice]}")"
    else
        steampath="$path_manual"
        path_hash="$path_hash/manual"
        color_msg "yellow" "Manual Mode Selected\n"
    fi

    color_msg "white" "Skip previously processed maps? [Y/n] " "bold"
    skip_processed=$(prompt)
fi

# Prepare environment
color_msg "green" "Preparing Environment...\n" "bold"
[ -z "$TERM" ] && export TERM="xterm"
mkdir -p "$path_hash"
mkdir -p "$steampath/maps"
rm -rf "$path_data"/* || { color_msg "red" "Error: Failed to prepare $path_data\n" "bold"; exit 1; }
rm -rf "$path_log"/* || { color_msg "red" "Error: Failed to prepare $path_log\n" "bold"; exit 1; }
mkdir -p "$path_data/tmp"
if [ "$autodetect" -eq 1 ]; then
    path_bsp="$steampath/maps"
else
    mkdir -p "$path_manual"
    rm -rf "$path_manual"/* || { color_msg "red" "Error: Failed to prepare $path_manual\n" "bold"; exit 1; }    
fi
sleep 1

# Process
clear
show_logo

mapfile -t bsp_files < <(find -L "$path_bsp" -maxdepth 1 -type f -iname "*.bsp" | sort)
bsp_total=${#bsp_files[@]}

if [ "$bsp_total" -eq 0 ]; then
    color_msg "red" "Error: No Map files (bsp) found in '$path_bsp'\n" "bold"
    exit 1
else
    color_msg "green" "=> $bsp_total maps found in '$(shorten_path "$path_bsp" "3")'\n"
    color_msg "green" "=> Output path '$(shorten_path "$steampath" "3")'\n\n"
    if [[ -d "$steampath/materials" || -d "$steampath/models" || -d "$steampath/sound" ]]; then
        color_msg "yellow" "WARNING: Merging into existing game 'materials/models/sound' data!\n" "bold"
        color_msg "yellow" "Ensure you have a backup of these folders before proceeding, if needed.\n\n"
    fi
    color_msg "white" "Press any key to begin (CTRL+C to abort)..." "bold"
    read -n 1 -s
    printf '\n'

    declare -i start_time=$(date +%s)
    process_bsp
    sleep 1
fi

# Cleanup
declare -i end_time=$(date +%s)
declare -i total_seconds=$((end_time - start_time))
declare -i minutes=$((total_seconds / 60))
declare -i seconds=$((total_seconds % 60))

color_msg "white" "\nCleaning up...\n\n"
rm -rf "$path_data"/* || { color_msg "red" "Error: Failed to cleanup $path_data\n" "bold"; exit 1; }

color_msg "bgreen" "=> SUCCESS! $bsp_processed Maps Processed in ${minutes}m ${seconds}s\n" "bold"
if [ "$autodetect" -eq 0 ]; then
    color_msg "bmagenta" " To apply workaround, move everything from"
    color_msg "white" " '$(shorten_path "$steampath")/' "
    color_msg "bmagenta" "into desired Steam Game download path\n"
    color_msg "white" " Ex. '../Steam/steamapps/common/Half Life 2/download/'\n\n"
    color_msg "magenta" " >> Data must be copied to game download path (custom folder does not work) <<\n\n"

    saveconfig "$path_config" "$path_bsp" "$autodetect" "$skip_processed" "Manual" "$(hash_create "$path_bsp")"
else
    saveconfig "$path_config" "$steampath" "$autodetect" "$skip_processed" "$(echo "${steampath##*/common/}" | cut -d'/' -f1)" "$(hash_create "$steampath")"
fi

printf '\n'
