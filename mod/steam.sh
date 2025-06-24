game_root() {
    local search_path="${1%/}"
    local -a folders=()

    [ ! -d "$search_path" ] && return 1

    while IFS= read -r -d '' folder; do
        local folder_name="${folder##*/}"
        if [[ -d "$folder" && "$folder" != "$search_path" && ! "${folder_name,,}" =~ proton && ! "${folder_name,,}" =~ steam ]]; then
            folders+=("$folder")
        fi
    done < <(find "$search_path" -maxdepth 1 -type d -print0 2>/dev/null)

    [ ${#folders[@]} -eq 0 ] && return 1

    printf '%s\n' "${folders[@]}" | sort
}

game_folder() {
    local root_path="${1%/}"
    [ ! -d "$root_path" ] && { printf "Error: '%s' is not a valid directory\n" "$root_path" >&2; return 1; }

    local -a validate=("cfg" "maps" "download" "gameinfo.txt")
    local current_parent=""
    declare -A found_items

    while IFS= read -r -d '' item; do
        local parent="${item%/*}"
        local item_name="${item##*/}"

        if [ "$parent" != "$current_parent" ]; then
            if [ -n "$current_parent" ]; then
                local all_found=1
                for target in "${validate[@]}"; do
                    [ -z "${found_items[$target]}" ] && { all_found=0; break; }
                done
                [ "$all_found" -eq 1 ] && { printf '%s\n' "$current_parent"; return 0; }
            fi
            declare -A found_items
            current_parent="$parent"
        fi

        if [ "$parent" = "$current_parent" ]; then
            for target in "${validate[@]}"; do
                if [ "${item_name,,}" = "${target,,}" ]; then
                    [ -e "$item" ] && found_items["$target"]=1
                    break
                fi
            done
        fi
    done < <(find "$root_path" -maxdepth 2 -print0 2>/dev/null)

    if [ -n "$current_parent" ]; then
        local all_found=1
        for target in "${validate[@]}"; do
            [ -z "${found_items[$target]}" ] && { all_found=0; break; }
        done
        [ "$all_found" -eq 1 ] && { printf '%s\n' "$current_parent"; return 0; }
    fi

    return 1
}

check_steampath() {
    local steamroot=(
        "$HOME/.steam/debian-installation/steamapps/common"
        "$HOME/.local/share/Steam/steamapps/common"
        "$HOME/.steam/steam/steamapps/common"
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common"
        "$HOME/snap/steam/common/.local/share/Steam/steamapps/common"
    )

    for path in "${steamroot[@]}"; do
        if [ -d "$path" ]; then
            path_steam="$path"
            return 0
        fi
    done

    return 1
}

find_steam_libraries() {
    local array_name="$1"
    [ -z "$array_name" ] && return 1

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
        [ -n "$(find "$path" -maxdepth 1 -type d -not -path "$path" 2>/dev/null)" ] && eval "$array_name+=(\"$path\")"
    done
}

clear_cache() {
    [ -d "$1" ] && find "$1" -name "*.cache" -type f -delete 2>/dev/null && return 0 || return 1
}
