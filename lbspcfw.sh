#!/usr/bin/env bash
# set -euo pipefail
#
# Info    : Workaround for case folding issues for BSP map files with custom assets in Steam games on Linux
# Author  : Scorp (https://github.com/scorpius2k1)
# Repo    : https://github.com/scorpius2k1/linux-bsp-casefolding-workaround
# License : https://www.gnu.org/licenses/gpl-3.0.en.html#license-text
#
[ "${BASH_VERSINFO[0]}" -lt 4 ] && { echo "Error: Bash 4+ required"; exit 1; }

exec 9<"$0"
flock -n 9 || { echo "${0##*/} is already running."; exit 0; }

readonly script="lbspcfw.sh"
readonly version="1.05"
readonly logo="$(cat <<EOF
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

declare dependencies=(curl inotifywait notify-send parallel rsync unzip)
declare path_script="$(dirname "$(realpath "$0")")"
declare script_name="${0##*/}"
declare path_bsp="$path_script/bsp"
declare path_cfg="$path_script/.cfg"
declare path_temp="$path_script/.tmp"
declare path_hash="$path_script/.hash"
declare path_log="$path_script/log"
declare path_mod="$path_script/mod"
declare path_sync="$path_script/fix"
declare path_vpk="$path_script/vpk"
declare path_undo="$path_script/.undo"
declare path_game=""
declare path_steam=""
declare game_name=""
declare -i autodetect=0
declare -i bsp_processed=0
declare -i bsp_total=0
declare -i skip_processed=0
declare -i steam_pid=0
declare -i time_start=0
declare -i use_config=0
declare -i use_monitor=0
declare -i use_service=0
declare -i use_steam=0
declare -i use_popup=1
declare -i use_docker=0
declare -i use_reset=0
declare -i use_purge=0
declare -i use_undo=0
declare -a steamexternal
declare -A command_run
declare -A color_codes=(
    ["red"]="\033[31m"
    ["green"]="\033[32m"
    ["yellow"]="\033[33m"
    ["blue"]="\033[34m"
    ["magenta"]="\033[35m"
    ["cyan"]="\033[36m"
    ["white"]="\033[37m"
    ["black"]="\033[30m"
    ["bred"]="\033[91m"
    ["bgreen"]="\033[92m"
    ["byellow"]="\033[93m"
    ["bblue"]="\033[94m"
    ["bmagenta"]="\033[95m"
    ["bcyan"]="\033[96m"
    ["bwhite"]="\033[97m"
    ["red bg"]="\033[41m"
    ["green bg"]="\033[42m"
    ["yellow bg"]="\033[43m"
    ["blue bg"]="\033[44m"
)

[ ! -s "$path_script/$script" ] && { echo "Error: '$script' missing or invalid."; exit 1; }

modules=()
for f in "$path_mod"/*.sh; do
    [ -f "$f" ] && modules+=("$f")
done
[ "${#modules[@]}" -gt 0 ] || { echo "Error: No modules found in $path_mod" >&2; exit 1; }
for module in "${modules[@]}"; do
    source "$module" || { echo "Error: Failed to source $module" >&2; exit 1; }
done

[ "$(uname)" != "Linux" ] && { color_msg "yellow" "Your Operating System '$(uname)' may not work properly with this script!\n\n"; sleep 2; }
[ -z "$TERM" ] && export TERM="xterm"

checkargs "$@"

if [[ $EUID -eq 0 ]]; then
    if [[ ! -f "$path_script/.version" ]]; then
        color_msg "red" "Error: Unable to initialize script environment as the root/sudo user.\n"
        exit 0
    elif [[ "$use_docker" -eq 0 ]]; then
        color_msg "red" "Error: Unable to run this script as the root/sudo user.\n"
        exit 0
    fi
fi

show_logo

checkdeps
checkpaths
checkupdate
checkdocker
checkvpk

trap 'printf "\n\n"; env_cleanup' SIGINT
trap 'env_cleanup' SIGTERM EXIT

if [ "$use_service" -eq 1 ]; then
    if [ ! -d "$2" ]; then
        if [ "$(checkconfig 1)" -ne 0 ]; then
            use_service=0
            show_logo 1
            color_msg "white" "Create service\n\n" "bold"
            checkconfig
            printf '\n'
            game_title="${path_game##*/}"
            create_user_service "lbspcfw-$game_title" "--service" "${path_game%/*}"
        else
            color_msg "red" "Error: No configurations found.\nTo configure a service, first process a game by executing this script in standard mode.\n"
            exit 0
        fi
    else
        path_game="$2"
        if [ -d "$path_game" ]; then
            game_name="${path_game##*/common/}"
            path_game=$(game_folder "$path_game")
            path_hash="$path_hash/$game_name"
            env_prepare
            path_hash="$path_hash/hash.dat"
            use_monitor=1
            notify "Monitoring '$game_name'"
        fi
    fi
