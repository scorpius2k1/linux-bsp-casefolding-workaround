checkdeps() {
    local confirm=${1:-0}
    local missing_deps=()
    local install_cmd
    local cache_cmd
    local distro

    for app in "${dependencies[@]}"; do
        if ! command -v "$app" &>/dev/null; then
            missing_deps+=("$app")
        else
            command_run[$app]="$(which "$app" 2>/dev/null)"
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        [ $use_steam -eq 1 ] && { notify_steam_error; exit 1; }
        
        if [ $use_service -eq 1 ]; then
            echo "Missing dependencies: ${missing_deps[*]}"
            notify "Unable to start service, run this script manually from a terminal to complete initial configuration"
            exit 1
        fi

        if [ $confirm -eq 1 ] || ! command -v sudo >/dev/null 2>&1; then
            color_msg "red" "There was an problem installing dependencies:\n" "bold"
            color_msg "red" " ${missing_deps[*]}\n\n"
            color_msg "white" "Please check your distribution's documentation for further instructions.\n\n"
            exit 1
        fi

        if command -v pacman &>/dev/null; then
            distro="arch"
            cache_cmd="sudo pacman -Syy"
            install_cmd="sudo pacman -S --noconfirm"
        elif command -v apt &>/dev/null; then
            distro="debian"
            cache_cmd="sudo apt update"
            install_cmd="sudo apt install -y"
        elif command -v dnf &>/dev/null; then
            distro="fedora"
            cache_cmd="sudo dnf makecache"
            install_cmd="sudo dnf install -y"
        else
            color_msg "red" "Dependencies required, but not found:\n" "bold"
            color_msg "red" " ${missing_deps[*]}\n\n"
            color_msg "white" "Please check your distribution's documentation for further instructions.\n\n"
            exit 1
        fi

        color_msg "red" "Missing dependencies: ${missing_deps[*]}\n" "bold"
        color_msg "white" "Would you like to install them now? (Y/n): " "bold"
        if [ $(prompt) -eq 1 ]; then
            color_msg "blue" "=> Installing dependencies...\n"

            local install_pkgs=()
            for dep in "${missing_deps[@]}"; do
                case "$distro" in
                    arch)
                        case "$dep" in
                            inotifywait) install_pkgs+=("inotify-tools") ;;
                            notify-send) install_pkgs+=("libnotify") ;;
                            *) install_pkgs+=("$dep") ;;
                        esac
                        ;;
                    debian)
                        case "$dep" in
                            inotifywait) install_pkgs+=("inotify-tools") ;;
                            notify-send) install_pkgs+=("libnotify-bin") ;;
                            *) install_pkgs+=("$dep") ;;
                        esac
                        ;;
                    fedora)
                        case "$dep" in
                            inotifywait) install_pkgs+=("inotify-tools") ;;
                            notify-send) install_pkgs+=("libnotify") ;;
                            *) install_pkgs+=("$dep") ;;
                        esac
                        ;;
                esac
            done

            if ! $cache_cmd > /dev/null 2>&1; then
                color_msg "red" "Failed to update package database. Please install dependencies manually.\n"
                color_msg "white" "Required packages: ${install_pkgs[*]}\n"
                exit 1
            fi
            if ! $install_cmd "${install_pkgs[@]}" > /dev/null 2>&1; then
                color_msg "red" "Failed to install dependencies. Please install dependencies manually.\n"
                color_msg "white" "Required packages: ${install_pkgs[*]}\n"
                exit 1
            fi
            color_msg "green" "Dependencies installed successfully!\n" "bold"
            checkdeps 1
            sleep 2
            show_logo
        else
            color_msg "yellow" "=> Please install required dependencies manually and try again\n\n"
            exit 1
        fi
    fi
}

