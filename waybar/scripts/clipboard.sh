#!/bin/sh
# Needs: cliphist, wl-clipboard, rofi (or wofi). Run `wl-paste --watch cliphist store` from sway.
menu() { if command -v rofi >/dev/null 2>&1; then rofi -dmenu -p "$1" -lines 10; else wofi --dmenu -p "$1"; fi; }
case $1'' in
'pick')   cliphist list | menu "Select item to copy" | cliphist decode | wl-copy ;;
'delete') cliphist list | menu "Select item to delete" | cliphist delete ;;
esac
