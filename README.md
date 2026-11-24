# waybar-flatmint

Waybar config extracted from [Manjaro Sway](https://github.com/Manjaro-Sway/desktop-settings), made standalone
so it works on **CachyOS / Arch** with sway, without the rest of the Manjaro Sway system.

## Install (one command)

    git clone https://github.com/vinhdubaii/waybar-flatmint && cd waybar-flatmint && ./install.sh

or without cloning:

    curl -fsSL https://raw.githubusercontent.com/vinhdubaii/waybar-flatmint/main/install.sh | bash

The installer:
1. installs required packages with `pacman` (AUR ones via `paru`/`yay` if present)
2. backs up and replaces `~/.config/waybar`
3. backs up `~/.config/sway/config` (or creates it from `/etc/sway/config`), switches the bar to waybar
   and adds a small marked block (`# >>> waybar-flatmint >>>`) — floating terminal rule, mako, cliphist, env import
4. installs the `wlsunset` user unit and reloads sway if you run it inside a sway session

Re-running is safe: backups get a timestamp and the sway block is not added twice.

Options: `--no-packages`, `--no-sway`, `--full` (optional packages: github-cli, wf-recorder, wluma, zeit, valent, topgrade), `-y`.

## What is different from Manjaro Sway
- scripts live in `~/.config/waybar/scripts/`
- sway variables (`$menu`, `$volume_up`, ...) replaced by real commands (rofi, wpctl, brightnessctl)
- weather/geoip call open-meteo directly (stdlib Python, no third-party server)
- updates via `checkupdates` (+ paru/yay) instead of pamac
- `custom/theme` needs Manjaro's theme files, so it stays hidden

## Weather (optional) — `~/.config/weather.cfg`
    [DEFAULT]
    city = Bien Hoa
    temperature = C
    distance = km

## Other distros
Run `./install.sh --no-packages` and install the packages listed in `install.sh` (`CORE`/`EXTRA`) yourself.
The update-count module only works with `checkupdates` (Arch) and stays hidden elsewhere.

## Credits
Config and scripts originate from Manjaro-Sway/desktop-settings. That repository has no license file at the time
of writing, so check with the authors if you plan to redistribute this widely.
