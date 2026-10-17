# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# step ORDER FUNCTION ENGLISH RUSSIAN — a step of the run. A module registers its own; they run
# by ORDER (two digits), so a new step is a new file in installer/steps with one line like this
STEPS=()
step() { STEPS+=("$1|$2|$3|$4"); }

TMP_FILES=()
TMP_DIRS=()
cleanup() {
  music_stop
  [[ -n "${SUDO_KEEP:-}" ]] && kill "$SUDO_KEEP" 2>/dev/null
  ((${#TMP_FILES[@]})) && rm -f -- "${TMP_FILES[@]}"
  ((${#TMP_DIRS[@]})) && rm -rf -- "${TMP_DIRS[@]}"
  return 0
}
trap cleanup EXIT

usage() { sed -n '2,/^set -E/p' "$ROOT/install.sh" | sed -e '$d' -e 's/^# \{0,1\}//'; }

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    *) die "$(_ "Unknown argument: $arg (try --help)" "Неизвестный аргумент: $arg (см. --help)")" ;;
  esac
done

# confirm "question" y|n   → returns 0 for yes. Without a terminal the default wins.
confirm() {
  local question="$1" default="${2:-n}" hint answer
  [[ "$default" == y ]] && hint='[Y/n]' || hint='[y/N]'
  ((INTERACTIVE)) || { [[ "$default" == y ]]; return; }
  read -r -p "$question $hint " answer || true
  answer="${answer:-$default}"
  [[ "$answer" =~ ^([yYдД]|yes|да|Да)$ ]]
}

# before anything is changed: sudo lets this user in (else every package asked again and failed one
# by one), and the password is asked once — kept fresh while the downloads run
SUDO_KEEP=""
preflight() {
  ((INTERACTIVE)) && [[ "$SKIP_PACKAGES" != 1 ]] && command -v pacman >/dev/null 2>&1 || return 0
  command -v sudo >/dev/null 2>&1 ||
    die "$(_ 'sudo is missing: as root, pacman -S sudo, then let your user in (usermod -aG wheel YOU; EDITOR=nano visudo — uncomment %wheel)' \
             'нет sudo: от root поставь его (pacman -S sudo) и пусти своего пользователя (usermod -aG wheel ИМЯ; EDITOR=nano visudo — раскомментируй %wheel)')"
  sudo -n true 2>/dev/null || say "$(_ 'The admin password — once for the whole install:' 'Пароль администратора — один раз на всю установку:')"
  sudo -v || die "$(_ "sudo does not let $(id -un) in: add the user to wheel (as root: usermod -aG wheel $(id -un); EDITOR=nano visudo — uncomment %wheel), log in again" \
                      "sudo не пускает $(id -un): добавь пользователя в wheel (от root: usermod -aG wheel $(id -un); EDITOR=nano visudo — раскомментируй %wheel) и войди заново")"
  ( while kill -0 "$$" 2>/dev/null; do sleep 50; sudo -n -v 2>/dev/null || exit 0; done ) &
  SUDO_KEEP=$!
}
