#!/usr/bin/env bash
# qThrone (github.com/ttrroyy/qThrone, Throne's fork: sing-box + olcrtc/openflux/csqtt/qwdtt): the
# release's portable zip, checked by SHA256, into ~/.local/opt/qThrone. A folder of the user's own and
# no -appdata: that is when its built-in updater works (Help → Check for updates), so later versions
# come from qThrone itself, not from here. One place for install.sh and the setup wizard (the apps).
#
#   qthrone-install.sh all [LANG]    the app, its launcher (~/.local/bin/qthrone), menu entry and
#                                    throne:// links; Throne's settings come along when there are some
#
# Progress for the wizard: lines "STEP <text>" and, at the end, "DONE" or "FAIL <why>".
# QTHRONE_FORCE=1 puts the pinned release over an existing install (its config/ stays).
set -uo pipefail
QTHRONE_VERSION=1.3.5
QTHRONE_FORCE="${QTHRONE_FORCE:-0}"
DIR="$HOME/.local/opt/qThrone"
BIN="$HOME/.local/bin/qthrone"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
tmp=""   # the download, gone at the exit
case "${2:-${ANGELOS_LANG:-${LANG:-}}}" in ru*) UI=ru ;; *) UI=en ;; esac
_() { if [[ "$UI" == ru ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
step() { echo "STEP $*"; }
fail() { echo "FAIL $*"; exit 1; }

app() {
  local arch sha url
  case "$(uname -m)" in
    x86_64)  arch=amd64 sha=dee5020ba8a39eae284054de051b6637c19ae8bd8e658c8fca139d6fec9d38ef ;;
    aarch64) arch=arm64 sha=9af6aeca7bb0ce59720c4a6f075ac87be8d3b34ae6d6c2e4b195810f05ca2185 ;;
    *) fail "$(_ "qThrone has no build for $(uname -m)" "у qThrone нет сборки для $(uname -m)")" ;;
  esac
  if [[ -x "$DIR/qThrone" && "$QTHRONE_FORCE" != 1 ]]; then
    step "$(_ 'qThrone is installed already (it updates itself)' 'qThrone уже стоит (обновляется сам)')"
    return 0
  fi
  command -v curl >/dev/null 2>&1 || fail "$(_ 'curl is needed' 'нужен curl')"
  command -v bsdtar >/dev/null 2>&1 || fail "$(_ 'bsdtar (libarchive) is needed' 'нужен bsdtar (libarchive)')"
  url="https://github.com/ttrroyy/qThrone/releases/download/v${QTHRONE_VERSION}/qThrone-${QTHRONE_VERSION}-linux-${arch}.zip"
  tmp="$(mktemp -d)"
  trap '[[ -n "$tmp" ]] && rm -rf "$tmp"' EXIT
  step "$(_ "downloading qThrone ${QTHRONE_VERSION} (~140 MB)" "скачиваю qThrone ${QTHRONE_VERSION} (~140 МБ)")"
  curl -fL --retry 2 --progress-bar -o "$tmp/q.zip" "$url" || fail "$(_ 'the download failed' 'не скачалось')"
  [[ "$(sha256sum "$tmp/q.zip" | cut -d' ' -f1)" == "$sha" ]] ||
    fail "$(_ "the checksum doesn't match: not installing" 'контрольная сумма не сошлась — не ставлю')"
  mkdir -p "$tmp/x" && bsdtar -xf "$tmp/q.zip" -C "$tmp/x" && [[ -x "$tmp/x/qThrone/qThrone" ]] ||
    fail "$(_ "the archive didn't unpack" 'архив не распаковался')"
  mkdir -p "$DIR"
  # over an existing install the files are swapped, its config/ (profiles, settings) stays
  (cd "$tmp/x/qThrone" && find . -mindepth 1 -maxdepth 1 -print0) | while IFS= read -r -d '' f; do
    rm -rf "$DIR/${f#./}" && mv "$tmp/x/qThrone/${f#./}" "$DIR/"
  done
  [[ -x "$DIR/qThrone" ]] || fail "$(_ "qThrone didn't install" 'qThrone не поставился')"
}

# Throne's profiles and settings (the same database): taken once, while qThrone has none of its own
settings() {
  local old="${XDG_CONFIG_HOME:-$HOME/.config}/Throne/config"
  [[ -f "$old/throne.db" && ! -e "$DIR/config/throne.db" ]] || return 0
  step "$(_ "qThrone takes Throne's profiles and settings" 'qThrone забирает профили и настройки Throne')"
  mkdir -p "$DIR/config" && cp -a "$old/." "$DIR/config/"
}

launcher() {
  mkdir -p "${BIN%/*}" "$APPS"
  cat >"$BIN" <<'EOF'
#!/bin/sh
# qThrone, portable in ~/.local/opt/qThrone (angelOS's scripts/qthrone-install.sh): no -appdata, so
# its own updater works; settings in ~/.local/opt/qThrone/config.
# For TUN qThrone gives its core root through pkexec, and pkexec refuses (exit 127) when $SHELL is
# not in /etc/shells — after every update the core is new and asks again.
grep -qxF "$SHELL" /etc/shells 2>/dev/null || export SHELL=/bin/sh
# the shell's own Qt libraries are not for qThrone's bundled Qt
unset LD_LIBRARY_PATH
# a qt6ct built against the bundled Qt, when there is one: the palette of the desktop
if [ -d "$HOME/.local/share/throne-qt-plugins" ]; then
  export QT_QPA_PLATFORMTHEME=qt6ct QT_PLUGIN_PATH="$HOME/.local/share/throne-qt-plugins"
fi
cd "$HOME/.local/opt/qThrone" && exec ./qThrone "$@"
EOF
  chmod +x "$BIN"
  cat >"$APPS/qThrone.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=qThrone
Comment=Proxy / VPN client (Throne fork, sing-box)
Exec=$BIN
Icon=$DIR/qThrone.png
Terminal=false
StartupNotify=false
StartupWMClass=qThrone
Categories=Network;
Keywords=throne;vpn;proxy;sing-box;
EOF
  cat >"$APPS/qthrone-url-handler.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=qThrone
Icon=$DIR/qThrone.png
Exec=$BIN %U
MimeType=x-scheme-handler/throne;
Terminal=false
NoDisplay=true
EOF
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" >/dev/null 2>&1
  command -v xdg-mime >/dev/null 2>&1 && xdg-mime default qthrone-url-handler.desktop x-scheme-handler/throne
  return 0
}

case "${1:-all}" in
  all) app && settings && launcher &&
         step "$(_ 'qThrone: in the menu; TUN asks for the password once (and after an update)' \
                   'qThrone: в меню; TUN один раз спросит пароль (и после обновления)')" && echo DONE ;;
  *) echo "usage: qthrone-install.sh all [LANG]" >&2; exit 2 ;;
esac