checkupdate() {
    [ -d "$path_script/hash" ] && { find "$path_script/hash" -maxdepth 1 -mindepth 1 -exec mv -f {} "$path_hash"/ \; ; rm_dir "$path_script/hash"; }
    [ -d "$path_script/cfg" ] && { find "$path_script/cfg" -maxdepth 1 -mindepth 1 -exec mv -f {} "$path_cfg"/ \; ; rm_dir "$path_script/cfg"; }

    [ "$use_service" -eq 1 ] || [ "$use_steam" -eq 1 ] && return

    local repo_url="https://github.com/scorpius2k1/linux-bsp-casefolding-workaround.git"
    local latest_tag="https://api.github.com/repos/scorpius2k1/linux-bsp-casefolding-workaround/releases/latest"
    local latest="$("${command_run[curl]}" -s "$latest_tag" | grep '"tag_name":' | sed -E 's/.*"tag_name": "v?([0-9.]+)".*/\1/')"
    local path_update="$path_script/.update"

    if [ -n "$latest" ] && [ "$(printf '%s\n' "$version" "$latest" | sort -V | tail -n1)" = "$latest" ] && [ "$version" != "$latest" ]; then
        color_msg "white" "A newer version of LBSPCFW is available ($latest), update now? [Y/n] " "bold"
        if [ $(prompt) -eq 1 ]; then
            rm_dir "$path_update"
            if ! git clone "$repo_url" "$path_update" > /dev/null 2>&1; then
                color_msg "red" "Error: Failed to clone repository" "bold" >&2
                exit 1
            fi
            "${command_run[rsync]}" -aAHX "$path_update/" "$path_script" > /dev/null 2>&1
            rm_dir "$path_update"
            chmod +x "$path_script/lbspcfw.sh"
            color_msg "green" "Update successful, restarting script..."
            sleep 2
            exec "$path_script/${0##*/}" "$@"
        fi
    fi
}

checkvpk() {
    command_run[vpkeditcli]="$path_script/vpkeditcli"

    [ "$use_steam" -eq 1 ] && ! command -v "${command_run[vpkeditcli]}" &>/dev/null && { notify_steam_error; exit 1; }
    [ "$use_steam" -eq 1 ] && return
    
    local repo_url="https://api.github.com/repos/craftablescience/VPKEdit/releases/latest"
    local vpkedit_file="${command_run[vpkeditcli]}"
    local timestamp_file="$path_script/.vpkedit"
    local download_needed=1
    local current_time=$(date +%s)

    if [ -f "$vpkedit_file" ] && [ -f "$timestamp_file" ]; then
        local last_modified=$(cat "$timestamp_file")
        if [ -n "$last_modified" ] && [ $((current_time - last_modified)) -lt 604800 ]; then
            download_needed=0
            return 0
        fi
    fi

    if [ "$download_needed" -eq 1 ]; then
        color_msg "white" "Updating 'vpkedit' to latest release...\n" "bold"
        color_msg "green" " https://github.com/craftablescience/VPKEdit"
        local latest_url=$("${command_run[curl]}" -s "$repo_url" | grep "browser_download_url.*Linux-Binaries.*\.zip" | cut -d '"' -f 4)
        [ -z "$latest_url" ] && { color_msg "red" "Error: Failed to fetch latest VPKEdit release URL\n" "bold"; exit 1; }
        local filename="${latest_url##*/}"
        "${command_run[curl]}" -s -L -o "$filename" "$latest_url" || { color_msg "red" "Error: Failed to download VPKEdit\n" "bold"; exit 1; }
        "${command_run[unzip]}" -t "$filename" &>/dev/null || { color_msg "red" "Error: Downloaded VPKEdit archive is corrupt\n" "bold"; exit 1; }
        "${command_run[unzip]}" -o "$filename" -d "$path_script" &>/dev/null || { color_msg "red" "Error: Failed to unzip VPKEdit\n" "bold"; exit 1; }
        
        [ -f "$vpkedit_file" ] || { color_msg "red" "Error: '$vpkedit_file' not found after unzip.\n" "bold"; exit 1; }
        
        chmod +x "${command_run[vpkeditcli]}"
        rm_file "$filename"
        echo "$current_time" > "$timestamp_file"
    fi
}

checkargs() {
    ARGS="$#"
    POSITIONAL_ARGS=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config) use_config=1; shift ;;
            -m|--monitor) use_monitor=1; shift ;;
            -s|--service) use_service=1; shift; [ -n "$1" ] && [[ ! "$1" =~ ^-- ]] && { use_service=3; shift; } ;;
            -r|--reset) show_logo 1; data_reset; show_logo 1; shift ;;
            -h|--help)
                color_msg "white" "\nUsage: ${0##*/} " "bold"
                color_msg "white" "[--config] [--monitor] [--service] [--reset] [--help]\n\n"
                color_msg "white" "Linux BSP Case Folding Workaround\n" "bold"
                color_msg "white" "- Workaround for Valve Source1 engine games case folding issue on Linux\n"
                color_msg "white" "- Options:\n"
                color_msg "white" "  --config: Use a saved configuration\n"
                color_msg "white" "  --monitor: Monitor active game\n"
                color_msg "white" "  --service: Create daemon background service monitor for active game\n"
                color_msg "white" "  --reset: Reset all script data to defaults\n"
                color_msg "white" "  --help: Show this message\n\n"
                color_msg "white" "  This script can also be run as a monitor via Steam launch option:\n" "bold"
                color_msg "white" "  $path_script/${0##*/} %%command%%\n"
                color_msg "white" "   *Steam installs using snap/flatpak may not work with this option\n\n"
                exit 0
                ;;
            -*|--*|*)
                if [[ "$@" =~ "SteamLaunch AppId" ]]; then
                    use_steam=1
                    break
                fi
                echo "Unknown option '$1'" >&2
                exit 1
                ;;
            *) POSITIONAL_ARGS+=("$1"); shift ;;
        esac
    done
    set -- "${POSITIONAL_ARGS[@]}"

    [ "$use_service" -eq 1 ] && [ "$(checkconfig 1)" -eq 0 ] && use_service=2
    [ "$use_service" -eq 3 ] && use_service=1
}

