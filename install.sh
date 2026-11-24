#!/usr/bin/env bash
# waybar-flatmint installer — one command setup for sway + waybar.
#   git clone https://github.com/vinhdubaii/waybar-flatmint && cd waybar-flatmint && ./install.sh
#   or: curl -fsSL https://raw.githubusercontent.com/vinhdubaii/waybar-flatmint/main/install.sh | bash
#
# Options:
#   --no-packages   do not install packages (just copy config)
#   --no-sway       do not touch ~/.config/sway/config
#   --full          also install optional packages (gh, wf-recorder, wluma, zeit, valent, ...)
#   -y, --yes       pass --noconfirm to pacman/AUR helper
#   -h, --help
set -euo pipefail

REPO="vinhdubaii/waybar-flatmint"
BRANCH="main"
TS="$(date +%Y%m%d-%H%M%S)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

DO_PKGS=1; DO_SWAY=1; FULL=0; YES=0
for a in "$@"; do
    case "$a" in
        --no-packages) DO_PKGS=0 ;;
        --no-sway) DO_SWAY=0 ;;
        --full) FULL=1 ;;
        -y|--yes) YES=1 ;;
        -h|--help) sed -n '2,12p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $a (try --help)" >&2; exit 1 ;;
    esac
done

c_b=$'\033[1m'; c_g=$'\033[32m'; c_y=$'\033[33m'; c_r=$'\033[31m'; c_0=$'\033[0m'
say()  { printf '%s==>%s %s\n' "$c_g$c_b" "$c_0" "$*"; }
warn() { printf '%s!!%s  %s\n' "$c_y$c_b" "$c_0" "$*" >&2; }
die()  { printf '%sERROR:%s %s\n' "$c_r$c_b" "$c_0" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] && die "Do not run as root. The script uses sudo only when installing packages."

# --- locate the repo files (or download them when run through curl | bash) ----------------
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -d "$(dirname "${BASH_SOURCE[0]}")/waybar" ]; then
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    command -v curl >/dev/null 2>&1 || die "curl is required to download the repo."
    TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
    say "Downloading $REPO ($BRANCH)..."
    curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$TMP" --strip-components=1 \
        || die "Download failed. Clone the repo manually and run ./install.sh"
    SRC="$TMP"
fi

# --- packages ----------------------------------------------------------------------------
CORE="sway waybar rofi foot mako swayidle cliphist wl-clipboard playerctl pacman-contrib brightnessctl wireplumber btop calcurse networkmanager jq curl python util-linux lsof wlsunset ttf-jetbrains-mono-nerd libnotify"
EXTRA="pulsemixer bluetuith"
OPTIONAL="github-cli wf-recorder wluma zeit valent python-dbus topgrade"

install_packages() {
    if ! command -v pacman >/dev/null 2>&1; then
        warn "pacman not found (not Arch/CachyOS). Skipping package install."
        warn "Install these yourself: $CORE $EXTRA"
        return 0
    fi
    local noconf=(); [ "$YES" -eq 1 ] && noconf=(--noconfirm)
    local want="$CORE $EXTRA"; [ "$FULL" -eq 1 ] && want="$want $OPTIONAL"
    local repo_pk=() aur_pk=() p
    for p in $want; do
        if pacman -Qq "$p" >/dev/null 2>&1; then continue
        elif pacman -Si "$p" >/dev/null 2>&1; then repo_pk+=("$p")
        else aur_pk+=("$p"); fi
    done
    if [ "${#repo_pk[@]}" -gt 0 ]; then
        say "Installing from repos: ${repo_pk[*]}"
        sudo pacman -S --needed "${noconf[@]}" "${repo_pk[@]}" || warn "Some repo packages failed to install."
    fi
    if [ "${#aur_pk[@]}" -gt 0 ]; then
        local helper=""
        command -v paru >/dev/null 2>&1 && helper=paru
        [ -z "$helper" ] && command -v yay >/dev/null 2>&1 && helper=yay
        if [ -n "$helper" ]; then
            say "Installing from AUR with $helper: ${aur_pk[*]}"
            for p in "${aur_pk[@]}"; do
                "$helper" -S --needed "${noconf[@]}" "$p" || warn "AUR package failed: $p"
            done
        else
            warn "Not in repos and no AUR helper (paru/yay) found, skipped: ${aur_pk[*]}"
        fi
    fi
}
[ "$DO_PKGS" -eq 1 ] && install_packages

# --- waybar config -----------------------------------------------------------------------
say "Installing waybar config to $CFG/waybar"
if [ -e "$CFG/waybar" ]; then
    mv "$CFG/waybar" "$CFG/waybar.bak-$TS"
    say "Existing config backed up to $CFG/waybar.bak-$TS"
fi
mkdir -p "$CFG"
cp -r "$SRC/waybar" "$CFG/waybar"
chmod +x "$CFG"/waybar/scripts/*

# --- systemd user unit for night light ---------------------------------------------------
if [ -f "$SRC/systemd-user/wlsunset.service" ]; then
    mkdir -p "$CFG/systemd/user"
    cp "$SRC/systemd-user/wlsunset.service" "$CFG/systemd/user/wlsunset.service"
    systemctl --user daemon-reload 2>/dev/null || true
fi

# --- sway config -------------------------------------------------------------------------
patch_sway() {
    local conf="$CFG/sway/config"
    mkdir -p "$CFG/sway"
    if [ ! -f "$conf" ]; then
        if [ -f /etc/sway/config ]; then
            cp /etc/sway/config "$conf"
            say "Created $conf from /etc/sway/config"
        else
            warn "No sway config found; creating a minimal one."
            printf 'set $mod Mod4\nfloating_modifier $mod\n' > "$conf"
        fi
    else
        cp "$conf" "$conf.bak-$TS"
        say "Sway config backed up to $conf.bak-$TS"
    fi

    # use waybar instead of swaybar
    if ! grep -q 'swaybar_command waybar' "$conf"; then
        if grep -Eq '^[[:space:]]*bar[[:space:]]*\{' "$conf"; then
            sed -i '0,/^[[:space:]]*bar[[:space:]]*{/s//&\n    swaybar_command waybar # waybar-flatmint/' "$conf"
        else
            printf '\nbar {\n    swaybar_command waybar # waybar-flatmint\n}\n' >> "$conf"
        fi
    fi

    if grep -q '>>> waybar-flatmint >>>' "$conf"; then
        say "Sway config already has the waybar-flatmint block, leaving it."
        return 0
    fi
    {
        printf '\n# >>> waybar-flatmint >>>\n'
        printf 'for_window [app_id="floating_shell"] floating enable\n'
        grep -Eq '^[[:space:]]*exec(_always)?[[:space:]].*mako' "$conf" || printf 'exec mako\n'
        grep -Eq 'cliphist' "$conf" || printf 'exec wl-paste --watch cliphist store\n'
        grep -Eq 'import-environment' "$conf" || printf 'exec systemctl --user import-environment WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP\n'
        printf '# <<< waybar-flatmint <<<\n'
    } >> "$conf"
    say "Updated $conf"
}
[ "$DO_SWAY" -eq 1 ] && patch_sway

# --- reload ------------------------------------------------------------------------------
if [ "$DO_SWAY" -eq 1 ] && [ -n "${SWAYSOCK:-}" ] && command -v swaymsg >/dev/null 2>&1; then
    swaymsg reload >/dev/null && say "Sway reloaded."
else
    warn "Not inside a sway session: log in to sway (or run 'swaymsg reload' there) to see the bar."
fi

say "Done. Optional: city for weather -> ~/.config/weather.cfg (see README)."
