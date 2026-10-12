#!/usr/bin/env bash
# Voice input (Voxtype, offline Whisper): the binary from its GitHub release, checked by SHA256,
# and its model. One place for install.sh and the setup wizard («Scripts» → Voice input).
#
#   voxtype-install.sh binary [LANG]   ~/.local/bin/voxtype (x86_64), its config when there is none
#   voxtype-install.sh model           the Whisper large-v3-turbo model (~1.6 GB), made the active one
#   voxtype-install.sh all [LANG]      both, then the user services (dictation + its indicator)
#
# Progress for the wizard: lines "STEP <text>" and, at the end, "DONE" or "FAIL <why>".
# VOXTYPE_VERSION / VOXTYPE_FORCE=1 as in install.sh.
set -uo pipefail
VOXTYPE_VERSION="${VOXTYPE_VERSION:-1.1.0}"
VOXTYPE_FORCE="${VOXTYPE_FORCE:-0}"
BIN="$HOME/.local/bin/voxtype"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/voxtype/config.toml"
case "${ANGELOS_LANG:-${LANG:-}}" in ru*) UI=ru ;; *) UI=en ;; esac
_() { if [[ "$UI" == ru ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
step() { echo "STEP $*"; }
fail() { echo "FAIL $*"; exit 1; }

binary() {
  local arch variant sha url tmp actual
  arch="$(uname -m)"
  [[ "$arch" == x86_64 ]] || fail "$(_ 'Voxtype downloads are x86_64 only' 'Voxtype скачивается только для x86_64')"
  if [[ -x "$BIN" && "$VOXTYPE_FORCE" != 1 && "$("$BIN" --version 2>/dev/null || true)" == *"voxtype ${VOXTYPE_VERSION}"* ]]; then
    step "$(_ 'Voxtype is installed already' 'Voxtype уже стоит')"
  else
    variant=baseline
    if grep -qE '(^|[[:space:]])avx512f([[:space:]]|$)' /proc/cpuinfo 2>/dev/null; then variant=avx512
    elif grep -qE '(^|[[:space:]])avx2([[:space:]]|$)' /proc/cpuinfo 2>/dev/null; then variant=avx2; fi
    case "$variant" in
      baseline) sha=1c9d78b4f6805e4f12ba3670949d3c22788269bdbc54215afffa42cafd0b4a7a ;;
      avx2)     sha=e7d5de68cc8fc610c3c961c47f879451db9bee4a2df152e9a66f1078072e7f28 ;;
      avx512)   sha=bb2da45c7676bc128da998da928cb239ab6eef9fe53c31c9b4a77e819e521715 ;;
    esac
    url="https://github.com/peteonrails/voxtype/releases/download/v${VOXTYPE_VERSION}/voxtype-${VOXTYPE_VERSION}-linux-x86_64-${variant}"
    command -v curl >/dev/null 2>&1 || fail "$(_ 'curl is needed' 'нужен curl')"
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    step "$(_ "downloading Voxtype ${VOXTYPE_VERSION} (${variant})" "скачиваю Voxtype ${VOXTYPE_VERSION} (${variant})")"
    curl --fail --location --retry 3 --silent --show-error --output "$tmp" "$url" || fail "$(_ 'download failed' 'не скачалось')"
    actual="$(sha256sum "$tmp" | awk '{print $1}')"
    [[ "$actual" == "$sha" ]] || fail "$(_ "SHA256 mismatch (expected $sha, got $actual)" "SHA256 не совпал (ждали $sha, пришёл $actual)")"
    mkdir -p -- "${BIN%/*}"
    install -m 0755 "$tmp" "$BIN"
  fi
  # a config of its own when there is none (install.sh renders the dotfiles' one)
  if [[ ! -f "$CONF" ]]; then
    mkdir -p -- "${CONF%/*}"
    printf '# angelOS: voice input (Settings → Sound → Voice typing)\nlanguage = "%s"\n' "${1:-en}" >"$CONF"
  fi
}

model() {
  [[ -x "$BIN" ]] || fail "$(_ 'Voxtype is not installed' 'Voxtype не установлен')"
  step "$(_ 'downloading the Whisper model (~1.6 GB)' 'скачиваю модель Whisper (~1,6 ГБ)')"
  "$BIN" setup --download --model large-v3-turbo --activate --no-post-install ||
    fail "$(_ 'the model did not download; again: voxtype setup --download --model large-v3-turbo --activate' \
              'модель не скачалась; ещё раз: voxtype setup --download --model large-v3-turbo --activate')"
}

case "${1:-}" in
  binary) binary "${2:-en}" ;;
  model) model ;;
  all)
    binary "${2:-en}"
    model
    step "$(_ 'starting dictation (Mod+Shift+V)' 'включаю диктовку (Mod+Shift+V)')"
    systemctl --user enable --now voxtype.service voxtype-indicator.service >/dev/null 2>&1 || true ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac
echo DONE
