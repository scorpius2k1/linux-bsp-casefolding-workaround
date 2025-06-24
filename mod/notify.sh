notify() {
    local title="LBSPCFW"
    local description="$1"
    local icon="$path_script/lbspcfw.svg"

    [ "$use_popup" -eq 1 ] && "${command_run["notify-send"]}" "$title" "$description" --urgency=normal --icon "$icon"

    echo "$description"
}

notify_steam_error() {
    [ "$use_steam" -eq 1 ] && notify "To enable Steam Monitor, run this script manually from a terminal to complete initial setup"
}
