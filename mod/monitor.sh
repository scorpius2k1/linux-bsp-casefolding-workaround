game_monitor() {
    local ext="bsp"
    local dir="$path_bsp"
    local log="$path_log/monitor.log"
    local notify_popup

    use_monitor=2
    bsp_processed=0
    mk_dir "$path_temp"

    export path_vpkcli="${command_run[vpkeditcli]}"
    export path_rsync="${command_run[rsync]}"

    [[ ${use_service:-0} -eq 1 || ${use_steam:-0} -eq 1 ]] && notify_popup=1

    if [ "$use_service" -eq 0 ] && [ "$use_steam" -eq 0 ]; then
        color_msg "white" "Monitoring '$game_name' for new maps (CTRL+C to abort)...\n" "bold"
    fi

    if [ -n "$steam_pid" ] && [ "$steam_pid" -gt 0 ]; then
        while true; do
            ! kill -0 "$steam_pid" 2>/dev/null && env_cleanup
            sleep 1
        done &
    fi

    local -A hash_seen
    if [ -f "$path_hash" ]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && hash_seen["$line"]=1
        done < "$path_hash" 2>/dev/null
    fi

    trap '{ env_cleanup; }' SIGINT
    process_time "start"

    export hash_parallel="$path_hash"


    local -A processing
    while read -r fullpath
    do
        local bsp="${fullpath##*/}"
        [[ "${bsp,,}" != *.${ext} ]] && continue

        local current_time=$(date +%s)
        local last_time=${processing[$bsp]:-0}

        (( current_time - last_time < 5 )) && continue
        
        processing[$bsp]=$current_time

        local size=$(stat -c%s "$fullpath" 2>/dev/null || echo 0)
        while [ "$size" -eq 0 ]; do
            sleep 0.1
            size=$(stat -c%s "$fullpath" 2>/dev/null || echo 0)
        done

        color_msg "blue" " $(date) Processing \033[36m${bsp%.*}... " "bold" || echo

        if game_freeze process_bsp "$fullpath" >> "$log" 2>&1; then
            [ "${notify_popup:-0}" -eq 0 ] && color_msg "green" "DONE\n" "bold" || notify "Processed $bsp"            
        else
            [ "${notify_popup:-0}" -eq 0 ] && color_msg "red" "FAILED\n" || notify "Failed processing $bsp"
        fi

    done < <(inotifywait --quiet --monitor --format '%w%f' -e close_write "$dir") #& loop_pid=$!
    #wait "$loop_pid"
}

game_freeze() {
    [[ -z "$path_game" || -z "$game_name" ]] && return 1
    local cmd="$1"
    shift 
    
    local path_root="${path_game%%$game_name*}$game_name"
    [[ -z "$path_root" || ! -d "$path_root" ]] && return 1

    local current_user="${USER:-$(whoami)}"

    local pid_inotify=$(pgrep -u "$current_user" -f "inotifywait.*$path_root" 2>/dev/null | grep -vE "^($$|$PPID)$")
    local pids_game=$(pgrep -u "$current_user" -f "$path_root" 2>/dev/null | grep -vE "^($$|$PPID|${pid_inotify:-0})$")
    
    if [[ "$cmd" == "disable" ]]; then
        [[ -n "$pids_game" ]] && kill -CONT $pids_game 2>/dev/null
        return 0
    fi

    if [[ -n "$pids_game" ]]; then
        kill -STOP $pids_game 2>/dev/null
        ( sleep 3; kill -CONT $pids_game 2>/dev/null ) & disown
    fi

    "$cmd" "$@" 
    return $?
}