elif [ "$use_steam" -eq 1 ]; then
    rm_file "$path_log/steam.log"
    command "$@" >> "$path_log/steam.log" 2>&1 &
    steam_pid=$!
    path_game=$(dirname "$(printf '%s ' "$@" | sed 's/^.* -- //')")
    if [ -d "$path_game" ] && [ "$steam_pid" -gt 0 ]; then
        game_name="${path_game##*/common/}"
        path_game=$(game_folder "$path_game")
        path_hash="$path_hash/$game_name"
        [ -n "$path_game" ] && systemctl --user is-active "lbspcfw-${path_game##*/}" >/dev/null 2>&1 && { notify "Steam Monitor disabled. Service monitor already active for $game_name"; exit 1; }
        env_prepare
        path_hash="$path_hash/hash.dat"
        use_monitor=1
        notify "Steam Monitor Active ($game_name)"
    fi
elif [ "$use_purge" -eq 1 ]; then
    if [ "$(checkconfig 1)" -eq 0 ]; then
        color_msg "yellow" "No configuration presets detected!\n" "bold"
        color_msg "white" "Please run the script in interactive mode to create one.\n\n"
        exit 1
    fi

    checkconfig
    
    if [[ ! -d "$path_game" ]] || \
        [[ -z "$path_game" ]] || \
        [[ "$path_game" == "/" ]] || \
        [[ ${#path_game} -lt 10 ]] || \
        [[ "$path_game" != *"steamapps/common"* ]]; then
        color_msg "red" "Invalid or dangerous game path detected ($path_game)\n" "bold"
        color_msg "red" "Safely aborting.\n"
        exit 1
    fi

    game_name="${path_game##*/common/}" && game_name="${game_name%%/*}"
    color_msg "green" " Game set to '$game_name'\n\n"

    color_msg "yellow" "WARNING: This will purge all custom assets and cache data!\n" "bold"
    color_msg "yellow" "Please ensure a backup is made before proceeding, if necessary.\n\n"
    color_msg "white" "Continue with purge? [y/N] " "bold"

    if [ "$(prompt "n")" != "1" ]; then
        color_msg "red" "Purge aborted\n\n"
        exit 0
    fi

    color_msg "blue" "Purging data...\n"
    path_purge="$path_game/download"

    if [ ! -d "$path_purge" ]; then
        color_msg "red" "Error: Game asset path does not exist at expected location.\n"
        exit 1
    fi

    for sub in materials models sound; do
        target_dir="$path_purge/$sub"
        [[ ! -d "$target_dir" ]] && continue
        
        if ! find "$target_dir" -mindepth 1 -delete 2>/dev/null; then
            color_msg "red" "Warning: unable to purge $sub (check permissions).\n"
        fi
    done

    color_msg "blue" "Clearing cache...\n"
    clear_cache "$path_game"

    color_msg "green" "Done!\n\n" "bold"
elif [ "$use_undo" -gt 0 ]; then
    [ "$use_undo" -eq 1 ] && undo_sync "standard" || undo_sync "recurse"
else
    stty -echoctl 2>/dev/null

    show_logo

    if [ "$use_config" -eq 0 ] && [ "$(checkconfig 1)" -gt 0 ]; then
        color_msg "white" "Use configuration preset? [Y/n] " "bold"
        use_config=$(prompt)
    fi

    if [ "$use_config" -eq 1 ]; then
        checkconfig
        game_name="${path_game##*/common/}" && game_name="${game_name%%/*}"
        color_msg "green" " Game set to '$game_name'\n\n"        
        [ "$autodetect" -eq 0 ] && path_steam="$path_sync" && path_game="$path_steam"
        color_msg "white" "Skip previously processed maps? [Y/n] " "bold"
        skip_processed=$(prompt)
    else
        if [ "$use_docker" -eq 0 ]; then
            color_msg "white" "Attempt to auto-detect game folders/maps? [Y/n] " "bold"
            autodetect=$(prompt)
        else
            autodetect=1
        fi

        if [ "$autodetect" -eq 1 ]; then
            if check_steampath; then
                color_msg "green" " Steam Install Detected\n"
                color_msg "bblue" " ${path_steam}\n"
            else
                autodetect=2
            fi

            if [ "$use_docker" -eq 0 ]; then
                [ "$autodetect" -eq 1 ] && color_msg "white" "\nSearch for additional Steam Libraries? [y/N] " "bold"
                if [ "$autodetect" -eq 2 ] || [ "$(prompt "n")" = "1" ]; then
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

                    autodetect=1
                fi
            fi

            mapfile -t gamepath < <(game_root "$path_steam")
            [ "${#gamepath[@]}" -eq 0 ] && { color_msg "red" "\nNo Steam Libraries found, exiting.\n" "bold"; exit 1; }

            show_logo
            color_msg "white" "Available Games\n"
            for i in "${!gamepath[@]}"; do
                color_msg "bblue" " $((i+1)): ${gamepath[$i]##*/}\n"
            done

            while true; do
                color_msg "white" "\nWhich game to apply workaround (1-${#gamepath[@]}): " "bold"
                read -r choice || exit 1

                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    ((choice--))
                    
                    if [ "$choice" -ge 0 ] && [ "$choice" -lt "${#gamepath[@]}" ]; then
                        path_game=$(game_folder "${gamepath[$choice]}")
                        if [ -n "$path_game" ]; then
                            game_name="${path_game##*/common/}" && game_name="${game_name%%/*}"
                            color_msg "green" " Game set to '$game_name'\n\n"
                            break 
                        else
                            color_msg "red" "Error: Failed to validate game folder.\n" "bold"
                        fi
                    fi
                fi
                color_msg "red" "Invalid choice, please select a number between 1 and ${#gamepath[@]}.\n" "bold"
            done

            path_hash="$path_hash/${gamepath[$choice]##*/}"
        else
            path_steam="$path_sync"
            path_game="$path_steam"
            path_hash="$path_hash/manual"
            color_msg "yellow" " Manual Mode Selected\n"
        fi

        if [ "$use_docker" -eq 0 ]; then
            color_msg "white" "Skip previously processed maps? [Y/n] " "bold"
            skip_processed=$(prompt)
        fi
    fi

    show_logo
    env_prepare

    bsp_files=()
    for f in "$path_bsp"/*.[bB][sS][pP]; do
        [ -f "$f" ] && [[ "${f##*/}" != ".bsp" ]] && bsp_files+=("$f")
    done
    mapfile -t bsp_files < <(printf '%s\n' "${bsp_files[@]}" | sort)

    bsp_total=${#bsp_files[@]}
    path_hash="$path_hash/hash.dat"

    if [ "$bsp_total" -eq 0 ]; then
        color_msg "red" "Error: No Map files (bsp) found in '$path_bsp'\n" "bold"
        exit 1
    else
        color_msg "green" "=> $bsp_total maps found in '$(shorten_path "$path_bsp" "4")'\n"
        color_msg "green" "=> Output Path '$(shorten_path "$path_sync" "3")'\n\n"
        if [[ -d "$path_sync/materials" || -d "$path_sync/models" || -d "$path_sync/sound" ]]; then
            color_msg "yellow" "WARNING: Merging data into existing asset folders!\n" "bold"
            color_msg "yellow" "Please ensure a backup is made before proceeding, if necessary.\n\n"
        fi
        color_msg "white" "Press any key to begin (CTRL+C to abort)..." "bold"
        read -n 1 -s || exit 1
        
        show_logo
        process_time "start"
        process_parallel
        sleep 1
    fi

    color_msg "green" "\nCleaning up...\n\n" "bold"
    rm_dir "$path_temp/"

    color_msg "bgreen" "=> SUCCESS! $bsp_processed Maps Processed in $(process_time)\n" "bold" || { echo "Error processing time" >&2; exit 1; }
    
    if [ "$use_docker" -eq 0 ]; then
        if [ "$autodetect" -eq 0 ]; then
            color_msg "bmagenta" " To apply workaround, move everything from"
            color_msg "white" " '$(shorten_path "$path_steam")/' "
            color_msg "bmagenta" "into desired Steam Game download path\n"
            color_msg "white" " Ex. '../Steam/steamapps/common/Half Life 2/download/'\n\n"
            color_msg "magenta" " >> Data must be copied to game download path (custom folder does not work) <<\n\n"
            saveconfig "$path_cfg" "$path_game" "$autodetect" "$skip_processed" "Manual" "$(hash_create "$path_game")"
        else
            saveconfig "$path_cfg" "$path_game" "$autodetect" "$skip_processed" "$(echo "${path_game##*/common/}" | cut -d'/' -f1)" "$(hash_create "$path_game")"
        fi
    fi
    printf '\n'

    sleep 1

    if [ "$use_service" -eq 2 ]; then
        game_title="${path_game##*/}"
        color_msg "white" "Create Service? [Y/n] " "bold"
        [ $(prompt) -eq 1 ] && create_user_service "lbspcfw-$game_title" "--service" "${path_game%/*}"
        
    fi
fi

if [ "$use_monitor" -eq 1 ]; then
    show_logo
    game_monitor
fi