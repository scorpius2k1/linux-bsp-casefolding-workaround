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
            command_run[$app]="$(command -v "$app")"
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
        elif command -v emerge &>/dev/null; then
            distro="gentoo"
            cache_cmd="sudo emerge --sync"
            install_cmd="sudo emerge -qN"
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
                    gentoo)
                        case "$dep" in
                            curl) install_pkgs+=("net-misc/curl") ;;
                            inotifywait) install_pkgs+=("sys-fs/inotify-tools") ;;
                            notify-send) install_pkgs+=("x11-libs/libnotify") ;;
                            parallel) install_pkgs+=("sys-process/parallel") ;;
                            rsync) install_pkgs+=("net-misc/rsync") ;;
                            unzip) install_pkgs+=("app-arch/unzip") ;;
                            *) install_pkgs+=("$dep") ;;
                        esac
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

checkargs() {
    if [[ " $* " =~ " -r " ]] || [[ " $* " =~ " --reset " ]]; then
        show_logo 1
        data_reset
    fi

    ARGS="$#"
    POSITIONAL_ARGS=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_logo

                color_msg "white" "Usage: $script_name [-c] [-d] [-R] [-X] [-h] [-m] [-p] [-r] [-s] [-u]\n\n"

                color_msg "white" "  -c, --config:          Load saved game preset/profile shortcut\n"
                color_msg "white" "  -d, --docker:          Execute within a containerized environment\n"
                color_msg "white" "  -R, --docker-rebuild:  Force-rebuild container image and launch containerized\n"
                color_msg "white" "  -X, --docker-remove:   Remove container image and cleanup resources\n"
                color_msg "white" "  -h, --help:            Display this help message\n"
                color_msg "white" "  -m, --monitor:         Track active game process and apply fixes live\n"
                color_msg "white" "  -p, --purge:           Remove all custom assets and clear game cache files\n"
                color_msg "white" "  -r, --reset:           Reset all script data and configurations to defaults\n"
                color_msg "white" "  -s, --service:         Deploy background daemon for automated monitoring\n"
                color_msg "white" "  -u, --undo [mode]:     Rollback: [precise] (default 1:1) or [recurse] (folder-purge)\n\n"
                color_msg "white" "  Steam Launch Option:\n" "bold"
                color_msg "white" "  $path_script/$script %command%\n\n"
                color_msg "yellow" "  Note: Only one argument may be used at a time (except --reset, which allows\n"
                color_msg "yellow" "  one subsequent command to follow).\n\n"                
                exit 0 ;;
            -r|--reset) shift ;;
            -c|--config) use_config=1; break; ;;
            -d|--docker) use_docker=1; break; ;;
            -R|--docker-rebuild) use_docker=2; break; ;;
            -X|--docker-remove) use_docker=3; break; ;;
            -m|--monitor) use_monitor=1; break; ;;
            -p|--purge) use_purge=1; break; ;;
            -s|--service) use_service=1; shift; [ -n "$1" ] && [[ ! "$1" =~ ^-- ]] && { use_service=3; break; } ;;
            -u|--undo) [[ "$2" == "recurse" ]] && { use_undo=2; shift 2; } || { use_undo=1; shift; }; break ;;
            -*|--*) if [[ "$*" =~ "SteamLaunch AppId" ]]; then use_steam=1; break; fi; echo "Unknown option '$1'" >&2; exit 1 ;;
            *) POSITIONAL_ARGS+=("$1"); shift ;;
        esac
    done
    set -- "${POSITIONAL_ARGS[@]}"
    [ "$use_service" -eq 1 ] && [ "$(checkconfig 1)" -eq 0 ] && use_service=2
    [ "$use_service" -eq 3 ] && use_service=1
}

