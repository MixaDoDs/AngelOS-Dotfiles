#!/usr/bin/env bash
# Spotify in the author's look: spicetify with the theme and extensions the dotfiles ship
# (~/.config/spicetify: Vantagraph Custom, see THIRD-PARTY.md). Run after the apps are
# installed (scripts/apps-install.py) and at every login (services/AppsSync): spotify-launcher
# downloads Spotify itself on its first start, and each Spotify update puts the plain client
# back — then this applies the theme again. Quiet and quick when there is nothing to do.
#
#   spicetify-apply.sh          apply when needed (exit 0 also when Spotify isn't there yet)
#   spicetify-apply.sh --check  exit 0 when it is applied, 1 when it would apply, 2 when it can't yet
set -u

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/spicetify/config-xpui.ini"
command -v spicetify >/dev/null 2>&1 && [[ -f "$CONF" ]] || exit "$([[ "${1:-}" == --check ]] && echo 2 || echo 0)"

# where Spotify is: the config's spotify_path ($HOME expanded), else spotify-launcher's
dir="$(sed -n 's/^spotify_path[[:space:]]*=[[:space:]]*//p' "$CONF" | head -n 1)"
dir="${dir//\$HOME/$HOME}"
[[ -n "$dir" ]] || dir="$HOME/.local/share/spotify-launcher/install/usr/share/spotify/"
prefs="$(sed -n 's/^prefs_path[[:space:]]*=[[:space:]]*//p' "$CONF" | head -n 1)"
prefs="${prefs//\$HOME/$HOME}"

# not downloaded or never started yet (spicetify needs Spotify's prefs): later
if [[ ! -d "$dir/Apps" || ( -n "$prefs" && ! -f "$prefs" ) ]]; then
  [[ "${1:-}" == --check ]] && exit 2
  exit 0
fi
# applied = spicetify unpacked the client (Apps/xpui/); an update brings xpui.spa back
if [[ -d "$dir/Apps/xpui" && ! -f "$dir/Apps/xpui.spa" ]]; then
  exit 0
fi
[[ "${1:-}" == --check ]] && exit 1

# -n: Spotify is not restarted under the user; the look comes with its next start
spicetify -q -n backup apply >/dev/null 2>&1 ||
  spicetify -q -n restore backup apply >/dev/null 2>&1 ||
  { echo "spicetify: could not apply the theme (run: spicetify backup apply)" >&2; exit 1; }
exit 0
