game_monitor() {
    local ext="bsp"
    local dir="$path_bsp"
    local log="$path_log/monitor.log"

    use_monitor=2
    bsp_processed=0
    mk_dir "$path_data"

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

    process_time "start"

    inotifywait -q -m "$dir" -e moved_to -e close_write --format '%e %f' --include "\.${ext}$" |
        while IFS=' ' read -r event filename; do
            if [[ "${filename,,}" == *.${ext} ]]; then
                
                local bsp="$filename"
                game_process "freeze"

                "${command_run[rsync]}" --quiet -aAHX "$dir/$bsp" "$path_data"
                [ "$use_service" -eq 0 ] && [ "$use_steam" -eq 0 ] && color_msg "blue" " $(date) Processing \033[36m${bsp%.*}..." "bold"

                if "${command_run[vpkeditcli]}" --no-progress --output "$path_data" --extract / "$path_data/$bsp" >> "$log" 2>&1; then
                    process_bsp_single "$bsp" "$path_data/${bsp%.*}"
                    sleep 3
                else
                    color_msg "red" "Failed to process $bsp\n"
                fi

		rm_dir "$path_data/"
                game_process "unfreeze"
            fi
        done &
    wait "$!"
}

game_monitor_nodep() {
    local dir="$path_bsp"
    local ext="bsp"
    local max_wait=300
    local required_stable=3
    local max_iterations=$(( max_wait * 100 ))
    local log="$path_log/monitor.log"
    local stat_size_cmd="stat -c %s"
    local init=0

    [ -z "$path_sync" ] && exit 1
    [ ! -d "$dir" ] && { color_msg "red" "Error: Directory $dir does not exist\n"; exit 1; }

    if [ "$use_service" -eq 0 ] && [ "$use_steam" -eq 0 ]; then
        color_msg "white" "Monitoring '${path_game##*/common/}' for new maps (CTRL+C to abort)...\n" "bold"
        game_process && color_msg "green" "Map processing will activate automatically on game launch\n"
    fi

    local -A hash_seen
    if [ -f "$path_hash" ]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && hash_seen["$line"]=1
        done < "$path_hash" 2>/dev/null
    fi

    local previous_maps_sorted=""
    use_monitor=2
    bsp_processed=0
    process_time "start"

    while true; do
        [ "$use_steam" -eq 0 ] && game_process && { sleep 5; continue; } || { [ -n "$steam_pid" ] && [ "$steam_pid" -gt 0 ] && ! kill -0 "$steam_pid" 2>/dev/null && break; }

        local current_maps=$(find "$dir" -maxdepth 1 -type f -name "*.$ext" 2>/dev/null || { color_msg "red" "Error: Cannot access directory $dir\n"; exit 1; })
        local current_maps_sorted=$(echo "$current_maps" | sort)
        [ "$init" -eq 0 ] && previous_maps_sorted="$current_maps_sorted" && init=1

        local new_maps=$(comm -13 <(echo "$previous_maps_sorted") <(echo "$current_maps_sorted"))

        if [ -n "$new_maps" ]; then
            mk_dir "$path_data"

            while read -r bsp; do
                local bsp_name="${bsp##*/}"
                if [ "$skip_processed" -eq 1 ]; then
                    local hash
                    hash=$(hash_create "$bsp") || continue
                    [ -n "${hash_seen[$hash]}" ] && {
                        color_msg "blue" "\033[35mSkipping ${bsp_name%.*} (already processed)\n" "bold"
                        echo "$(date) Skipped $bsp_name: Skipping ${bsp_name%.*} (already processed)" >> "$log"
                        continue
                    }
                fi

                local initial_size current_size stable_count=0
                local start_time=$(date +%s)
                local iterations=0
                local last_mtime current_mtime
                initial_size=$($stat_size_cmd "$bsp" 2>/dev/null) || { echo "$(date) Initial stat failed for $bsp_name" >> "$log"; color_msg "yellow" "Skipped $bsp_name: stat failed!\n"; continue; }
                last_mtime=$(stat -c %Y "$bsp" 2>/dev/null) || { echo "$(date) Initial mtime stat failed for $bsp_name" >> "$log"; color_msg "yellow" "Skipped $bsp_name: stat failed!\n"; continue; }
                while true; do
                    sleep 0.01
                    current_size=$($stat_size_cmd "$bsp" 2>/dev/null) || { echo "$(date) Current stat failed for $bsp_name" >> "$log"; color_msg "yellow" "Skipped $bsp_name: stat failed!\n"; continue 2; }
                    current_mtime=$(stat -c %Y "$bsp" 2>/dev/null) || { echo "$(date) Current mtime stat failed for $bsp_name" >> "$log"; color_msg "yellow" "Skipped $bsp_name: stat failed!\n"; continue 2; }
                    if [[ -n "$initial_size" && -n "$current_size" && "$initial_size" = "$current_size" && -n "$last_mtime" && -n "$current_mtime" && "$last_mtime" = "$current_mtime" ]]; then
                        ((stable_count++))
                        [[ $stable_count -ge $required_stable ]] && break
                    else
                        stable_count=0
                        initial_size=$current_size
                        last_mtime=$current_mtime
                    fi
                    ((iterations++))
                    if [[ $iterations -ge $max_iterations ]]; then
                        echo "$(date) Skipped $bsp_name: initial_size=$initial_size, current_size=$current_size, stable_count=$stable_count, elapsed=$(( $(date +%s) - start_time ))s" >> "$log"
                        color_msg "yellow" "Skipped $bsp_name: unstable after ${max_wait}s!\n"
                        continue 2
                    fi
                done
                if [[ -z "$initial_size" || -z "$current_size" || $stable_count -lt $required_stable ]]; then
                    echo "$(date) Skipped $bsp_name: initial_size=$initial_size, current_size=$current_size, stable_count=$stable_count, elapsed=$(( $(date +%s) - start_time ))s" >> "$log"
                    color_msg "yellow" "Skipped $bsp_name: unstable or stat failed!\n"
                    continue
                fi

                game_process "freeze"
                "${command_run[rsync]}" --quiet -aAHX "$bsp" "$path_data"

                [ "$use_service" -eq 0 ] && [ "$use_steam" -eq 0 ] && color_msg "blue" " $(date) Processing \033[36m${bsp_name%.*}..." "bold"
                if "${command_run[vpkeditcli]}" --no-progress --output "$path_data" --extract / "$path_data/$bsp_name" >> "$log" 2>&1; then
                    process_bsp_single "$bsp_name" "$path_data/${bsp_name%.*}"
                    sleep 3
                else
                    color_msg "red" "Failed to process $bsp_name\n"
                fi

                game_process "unfreeze"
            done < <(echo "$new_maps")

            rm_dir "$path_data/"
            
        fi

        previous_maps_sorted="$current_maps_sorted"
        sleep 0.25
    done
}