checkdocker() {
    if [[ -z "$IN_DOCKER" && "$use_docker" -gt 0 ]]; then
        if ! command -v docker &>/dev/null; then
            color_msg "red" "Error: 'docker' is not installed!\n"
            exit 0
        fi
        if ! docker info >/dev/null 2>&1; then
            color_msg "red" "Error: docker access restricted by your system (root or docker group required)\n"
            exit 0
        fi
        
        if [ "$use_docker" -eq 3 ]; then
            docker_run
            exit 0
        fi

        check_steampath
        mapfile -t gamepath < <(game_root "$path_steam")
        if [ "${#gamepath[@]}" -eq 0 ]; then
            show_logo
            color_msg "white" "Searching for Steam Library folders..."
            find_steam_libraries steamexternal
            [ ${#steamexternal[@]} -eq 0 ] && { color_msg "red" "\nError: No Steam Libraries found, aborting.\n\n" "bold"; exit 1; }
            color_msg "white" "\n\nAvailable Steam Libraries:\n"
            for i in "${!steamexternal[@]}"; do
                color_msg "bblue" "$((i+1)): $(shorten_path "${steamexternal[$i]}" "6" "first")\n"
            done

            while true; do
                color_msg "white" "\nWhich library to use (1-${#steamexternal[@]}): " "bold"
                read -r choice || exit 1

                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    ((choice--))

                    if [ "$choice" -ge 0 ] && [ "$choice" -lt "${#steamexternal[@]}" ]; then
                        path_steam="${steamexternal[$choice]}"
                        break
                    fi
                fi

                color_msg "red" "Invalid choice, please select a number between 1 and ${#steamexternal[@]}.\n" "bold"
            done
        fi

        docker_run

    elif [ "$IN_DOCKER" == "1" ]; then
        use_service=0
        use_steam=0
        use_purge=0
        use_reset=0
        use_config=2
        use_docker=1
    fi    
}

checkpaths() {
    local required_dirs=(
        "$path_bsp"
        "$path_cfg"
        "$path_hash"
        "$path_log"
        "$path_sync"
        "$path_temp"
        "$path_undo"
        "$path_vpk"
    )
    
    local current_uid=$(id -u)
    local current_user=$(whoami)
    local fail=0

    for path in "${required_dirs[@]}"; do
        [[ $current_uid -gt 0 || $IN_DOCKER == "1" ]] && mk_dir "$path"
        [[ $current_uid -eq 0 && $IN_DOCKER != "1" ]] && continue  

        local owner=$(stat -c '%U' "$path" 2>/dev/null) # 'stat -f %Su'

        if [ "$owner" = "root" ]; then
            color_msg "yellow" "WARNING: '$path' is owned by root.\n"
            fail=1
        elif [ "$owner" != "$current_user" ]; then
            color_msg "yellow" "WARNING: '$path' is owned by '$owner', not '$current_user'\n"
            fail=1
        fi

        if [ ! -w "$path" ]; then
            color_msg "yellow" "WARNING: '$path' is not writable.\n"
            fail=1
        fi
    done

    if [ $fail -ne 0 ]; then
        color_msg "red" "FAILED: Path permissions check.\n" "bold"
        exit 1
    fi
}

checkselinux() {
    if [ -d /sys/fs/selinux ]; then
        if [ -f /sys/fs/selinux/enforce ] && [ "$(cat /sys/fs/selinux/enforce)" -eq 1 ]; then
            echo ":Z"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

checkupdate() {
    if [ "$use_service" -eq 1 ] || [ "$use_steam" -eq 1 ] || [ "$use_docker" -eq 1 ]; then
        return
    fi

    local repo_url="https://github.com/scorpius2k1/linux-bsp-casefolding-workaround.git"
    local latest_tag="https://api.github.com/repos/scorpius2k1/linux-bsp-casefolding-workaround/releases/latest"
    local path_update="$path_script/.update"

    local latest=$("${command_run[curl]}" -sL --connect-timeout 5 --max-time 10 "$latest_tag" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | sed 's/^v//')

    if [ -z "$latest" ]; then
        color_msg "yellow" "WARNING: Unable to check for updates\n"
        return
    fi

    if [ "$version" != "$latest" ] && [ "$(printf '%s\n' "$version" "$latest" | sort -V | tail -n1)" = "$latest" ]; then
        color_msg "white" "A newer version of LBSPCFW is available ($latest), update now? [Y/n] " "bold"
        
        if [ $(prompt) -eq 1 ]; then
            [ -d "$path_update" ] && rm_dir "$path_update"

            if ! git clone --depth 1 "$repo_url" "$path_update" > /dev/null 2>&1; then
                color_msg "red" "Error: Failed to clone repository\n" "bold" >&2
                return 1
            fi

            if [ ! -s "$path_update/$script" ]; then
                color_msg "red" "Error: Update verification failed\n" "bold"
                rm_dir "$path_update"
                return 1
            fi

            "${command_run[rsync]}" -rlptD --exclude='.git' "$path_update/" "$path_script/" > /dev/null 2>&1
            
            process_update
            
            rm_dir "$path_update"
            chmod +x "$path_script/$script"
            
            color_msg "green" "Update successful, restarting script..."
            sleep 3
            
            exec "$path_script/$script" "$@"
        fi
    fi

    if [[ ! -f "$path_script/.version" ]] || [[ "$(cat "$path_script/.version")" != "$version" ]]; then
        echo "$version" > "$path_script/.version"
    fi 
}

checkvpk() {
    command_run[vpkeditcli]="$path_vpk/vpkeditcli"

    if [ "$use_steam" -eq 1 ]; then
        if ! command -v "${command_run[vpkeditcli]}" &>/dev/null; then
            notify_steam_error
            exit 1
        fi
        return
    fi
    
    local repo_url="https://api.github.com/repos/craftablescience/VPKEdit/releases/latest"
    local vpkedit_file="${command_run[vpkeditcli]}"
    local timestamp_file="$path_script/.vpkedit"
    local current_time=$(date +%s)

    if [ -f "$vpkedit_file" ] && [ -f "$timestamp_file" ]; then
        local last_modified=$(cat "$timestamp_file")
        if [ -n "$last_modified" ] && [ $((current_time - last_modified)) -lt 604800 ]; then
            return 0
        fi
    fi

    color_msg "white" "Updating 'vpkedit' to latest release...\n" "bold"
    color_msg "green" " https://github.com/craftablescience/VPKEdit\n"

    local latest_url=$("${command_run[curl]}" -sL "$repo_url" | sed -n 's/.*"browser_download_url": *"\([^"]*Linux-Binaries[^"]*\.zip\)".*/\1/p' | head -n 1)

    if [ -z "$latest_url" ]; then
        color_msg "red" "Error: Failed to fetch latest VPKEdit release URL\n" "bold"
        exit 1
    fi

    local filename="${latest_url##*/}"

    "${command_run[curl]}" -sL -o "$filename" "$latest_url" || { exit 1; }
    
    if ! "${command_run[unzip]}" -t "$filename" &>/dev/null; then
        color_msg "red" "Error: Downloaded VPKEdit archive is corrupt\n" "bold"
        rm_file "$filename"
        exit 1
    fi

    "${command_run[unzip]}" -o "$filename" -d "$path_vpk" &>/dev/null
    
    if [ ! -f "$vpkedit_file" ]; then
        color_msg "red" "Error: '$vpkedit_file' not found after unzip.\n" "bold"
        rm_file "$filename"
        exit 1
    fi

    chmod +x "$vpkedit_file"
    rm_file "$filename"
    echo "$current_time" > "$timestamp_file"
}

data_reset() {
    [ ! -d "$path_script" ] && return 1

    local force=$([[ "$1" == "force" ]] && echo 1 || echo 0)

    if [ "$force" -eq 0 ]; then
        color_msg "yellow" "WARNING: This will remove all data except core script files!\n" "bold"
        color_msg "blue" "$(shorten_path "$path_script" "3" "last")\n\n"
        color_msg "white" "Continue with reset? [y/N] " "bold"
    fi

    if [ "$force" -eq 1 ] || [ "$(prompt "n")" -eq 1 ]; then
        local state=0
        local find_args=()
        local keep=(
            "CHANGELOG.md"
            "LICENSE"
            "README.md"
            "lbspcfw.sh"
            "lbspcfw.svg"
            "mod"
        )
        
        for item in "${keep[@]}"; do
            find_args+=( ! -name "$item" )
        done

        find "$path_script" -mindepth 1 -maxdepth 1 \
            "${find_args[@]}" \
            -exec rm -rf {} + || state=1

        if [ "$force" -eq 0 ]; then
            if [ "$state" -eq 0 ]; then
                color_msg "green" " Reset complete! All non-core files have been successfully removed.\n"
            else
                color_msg "red" "Error: Failed to reset script directory!\n" "bold"
                exit 1
            fi

            color_msg "white" "Remove all services? [y/N] " "bold"
            if [ "$(prompt "n")" -eq 1 ]; then
                remove_user_service
            else
                color_msg "green" " Skipping service removal"
            fi

            sleep 2
        fi
    fi
}

docker_create() {
    if ! command -v docker &>/dev/null; then
        color_msg "red" "Error: 'docker' is not installed!\n"
        exit 0
    fi

    if ! docker info >/dev/null 2>&1; then
        color_msg "red" "Error: docker access restricted by your system (root or docker group required)\n"
        exit 0
    fi

    local docker_image="$1"
    local action="$2"

    if [[ "$action" == "rebuild" || "$action" == "remove" ]]; then
        if docker image inspect "$docker_image" >/dev/null 2>&1; then
            docker rmi -f "$docker_image" >/dev/null 2>&1
            if [[ "$action" == "remove" ]]; then
                color_msg "green" "Docker image '$docker_image' has been removed.\n"
                exit 0
            fi
        else
            if [[ "$action" == "remove" ]]; then
                color_msg "yellow" "Docker image '$docker_image' does not exist.\n"
                exit 0
            fi
        fi
    fi

    if ! docker image inspect "$docker_image" >/dev/null 2>&1; then
        cd "$path_script"
        cat > "Dockerfile" <<-'EOF'
        FROM debian:stable
        ENV DEBIAN_FRONTEND=noninteractive

        RUN apt-get update && apt-get install -y --no-install-recommends \
            sudo nano curl git inotify-tools libnotify-bin parallel rsync unzip ca-certificates \
            && apt-get clean && rm -rf /var/lib/apt/lists/*

        WORKDIR /workspace

        ARG USER_UID
        ARG USER_GID
        RUN groupadd -g $USER_GID lbspcfw \
            && useradd -ms /bin/bash -u $USER_UID -g $USER_GID lbspcfw

        COPY lbspcfw.sh /workspace
        COPY mod/ /workspace/mod/

        RUN chown -R lbspcfw:lbspcfw /workspace && chmod -R 775 /workspace

        USER lbspcfw
        ENTRYPOINT [ "/workspace/lbspcfw.sh" ]
		EOF

        local uid gid
        uid=$(id -u); [ "$uid" -eq 0 ] && uid=1000
        gid=$(id -g); [ "$gid" -eq 0 ] && gid=1000

        show_logo
        color_msg "white" "Building Docker Image..."
        docker build --no-cache --network=host --build-arg USER_UID="$uid" --build-arg USER_GID="$gid" --tag "$docker_image" . >/dev/null 2>&1

        rm_file "$path_script/Dockerfile"
    fi
}

docker_run() {
    local docker_container="lbspcfw-docker"
    local uid gid
    uid=$(id -u); [ "$uid" -eq 0 ] && uid=1000
    gid=$(id -g); [ "$gid" -eq 0 ] && gid=1000
    
    local act=""
    [[ "$use_docker" -eq 2 ]] && act="rebuild"
    [[ "$use_docker" -eq 3 ]] && act="remove"

    docker_create "$docker_container" "$act"

    use_docker=1

    if docker image inspect "$docker_container" >/dev/null 2>&1; then
        color_msg "blue" "\nRunning containerized..."
        sleep 2    
        local selinux_context=$(checkselinux)
        docker run --interactive --tty --rm \
            --user "$uid:$gid" \
            --volume "${path_steam%/*/*}":/home/lbspcfw/.local/share/Steam$selinux_context \
            --env IN_DOCKER=1 \
            $docker_container
        sleep 2
    else
        color_msg "red" "\nError: unable to start docker container '$docker_container'\n"
    fi
    
    exit 0
}

env_prepare() {
    color_msg "green" "Preparing Environment...\n" "bold"

    local path_root

    [ "$use_steam" -eq 1 ] && path_root="steam/${path_game##*/}"
    [ "$use_service" -eq 1 ] && path_root="service/${path_game##*/}"
    [ "$use_service" -ne 1 ] && [ "$use_steam" -eq 0 ] && path_root="process/${path_game##*/}"
    path_temp="$path_temp/$path_root"
    path_log="$path_log/$path_root"

    rm_dir "$path_temp/"
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
    mk_dir "$path_temp"
    mk_dir "$path_log"

    temp_setup "$path_game/download/maps"
}

env_cleanup() { 
    local mutex="${path_temp}-cleanup.lock"
    
    mkdir "$mutex" 2>/dev/null || return
    trap - SIGTERM SIGINT EXIT

    if [[ $use_monitor -eq 2 ]]; then
        if [[ $use_service -eq 0 && $use_steam -eq 0 ]]; then
            color_msg "white" "\nStopped Monitor\n"
            color_msg "bgreen" "=> $bsp_processed maps processed, monitor active $(process_time)\n\n" "bold"
        elif [[ $use_steam -eq 1 ]]; then
            notify "Steam Monitor Stopped"
        else
            notify "Stopped Monitor for '$game_name'"
        fi
    fi

    pkill -P $$ 2>/dev/null
    rm_dir "$path_temp/" 2>/dev/null

    [ "$use_docker" -eq 0 ] && game_freeze "disable"
    [[ "$use_service" -eq 1 || "$use_steam" -eq 1 ]] && { rm_dir "$mutex" 2>/dev/null; exit 0; }

    color_msg "cyan" "Thank you for using LBSPCFW!\n" "bold"
    color_msg "cyan" "If you found it useful, please consider sharing & supporting further development.\n"
    color_msg "green" " > "; color_msg "green" "https://help.scorpex.org/?s=git\n\n" "underline"

    tput cnorm 2>/dev/null
    stty echoctl 2>/dev/null

    rm_dir "$mutex" 2>/dev/null

    exit 0
}

process_update() {
    local -r version_file="$path_script/.version"
    local version_migrate
    
    if [[ -f "$version_file" ]]; then
        version_migrate=$(head -n 1 "$version_file" | tr -d '\r')
    else
        version_migrate="legacy"
    fi

    case "$version_migrate" in
        "legacy" | *)
            data_reset "force"
            ;;
    esac

    color_msg "bblue" "Applying $version_migrate updates...\n"

    echo "$version" > "$version_file"
}

temp_setup() {
    [ ! -d "$1" ] && { color_msg "red" "Error: '$1' is an invalid path; no dataset size estimate available.\n"; exit 1; }

    local candidates=("/tmp" "$path_temp")
    local tmp_dir=""
    local dataset_estimate
    local avail
    local prefix=""
    local bsp_unpacked=1.7
    local tmp_pad=1.15

    dataset_estimate=$(find "$1" -type f -iname '*.bsp' -printf '%s\n' \
                    | sort -nr | head -5 \
                    | awk -v m="$bsp_unpacked" -v p="$tmp_pad" \
                            '{sum+=$1} END {print int(sum*m*p/1024)}')

    #echo "Estimated max temp space needed (KB): $dataset_estimate"

    for base in "${candidates[@]}"; do
        [[ ! -d "$base" || ! -w "$base" ]] && continue

        avail=$(df --output=avail "$base" | tail -1)
        if [ "$avail" -gt "$dataset_estimate" ]; then
            [[ "$base" == "/tmp" ]] && prefix="lbspcfw-"
            tmp_dir=$(mktemp -d --tmpdir="$base" "${prefix}XXXXXX")
            break
        fi
    done

    if [[ -z "$tmp_dir" || ! -d "$tmp_dir" || ! -w "$tmp_dir" ]]; then
        color_msg "red" "Error: A valid, writable temporary directory is required.\n"
        color_msg "yellow" "Check if '$tmp_dir' is set, exists, and has write permissions.\n\n"
        exit 1
    fi

    path_temp="$tmp_dir"
}

undo_sync() {
    
    local mode="${1:-precise}" 
    local sync_file="$path_undo/undo.dat"
    local sync_file_tmp="${sync_file}.tmp"

    trap 'rm_file "$sync_file_tmp"; echo -ne "\n\n"; env_cleanup' SIGTERM EXIT

    if [[ ! -f "$sync_file" ]]; then
        color_msg "yellow" " No sync file found to revert.\n"
        trap - EXIT
        exit 0
    fi

    if [[ "$mode" == "recurse" ]]; then
        color_msg "yellow" "Reverting Asset Folders (Recurse Mode)\n" "bold"
    else
        color_msg "green"  "Reverting Files (Precise 1:1 Mode)\n" "bold"
    fi

    color_msg "blue" " > Reading last sync data...\n" "bold"
    
    if [[ "$mode" == "recurse" ]]; then
        while read -r line || [[ -n "$line" ]]; do
            printf "%b\0" "${line//\\#/\\}"
        done < "$sync_file" | \
        LC_ALL=C grep -zE "/(materials|models|sound)/" | \
        LC_ALL=C sed -zE 's|(.*/(materials\|models\|sound)/[^/]+)/.*|\1|' | \
        LC_ALL=C sort -uzr > "$sync_file_tmp"
    else
        # FUTURE SCALE FIX: If while loop is slow, use:
        # sed 's/\\#/\\/g' "$sync_file" | xargs -I {} printf "%b\0" {} | \
        # LC_ALL=C grep -zE "/(materials|models|sound)/" | \
        # LC_ALL=C sort -uzr > "$sync_file_tmp"

        while read -r line || [[ -n "$line" ]]; do 
            printf "%b\0" "${line//\\#/\\}"
        done < "$sync_file" | \
        LC_ALL=C grep -zE "/(materials|models|sound)/" | \
        LC_ALL=C sort -uzr > "$sync_file_tmp"
    fi

    local total_items=$(tr -dc '\0' < "$sync_file_tmp" | wc -c)

    if [[ "$total_items" -eq 0 ]]; then
        color_msg "yellow" " No entries found to process.\n" "bold"
        rm_file "$sync_file"
        rm_file "$sync_file_tmp"
        trap - EXIT
        exit 0
    fi

    color_msg "white" " Found $total_items items to remove. Continue [y/N]? " "bold"
    if [ $(prompt "n") -eq 0 ]; then
        color_msg "red" "Revert aborted\n"
        rm_file "$sync_file_tmp"
        trap - EXIT
        exit 0
    fi

    color_msg "cyan" " > Reverting assets, please wait...\n\n"

    LC_ALL=C xargs -0 -a "$sync_file_tmp" -n100 -P 8 bash -c '
        target_mode="'"$mode"'"
        for item in "$@"; do
            [[ ! -e "$item" && ! -L "$item" ]] && continue
            
            if [[ "$target_mode" == "recurse" ]]; then
                rm -rf "$item"
            else
                if [[ -f "$item" || -L "$item" ]]; then
                    rm -f "$item"
                elif [[ -d "$item" ]]; then
                    rmdir "$item" 2>/dev/null
                fi
            fi
        done
    ' --

    local root_path=$(LC_ALL=C grep -m 1 -o '.*download' "$sync_file")
    if [[ -d "$root_path" ]]; then
        for sub in materials models sound; do
            if [[ -d "$root_path/$sub" ]]; then
                LC_ALL=C find "$root_path/$sub" -mindepth 1 -type d -empty -delete
            fi
        done
    fi

    rm_file "$sync_file"
    rm_file "$sync_file_tmp"
    
    color_msg "green" "Done!" "bold"
}