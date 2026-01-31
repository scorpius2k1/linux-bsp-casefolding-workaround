process_bsp() {
    local bsp="$1"
    local is_parallel="${2:-0}"
    [[ ! -f "$bsp" ]] && return 1

    local bsp_name="${bsp##*/}"

    local hash
    hash=$(hash_create "$bsp") || return 1

    if [[ "$skip_processed" -eq 1 ]]; then
        if grep -qFx "$hash" "$hash_parallel" 2>/dev/null; then
            echo "Skipping '$bsp_name', previously processed ($hash)" >&2
            [[ "$is_parallel" -eq 1 ]] && echo "SKIPPED: $bsp"
            return 0
        fi
    fi

    echo "Processing '$bsp'" >&2

    local job_tmp
    job_tmp=$(mktemp -d --tmpdir="$path_temp" bsp.XXXXXX) || {
        echo "Error: Failed to create temp directory" >&2
        return 1
    }

    if ! "$path_vpkcli" --no-progress --output "$job_tmp" --extract / "$bsp" >/dev/null 2>&1; then
        echo "Failed extraction for '$bsp_name'" >&2
        [[ "$is_parallel" -eq 1 ]] && echo "FAILED: $bsp"
        rm_dir "$job_tmp"
        return 1
    fi

    echo "Extraction succeeded for '$bsp_name'" >&2

    local bsp_base="${bsp_name%.*}"
    local -a dirs=()
    for sub in materials models sound; do
        [[ -d "$job_tmp/$bsp_base/$sub" ]] && dirs+=("$job_tmp/$bsp_base/$sub")
    done

    if [[ ${#dirs[@]} -gt 0 ]]; then
        local lockfile="$path_temp/rsync.lock"
        local sync_file="$path_undo/undo.dat"
        [[ "$use_steam" -ne 0 ]] && sync_file="/dev/null"

        flock -n "$lockfile" true 2>/dev/null || echo "Waiting for rsync lock: '$bsp_name' is in queue..." >&2
        if ! flock -w 60 "$lockfile" "$path_rsync" \
            -r --8-bit-output --whole-file --delay-updates --out-format="$path_sync/%n" "${dirs[@]}" "$path_sync/" \
            >> "$sync_file" 2>&1; then
                echo "Failed synchronization for '$bsp_name'" >&2
                [[ "$is_parallel" -eq 1 ]] && echo "FAILED: $bsp"
                rm_dir "$job_tmp"
                return 1
        fi
        echo "Successfully synchronized data for '$bsp_name' ($hash)" >&2
    else
        echo "No relevant directories to sync for '$bsp_name' ($hash)" >&2
    fi

    if [[ "$is_parallel" -eq 1 ]]; then
        echo "HASH: $hash"
        echo "SUCCESS: $bsp"
    else
        if [[ -z "${hash_seen[$hash]}" ]]; then
            hash_seen["$hash"]=1
            flock "$path_temp/hash.lock" -c "echo '$hash' >> '$path_hash'"
        fi
        ((bsp_processed++))
    fi

    rm_dir "$job_tmp"
    echo "Cleanup temp '$job_tmp' for '$bsp_name'" >&2
    echo "Completed processing for '$bsp_name'" >&2

    return 0
}

process_parallel() {
    local -i cursor_index=0
    local -a cursors=("/" "-" "\\" "|")

    local -i max_jobs=$(( $(nproc) / 2 ))
    (( max_jobs < 4 )) && max_jobs=4
    (( max_jobs > 6 )) && max_jobs=6

    export path_vpkcli="${command_run[vpkeditcli]}"
    export path_rsync="${command_run[rsync]}"
    export path_temp
    export path_sync
    export path_log
    export path_hash
    export path_undo
    export skip_processed

    export -f process_bsp
    export -f rm_dir
    export -f rm_file
    export -f hash_check
    export -f hash_create

    declare -A hash_seen
    if [ -f "$path_hash" ]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && hash_seen["$line"]=1
        done < "$path_hash"
    fi

    local tmp_hash_cache
    tmp_hash_cache=$(mktemp "$path_temp/hash.XXXXXX") || return 1
    [[ -f "$path_hash" ]] && cp "$path_hash" "$tmp_hash_cache"
    export hash_parallel="$tmp_hash_cache"

    bsp_processed=0
    local last_drawn=-1

    local start_time
    start_time=$(date +%s)

    format_time() {
        local t=$1
        printf '%02d:%02d:%02d' $((t/3600)) $(((t%3600)/60)) $((t%60))
    }

    color_msg "blue" "Initializing..." "bold"
    tput civis
    echo

    trap 'tput cnorm; rm_file "$tmp_hash_cache"; pkill -P $$ 2>/dev/null; printf "\n\n"; env_cleanup; exit 130' SIGINT
    trap 'tput cnorm; rm_file "$tmp_hash_cache"; env_cleanup' EXIT

    mkdir -p "$path_temp/parallel"

    while IFS= read -r result; do
        local state=-1

        if [[ "$result" =~ ^SUCCESS:\ (.+)$ ]]; then
            state=0
        elif [[ "$result" =~ ^SKIPPED:\ (.+)$ ]]; then
            state=1
        elif [[ "$result" =~ ^FAILED:\ (.+)$ ]]; then
            state=2
        elif [[ "$result" =~ ^HASH:\ (.+)$ ]]; then
            local hash="${BASH_REMATCH[1]}"
            if [ -z "${hash_seen[$hash]}" ]; then
                hash_seen["$hash"]=1
                flock "$path_temp/hash.lock" -c "echo '$hash' >> '$path_hash'"
            fi
            continue
        else
            continue
        fi

        local bsp="${BASH_REMATCH[1]}"
        local bsp_name="${bsp##*/}"
        local cursor="${cursors[cursor_index]}"

        ((cursor_index = (cursor_index + 1) % 4))
        ((bsp_processed++))

        if (( bsp_processed != last_drawn )); then
            last_drawn=$bsp_processed
            local now elapsed eta
            now=$(date +%s)
            elapsed=$((now - start_time))
            eta=0
            (( bsp_processed > 0 )) && eta=$(( elapsed * (bsp_total - bsp_processed) / bsp_processed ))

            printf "\033[1A\r\033[K\033[90m[ETA %s | Elapsed %s]\033[0m\n" \
                "$(format_time "$eta")" \
                "$(format_time "$elapsed")"

            if [ "$state" -eq 0 ]; then
                color_msg "blue" \
                    "\r\033[K [$cursor] Processing $bsp_processed/$bsp_total ($((bsp_processed * 100 / bsp_total))%) \033[36m${bsp_name%.*}..." \
                    "bold"
            elif [ "$state" -eq 1 ]; then
                color_msg "blue" \
                    "\r\033[K [$cursor] Processing $bsp_processed/$bsp_total ($((bsp_processed * 100 / bsp_total))%) \033[35mSkipping ${bsp_name%.*}..." \
                    "bold"
            else
                color_msg "yellow" \
                    "\r\033[K [$cursor] Warning: unable to extract '$bsp_name', skipping."
                sleep 1
            fi
        fi
    done < <(
        printf '%s\0' "${bsp_files[@]}" |
            "${command_run[parallel]}" -0 \
                --tmpdir "$path_temp/parallel" \
                --jobs "$max_jobs" \
                --line-buffer \
                process_bsp {} 1 \
                2> "$path_log/process.log"
    )

    [[ -f "$path_hash" ]] && flock "$path_temp/hash.lock" -c "sort -u -o '$path_hash' '$path_hash'"

    rm_file "$tmp_hash_cache"
    clear_cache "$path_game"
}