#!/bin/sh
# Update counter for Arch/CachyOS: repo updates via `checkupdates` (pacman-contrib),
# AUR updates via paru or yay if installed.
SC="$HOME/.config/waybar/scripts"

get_updates() {
    CACHE_FILE="/tmp/waybar-checkupdates-$USER"
    if [ -f "$CACHE_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$CACHE_FILE"))) -lt 30 ]; then
        cat "$CACHE_FILE"
    else
        {
            checkupdates 2>/dev/null
            if command -v paru >/dev/null 2>&1; then paru -Qua 2>/dev/null
            elif command -v yay >/dev/null 2>&1; then yay -Qua 2>/dev/null; fi
        } | tee "$CACHE_FILE"
    fi
}

case $1'' in
'status')
    UPDATES=$(get_updates)
    COUNT=$(echo "$UPDATES" | grep -v '^$' | wc -l)
    TOOLTIP=$(echo "$UPDATES" | awk 1 ORS='\\n' | sed 's/\\n$//')
    jq -cn --arg count "$COUNT" --arg tooltip "$TOOLTIP" '{"text": $count, "tooltip": $tooltip}'
    ;;
'check')
    UPDATES=$(get_updates)
    [ "$(echo "$UPDATES" | grep -v '^$' | wc -l)" -gt 0 ]
    exit $?
    ;;
'upgrade')
    if command -v topgrade >/dev/null 2>&1; then CMD="topgrade"
    elif command -v paru >/dev/null 2>&1; then CMD="paru -Syu"
    elif command -v yay >/dev/null 2>&1; then CMD="yay -Syu"
    else CMD="sudo pacman -Syu"; fi
    rm -f "/tmp/waybar-checkupdates-$USER"
    "$SC/term-float" sh -c "$CMD; printf '\nDone. Press Enter to close...'; read _; \"$SC/waybar-signal\" pacman"
    ;;
esac