data_reset() {
    [ ! -d "$path_script" ] && return 1

    color_msg "yellow" "WARNING: This will remove all existing script-related data!\n" "bold"
    color_msg "blue" "$(shorten_path "$path_script" "3" "last")\n\n"
    color_msg "white" "Continue with reset? [y/N] " "bold"

    if [ $(prompt "n") -eq 1 ]; then
        local state=0
        [[ $path_bsp == *"$path_script"* ]] && rm_dir "$path_bsp" || state=1
        [[ $path_cfg == *"$path_script"* ]] && rm_dir "$path_cfg" || state=1
        [[ $path_data == *"$path_script"* ]] && rm_dir "$path_data" || state=1
        [[ $path_sync == *"$path_script"* ]] && rm_dir "$path_sync" || state=1
        [[ $path_hash == *"$path_script"* ]] && rm_dir "$path_hash" || state=1
        [[ $path_log == *"$path_script"* ]] && rm_dir "$path_log" || state=1
        rm_file "$path_script/vpkedit" || state=1
        rm_file "$path_script/vpkeditcli" || state=1
        rm_file "$path_script/.vpkedit" || state=1

        [ "$state" -eq 0 ] && color_msg "green" " All script data has been successfully reset.\n" || { color_msg "red" "Error: Failed to reset script data!\n" "bold"; exit 1; }

        color_msg "white" "Remove all services? [y/N] " "bold"
        color_msg "Skipping service removal"
        [ $(prompt "n") -eq 1 ] && remove_user_service || color_msg "green" " Skipping service removal"

        sleep 2
    fi
}

env_prepare() {
    color_msg "green" "Preparing Environment...\n" "bold"
  
    local path_root

    [ "$use_steam" -eq 1 ] && path_root="steam/${path_game##*/}"
    [ "$use_service" -eq 1 ] && path_root="service/${path_game##*/}"
    [ "$use_service" -ne 1 ] && [ "$use_steam" -eq 0 ] && path_root="process/${path_game##*/}"
    path_data="$path_data/$path_root"
    path_log="$path_log/$path_root"

    rm_dir "$path_data/"
    rm_dir "$path_log/"
    if [ "$autodetect" -eq 1 ] || [ "$use_service" -eq 1 ] || [ "$use_steam" -eq 1 ]; then
        path_sync="$path_game/download"
        path_bsp="$path_sync/maps"
    fi
    mk_dir "$path_sync/maps"
    mk_dir "$path_sync/materials"
    mk_dir "$path_sync/models"
    mk_dir "$path_sync/sound"
    mk_dir "$path_hash"
    mk_dir "$path_data"
    mk_dir "$path_log"

    sleep 1
}

env_cleanup() {
    trap '' SIGINT SIGTERM EXIT
    if [ $use_monitor -eq 2 ]; then
        [ "$use_service" -eq 0 ] && color_msg "white" "\nStopped Monitor\n" || notify "Stopped Monitor for '$game_name'"
        [ "$use_service" -eq 0 ] && color_msg "bgreen" "=> $bsp_processed maps processed, monitor active $(process_time)\n\n" "bold"
        [ "$use_steam" -eq 1 ] && notify "Steam Monitor Stopped"
    fi

    game_process "unfreeze"
    pkill -P $$ 2>/dev/null

    [ "$use_service" -eq 1 ] || [ "$use_steam" -eq 1 ] && exit 0

    color_msg "cyan" "Thank you for using LBSPCFW!\n" "bold"
    color_msg "cyan" "If you found it useful, please consider sharing & supporting further development.\n"
    color_msg "green" " > "; color_msg "green" "https://help.scorpex.org/?s=git\n\n" "underline"

    stty echoctl 2>/dev/null
    exit 0
}

env_exit() {
    [ $? -eq 0 ] && env_cleanup
}
