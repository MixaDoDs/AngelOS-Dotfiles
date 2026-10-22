#!/usr/bin/env bash
# angel-niri, angelOS's fork of niri (minimize, pixel looks, privacy looks and the pause in
# screencasts, tearing, the game's pointer lock, windows in their places): the build pinned in
# data/angel-niri.json for this user — downloaded from its GitHub release and checked by SHA256,
# or built from source (MixaDoDs/angel-niri + angel-smithay beside it) when the download fails or
# the binary doesn't run here — and made the session's niri. Nothing system-wide: the niri package
# stays installed, a drop-in of niri.service starts ours (from the next login) and
# ~/.local/bin/niri is it for `niri msg`. angelOS works on stock niri too, without the fork's
# features. A session that doesn't start: Ctrl+Alt+F3, log in, `angel-niri-install.sh off`.
# Beside it angel-satellite, the fork of xwayland-satellite niri runs X11 apps with (drag and drop
# into X11 apps, menus on two monitors): ~/.local/bin/xwayland-satellite, picked up from PATH.
#
#   angel-niri-install.sh [install]   the pinned build, made the session's niri
#   angel-niri-install.sh off         back to the niri package (from the next login)
#   angel-niri-install.sh status      which niri the next login starts
#
# Progress as voxtype-install.sh: "STEP <text>", at the end "DONE" or "FAIL <why>".
# ANGEL_NIRI_BUILD=1 builds from source even when the download works.
set -uo pipefail
SHELL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PIN="$SHELL_DIR/data/angel-niri.json"
LIB="$HOME/.local/lib/angel-niri"
DROPIN="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/niri.service.d/angel-niri.conf"
LINK="$HOME/.local/bin/niri"
SAT_LIB="$HOME/.local/lib/angel-satellite"
SAT_LINK="$HOME/.local/bin/xwayland-satellite"
case "${ANGELOS_LANG:-${LANG:-}}" in ru*) UI=ru ;; *) UI=en ;; esac
_() { if [[ "$UI" == ru ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
step() { echo "STEP $*"; }
fail() { echo "FAIL $*"; exit 1; }

pin() { python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$PIN" "$1"; }

# does it run here (its libraries) and take this user's niri config
works() {
  "$1" --version >/dev/null 2>&1 || return 1
  local conf="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
  [[ -f "$conf" ]] || return 0
  "$1" validate -c "$conf" >/dev/null 2>&1
}

# download DIR [PIN_PREFIX FILE NAME]: angel-niri, or with satellite_ the satellite
download() {
  local dir="$1" p="${2:-}" file="${3:-niri}" name="${4:-angel-niri}" tmp actual url
  command -v curl >/dev/null 2>&1 || return 1
  [[ "$(uname -m)" == x86_64 ]] || return 1
  url="https://github.com/$(pin "${p}repo")/releases/download/$(pin "${p}tag")/$(pin "${p}asset")"
  tmp="$(mktemp -d)"
  step "$(_ "downloading $name $(pin "${p}tag")" "скачиваю $name $(pin "${p}tag")")"
  if curl --fail --location --retry 3 --silent --show-error --output "$tmp/a.tar.zst" "$url"; then
    actual="$(sha256sum "$tmp/a.tar.zst" | awk '{print $1}')"
    if [[ "$actual" == "$(pin "${p}sha256")" ]] && tar --zstd -xf "$tmp/a.tar.zst" -C "$tmp" "$file"; then
      mkdir -p -- "$dir" && install -m 0755 "$tmp/$file" "$dir/$file"
      rm -rf "$tmp"
      return 0
    fi
    step "$(_ "SHA256 mismatch (expected $(pin "${p}sha256"), got $actual)" "SHA256 не совпал (ждали $(pin "${p}sha256"), пришёл $actual)")"
  fi
  rm -rf "$tmp"
  return 1
}

build() {
  local dir="$1" src="${XDG_CACHE_HOME:-$HOME/.cache}/angel-niri-src"
  if ! command -v cargo >/dev/null 2>&1 || ! command -v clang >/dev/null 2>&1; then
    # the installer keeps sudo fresh; elsewhere (no password cached) this just fails
    step "$(_ 'installing Rust and clang to build it' 'ставлю Rust и clang для сборки')"
    sudo -n pacman -S --needed --noconfirm rust clang >/dev/null 2>&1 ||
      return 1
  fi
  # rustup without a default toolchain answers nothing
  cargo --version >/dev/null 2>&1 || { command -v rustup >/dev/null 2>&1 && rustup default stable >/dev/null 2>&1; } || return 1
  step "$(_ 'building angel-niri from source (10–20 minutes)' 'собираю angel-niri из исходников (10–20 минут)')"
  mkdir -p -- "$src"
  local name repo rev
  for name in angel-smithay angel-niri; do
    if [[ "$name" == angel-niri ]]; then repo="$(pin repo)" rev="$(pin commit)"; else repo="$(pin smithay_repo)" rev="$(pin smithay)"; fi
    [[ -d "$src/$name/.git" ]] || git clone --quiet "https://github.com/$repo.git" "$src/$name" || return 1
    git -C "$src/$name" fetch --quiet origin || return 1
    git -C "$src/$name" checkout --quiet --force "$rev" || return 1
  done
  (cd "$src/angel-niri" && nice cargo build --release --locked >"$src/build.log" 2>&1) ||
    { step "$(_ "build log: $src/build.log" "лог сборки: $src/build.log")"; return 1; }
  mkdir -p -- "$dir" && install -m 0755 "$src/angel-niri/target/release/niri" "$dir/niri"
}

use() {
  local bin="$1"
  mkdir -p -- "${DROPIN%/*}" "${LINK%/*}"
  printf '%s\n' "# angelOS: the session's niri is angel-niri (scripts/angel-niri-install.sh; off: angel-niri-install.sh off)" \
    "[Service]" "ExecStart=" "ExecStart=$bin --session" >"$DROPIN"
  ln -sfn -- "$bin" "$LINK"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
}

# shortcut: download only, no build from source; without it the xwayland-satellite package stays.
satellite() {
  local commit dir old
  commit="$(pin satellite_commit 2>/dev/null)" || return 0
  dir="$SAT_LIB/${commit:0:8}"
  if ! "$dir/xwayland-satellite" --test-listenfd-support 2>/dev/null; then
    rm -rf -- "$dir"
    if ! download "$dir" satellite_ xwayland-satellite angel-satellite ||
      ! "$dir/xwayland-satellite" --test-listenfd-support 2>/dev/null; then
      rm -rf -- "$dir"
      step "$(_ 'angel-satellite could not be downloaded; X11 apps stay on the xwayland-satellite package' 'angel-satellite не скачался; X11-программы остаются на xwayland-satellite из пакета')"
      return 0
    fi
  fi
  mkdir -p -- "${SAT_LINK%/*}" && ln -sfn -- "$dir/xwayland-satellite" "$SAT_LINK"
  for old in "$SAT_LIB"/*/; do
    [[ "${old%/}" == "$dir" ]] || rm -rf -- "$old"
  done
}

install_it() {
  [[ -f "$PIN" ]] || fail "$(_ 'no data/angel-niri.json' 'нет data/angel-niri.json')"
  local commit dir
  commit="$(pin commit)" || fail "$(_ 'data/angel-niri.json is broken' 'data/angel-niri.json сломан')"
  dir="$LIB/${commit:0:8}"
  if [[ -x "$dir/niri" ]] && works "$dir/niri"; then
    step "$(_ "angel-niri ${commit:0:8} is there already" "angel-niri ${commit:0:8} уже стоит")"
  else
    rm -rf -- "$dir"
    if [[ "${ANGEL_NIRI_BUILD:-0}" == 1 ]] || ! download "$dir" || ! works "$dir/niri"; then
      rm -rf -- "$dir"
      build "$dir" && works "$dir/niri" ||
        { rm -rf -- "$dir"; fail "$(_ 'angel-niri could not be downloaded or built; angelOS stays on the niri package' 'angel-niri не скачался и не собрался; angelOS остаётся на niri из пакета')"; }
    fi
  fi
  use "$dir/niri"
  satellite
  # older builds nobody starts any more
  local old
  for old in "$LIB"/*/; do
    [[ "${old%/}" == "$dir" ]] || rm -rf -- "$old"
  done
  step "$(_ 'angel-niri starts with the next login' 'angel-niri включится со следующего входа')"
  echo DONE
}

case "${1:-install}" in
  install) install_it ;;
  off)
    rm -f -- "$DROPIN"
    [[ "$(readlink "$LINK" 2>/dev/null)" == "$LIB"/* ]] && rm -f -- "$LINK"
    [[ "$(readlink "$SAT_LINK" 2>/dev/null)" == "$SAT_LIB"/* ]] && rm -f -- "$SAT_LINK"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    step "$(_ 'the niri package starts with the next login' 'со следующего входа — niri из пакета')"
    echo DONE ;;
  status)
    if [[ -f "$DROPIN" ]]; then sed -n 's/^ExecStart=\(.\+\) --session$/\1/p' "$DROPIN"; else echo "niri"; fi ;;
  *) sed -n '2,/^set -uo/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 2 ;;
esac
