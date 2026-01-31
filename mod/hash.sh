hash_create() {
    local f="$1"
    [[ ! -e "$f" ]] && return 1

    local info
    if [[ -d "$f" ]]; then
        info="$f"
    elif [[ -L "$f" ]]; then
        info="$f|$(readlink -f "$f")|$(stat -c "%s %Y" "$f" 2>/dev/null)"
    else
        info="$f|$(stat -c "%s %Y" "$f" 2>/dev/null)|$(head -c 1048576 "$f" 2>/dev/null | sha1sum | cut -d' ' -f1)"
    fi

    printf '%s' "$info" | sha1sum | cut -d' ' -f1
}

hash_check() {
    [[ "${skip_processed:-0}" -eq 0 ]] && return 1

    local filename="$2"
    local hash

    hash=$(hash_create "$filename") || return 1
    if grep -qFx "$hash" "$hash_parallel" 2>/dev/null; then
        echo "$hash"
        return 0
    fi

    return 1
}