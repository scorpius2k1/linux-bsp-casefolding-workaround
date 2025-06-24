process_parallel() {
    local bsp="$1"
    local bsp_name="${bsp##*/}"
    local matched_hash

    eval "$hash_parallel"

    echo "=> Processing $bsp" >&2
    if [ "$skip_processed" -eq 1 ] && matched_hash=$(hash_check hash_seen "$bsp"); then
        echo "Skipping $bsp_name, previously processed ($matched_hash)" >&2
        echo "SKIPPED: $bsp"
    elif "$path_vpkcli" --no-progress --output "$path_data" --extract / "$bsp" 2> "$path_log/${bsp_name}.log"; then
        echo "Extraction succeeded for $bsp_name" >&2
        local -a dirs
        materials="$path_data/${bsp_name%.*}/materials"
        models="$path_data/${bsp_name%.*}/models"
        sound="$path_data/${bsp_name%.*}/sound"
        [[ -d "$materials" ]] && dirs+=("$materials")
        [[ -d "$models" ]] && dirs+=("$models")
        [[ -d "$sound" ]] && dirs+=("$sound")
        [ ${#dirs[@]} -gt 0 ] && { "$path_rsync" --quiet -aAHX "${dirs[@]}" "$path_sync"; echo "Successfully synchronized extracted data for $bsp_name" >&2; }
        echo "Completed processing for $bsp_name" >&2
        rm_file "$path_log/${bsp_name}.log"
        hash=$(hash_create "$bsp")
        echo "HASH: $hash"
        echo "SUCCESS: $bsp"
    else
        echo "Failed extraction for $bsp_name" >&2
        echo "FAILED: $bsp"
    fi
}

process_bsp() {
    local -i cursor_index=0
    local -i max_jobs=$(( $(nproc) / 2 ))
    local -a cursors=("/" "-" "\\" "|")
    local -A hash_seen
    local hash_parallel=""

    export path_vpkcli="${command_run[vpkeditcli]}"
    export path_rsync="${command_run[rsync]}"
    export path_data="$path_data"
    export path_sync="$path_sync"
    export path_log="$path_log"
    export path_hash="$path_hash"

    export -f process_parallel

    local fifo=$(mktemp -u)
    mkfifo "$fifo"
    trap 'rm -f "$fifo"' SIGINT EXIT

    if [ -f "$path_hash" ]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && hash_seen["$line"]=1
        done < "$path_hash" 2>/dev/null
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

    "${command_run[parallel]}" --tmpdir "$path_data" --jobs $max_jobs --line-buffer --keep-order --quote process_parallel ::: "${bsp_files[@]}" > "$fifo" 2> "$path_log/process.log" &
    local parallel_pid=$!

    while IFS= read -r result || [ -n "$result" ]; do
        state=0
        if [[ "$result" =~ ^SUCCESS:\ (.+)$ ]]; then
            state=0
        elif [[ "$result" =~ ^SKIPPED:\ (.+)$ ]]; then
            state=1
        elif [[ "$result" =~ ^FAILED:\ (.+)$ ]]; then
            state=2
        elif [[ "$result" =~ ^HASH:\ (.+)$ ]]; then
            hash="${BASH_REMATCH[1]}"
            [ -z "${hash_seen[$hash]}" ] && { hash_seen["$hash"]=1; echo "$hash" >> "$path_hash"; }
            continue
        else
            continue
        fi

        bsp="${BASH_REMATCH[1]}"
        local cursor="${cursors[cursor_index]}"
        local bsp_name="${bsp##*/}"
        ((cursor_index = (cursor_index + 1) % 4))
        ((bsp_processed++))

        if [ "$state" -eq 0 ]; then
            color_msg "blue" "\r\033[K [$cursor] Processing $bsp_processed/$bsp_total ($((bsp_processed * 100 / bsp_total))%%) \033[36m${bsp_name%.*}..." "bold"
        elif [ "$state" -eq 1 ]; then
            color_msg "blue" "\r\033[K [$cursor] Processing $bsp_processed/$bsp_total ($((bsp_processed * 100 / bsp_total))%%) \033[35mSkipping ${bsp_name%.*} (already processed)..." "bold"
        elif [ "$state" -eq 2 ]; then
            color_msg "yellow" "Warning: Failed to extract '$bsp_name', skipping. Check error log at $path_log/${bsp_name}.log"
            sleep 1
        fi
    done < "$fifo"

    wait "$parallel_pid"
    printf "\n"

    rm -f "$fifo" || { color_msg "yellow" "Warning: Failed to remove $fifo" "bold"; }
    clear_cache "$path_game"

    trap 'env_cleanup' SIGINT
    trap 'env_exit' EXIT
}

process_bsp_single() {
    local bsp_name="$1"
    local data_path="$2"    
    local materials="$data_path/materials"
    local models="$data_path/models"
    local sound="$data_path/sound"

    "${command_run[rsync]}" --quiet -aAHX $([ -d "$materials" ] && echo "$materials") $([ -d "$models" ] && echo "$models") $([ -d "$sound" ] && echo "$sound") "$path_sync"
    
    hash=$(hash_create "$path_bsp/$bsp_name")
    [ -z "${hash_seen[$hash]}" ] && { hash_seen["$hash"]=1; echo "$hash" >> "$path_hash"; }
    [ "$use_service" -eq 0 ] && [ "$use_steam" -eq 0 ] && color_msg "green" "Done!\n" "bold" || notify "Processed ${bsp_name%.*}"
    ((bsp_processed++))
    
    echo "$(date) Successfully extracted & synchronized extracted data for $bsp_name ($hash)" >> "$log"    
}
