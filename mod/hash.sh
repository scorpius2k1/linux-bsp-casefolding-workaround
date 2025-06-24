hash_check() {
    [[ "$skip_processed" -eq 0 ]] && return 1

    local -n hashes=$1
    local filename="$2"

    [[ -z "$filename" || ! -f "$filename" ]] && return 1

    local hash=$(hash_create "$filename")
    [[ -n "${hashes[$hash]}" ]] && { echo "$hash"; return 0; }

    return 1
}

hash_create() {
    [ -z "$1" ] && return 1
    [ -d "$1" ] && echo "$1" | sha1sum - | cut -d' ' -f1 || stat --format="%d %s %Y %Z %n" "$1" 2>/dev/null | sha1sum - | cut -d' ' -f1
}