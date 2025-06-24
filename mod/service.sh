create_user_service() {
    [ -z "$1" ] || [ -z "$2" ] && return 1

    local game="$1"
    shift
    local game_desc="${2##*/}"
    local script_path="$path_script/${0##*/}"
    local service_file="$HOME/.config/systemd/user/${game}.service"
    local service_name="${service_file##*/}"
    local quoted_args=""

    [ -z "$game" ] || [ ! -f "$script_path" ] && return 1

    for arg in "$@"; do
        [ -d "$arg" ] || [ -f "$arg" ] && quoted_args="$quoted_args \"$arg\"" || quoted_args="$quoted_args $arg"
    done
    quoted_args=${quoted_args# }

    mk_dir "$HOME/.config/systemd/user"
    cat <<-EOF > "$service_file"
		[Unit]
		Description=LBSPCFW $game_desc
		After=graphical-session.target
		PartOf=graphical-session.target

		[Service]
		Type=simple
		ExecStart="$script_path" $quoted_args
		Restart=always
		RestartSec=10

		[Install]
		WantedBy=graphical-session.target
	EOF
    chmod 644 "$service_file"
    systemctl --user daemon-reload

    color_msg "green" "Service file created!\n" "bold"
    color_msg "blue" " $service_file\n\n"

    color_msg "white" "Enable service now? [Y/n] " "bold"
    local choice=$(prompt)

    if [ "$choice" -eq 1 ]; then
        systemctl --user stop "$service_name" 2>/dev/null
        sleep 1
        systemctl --user enable --now "$service_name" 2>/dev/null
        if [ $? -ne 0 ]; then
            color_msg "red" "Failed to enable or start '$service_name'\n" "bold"
            exit 1
        fi
        if systemctl --user is-enabled "$service_name" >/dev/null 2>&1 && systemctl --user is-active "$service_name" >/dev/null 2>&1; then
            color_msg "blue" " Service is enabled and active for '$game_desc' ($service_name)\n"
        else
            color_msg "red" "Service '$service_name' failed\n" "bold"
            systemctl --user disable --now "$service_name" 2>/dev/null
            systemctl --user status "$service_name"
            exit 1
        fi
    else
        color_msg "white" "\nTo enable service manually:\n"
        color_msg "blue" " systemctl --user enable --now $service_name\n"
    fi

    printf '\n'
}

remove_user_service() {
    local systemd_dir="$HOME/.config/systemd/user"
    local service_prefix="lbspcfw-*"
    local service_disabled=0

    if [ ! -d "$systemd_dir" ]; then
        color_msg "yellow" " No systemd user directory found at $systemd_dir\n"
        return 1
    fi
    
    while read -r service_file; do
        local service_name="${service_file##*/}"
        service_name="${service_name%.service}"
        
        systemctl --user stop "$service_name" 2>/dev/null
        systemctl --user disable "$service_name" 2>/dev/null
        
        rm_file "$service_file"
        
        color_msg "green" " Removed service '$service_name'\n"
        
        service_disabled=1
    done < <(find "$systemd_dir" -type f -name "$service_prefix" 2>/dev/null)

    [ "$service_disabled" -eq 0 ] && color_msg "green" " No services found\n"

    systemctl --user daemon-reload 2>/dev/null
    systemctl --user reset-failed 2>/dev/null
}