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
            unset found_items
            declare -A found_items=()
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

    declare -n out="$array_name"
    out=()

    local found=()
    local maxdepth=12
    declare -A scanned_roots=()

    get_lib_root() { dirname "$(dirname "$1")"; }

    local mounts
    local exclude_run=1

    if command -v findmnt >/dev/null 2>&1; then
        mounts=$(findmnt -rn -o TARGET,SOURCE,FSTYPE,OPTIONS | awk '
            $3 !~ /^(tmpfs|proc|sysfs|devtmpfs|cgroup2?|overlay)$/ &&
            $4 !~ /(^|,)ro(,|$)/ {
                if (!seen[$2]++) print $1
            }
        ')
        exclude_run=0
    else
        mounts=$(awk '{print $2}' /proc/mounts)
    fi

    while IFS= read -r mount; do
        case "$mount" in
            /proc*|/sys*|/dev*|/snap*|/var/lib/docker*|/tmp*)
                continue
                ;;
            /run*)
                (( exclude_run )) && continue
                ;;
        esac

        [ -d "$mount" ] || continue
        [[ $EUID -ne 0 && "$HOME" == "$mount"* ]] && continue

        while IFS= read -r path; do
            local lib_root
            lib_root="$(get_lib_root "$path")"
            [[ -n "${scanned_roots["$lib_root"]}" ]] && continue
            scanned_roots["$lib_root"]=1

            found+=("$path")
        done < <(
            find "$mount" \
                -maxdepth "$maxdepth" \
                -type d \
                \( -path "*/.cache" -o -path "*/Trash" -o -path "*/lost+found" \) -prune -o \
                -path "*/steamapps/common" -print \
                2>/dev/null
        )
    done <<< "$mounts"

    while IFS= read -r path; do
        local lib_root
        lib_root="$(get_lib_root "$path")"
        [[ -n "${scanned_roots["$lib_root"]}" ]] && continue
        scanned_roots["$lib_root"]=1

        found+=("$path")
    done < <(
        find "$HOME" \
            -maxdepth "$maxdepth" \
            -type d \
            -path "*/steamapps/common" \
            2>/dev/null
    )

    declare -A seen
    for p in "${found[@]}"; do
        seen["$p"]=1
    done

    local valid=()
    for p in "${!seen[@]}"; do
        if find "$p" -mindepth 1 -maxdepth 1 -type d >/dev/null 2>&1; then
            valid+=("$p")
        fi
    done

    IFS=$'\n' sorted=($(sort <<<"${valid[*]}"))
    unset IFS

    for p in "${sorted[@]}"; do
        out+=("$p")
    done
}

clear_cache() {
    [ -d "$1" ] || return 1
    find "$1" -name "*.cache" -type f -print -quit | grep -q . || return 1
    find "$1" -name "*.cache" -type f -delete 2>/dev/null || return 1
    return 0
}