game_process() {
    [ -z "$path_game" ] && return

    local search_string="${path_game%/*}/"
    local action="$1"

    search_string="${search_string//\/\///}"
    search_string="${search_string##*/steamapps/}"

    local exclude="reaper\|steam-runtime|${0##*/}"

    if [ -z "$action" ]; then
        local matches
        matches=$(ps -eLo pid,tid,cmd | grep -F "$search_string" | grep -E "${search_string}[^/ ]+[^.][^- ]*" | grep -v "/bin/bash" | grep -v "$exclude" | grep -v grep)
        local count
        [ -z "$matches" ] && count=0 || count=$(echo "$matches" | awk '{print $2}' | sort -u | wc -l)
        [ "$count" -ge 2 ] && return 1
        return 0
    elif [ "$action" = "freeze" ] || [ "$action" = "unfreeze" ]; then
        local pids
        pids=$(ps -eLo pid,cmd | grep -F "$search_string" | grep -E "${search_string}[^/ ]+[^.][^- ]*" | grep -v "/bin/bash" | grep -v "$exclude" | grep -v grep | awk '{print $1}' | sort -u)
        if [ -n "$pids" ]; then
            for pid in $pids; do
                [ "$action" = "freeze" ] && kill -STOP "$pid" || kill -CONT "$pid"
            done
        fi
    fi

}
