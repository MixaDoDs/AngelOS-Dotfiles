#!/usr/bin/env bash
# The gaming edition of angelOS: what games need to run (Steam, Proton, the 32-bit drivers),
# what makes them faster (gamemode, MangoHud, gamescope, sched-ext, a big shader cache; the
# boost itself is .local/bin/niri-game-mode, there for everyone) and what keeps the system
# whole (a snapshot before every pacman transaction, bootable from the boot menu on btrfs).
# The installer's step (installer/steps/12-gaming.sh) and Settings → Maintenance → Games run it.
#
#   game-setup.sh            install and set up (asks sudo itself)
#   game-setup.sh --plan     print what it would do, one line a thing (no root, changes nothing)
#   game-setup.sh --check    exit 0 when it was done here already
#
# The list is the shell's own (data/gaming-packages.txt): the live shell has no repository next
# to it. Packages come from the repositories only (on Arch, [cachyos] and [multilib] through
# scripts/cachyos-repos.sh, as the installer adds them); a name they don't have is skipped
# with a word. Done once, it leaves $STATE_DIR/gaming: updates keep the list installed.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="$HERE/../data/gaming-packages.txt"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/angelos"
MARK="$STATE_DIR/gaming"
ENV_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/90-angelos-games.conf"
case "${ANGELOS_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in ru*) RU=1 ;; *) RU=0 ;; esac
_() { if ((RU)); then printf '%s' "$2"; else printf '%s' "$1"; fi; }
say() { printf '\033[1;35m»\033[0m %s\n' "$(_ "$1" "$2")"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$(_ "$1" "$2")" >&2; }

[[ "${1:-}" == --check ]] && { [[ -f "$MARK" ]]; exit; }

# the 32-bit Vulkan driver of each video card here (Steam and Proton run 32-bit parts)
gpu_packages() {
  local v
  for v in /sys/class/drm/card[0-9]*/device/vendor; do
    [[ -r "$v" ]] || continue
    case "$(<"$v")" in
      0x10de) echo lib32-nvidia-utils ;;
      0x1002) echo lib32-vulkan-radeon ;;
      0x8086) echo lib32-vulkan-intel ;;
    esac
  done | sort -u
}
btrfs_root() { [[ "$(findmnt -no FSTYPE / 2>/dev/null)" == btrfs ]]; }
# the bootloader that can start a snapshot: limine (CachyOS's default) or GRUB; systemd-boot can't
boot_snapshots() {
  if pacman -Q limine >/dev/null 2>&1; then echo limine-snapper-sync
  elif pacman -Q grub >/dev/null 2>&1; then echo grub-btrfs
  fi
}
packages() {
  {
    grep -Ev '^[[:space:]]*(#|$)' "$LIST"
    gpu_packages
    if btrfs_root; then echo snapper; echo snap-pac; boot_snapshots; fi
  } | while IFS= read -r p; do
    if pacman -Si -- "$p" >/dev/null 2>&1 || pacman -Q -- "$p" >/dev/null 2>&1; then
      echo "$p"
    else
      warn "$p is not in your repositories: skipped" "$p нет в ваших репозиториях: пропущен"
    fi
  done
}

if [[ "${1:-}" == --plan ]]; then
  _ 'Steam, Proton (CachyOS build, umu with automatic per-game fixes, ProtonPlus for GE), 32-bit drivers' 'Steam, Proton (сборка CachyOS, umu с автопочинками для игр, ProtonPlus для GE), 32-битные драйверы'; echo
  _ 'gamemode, MangoHud, gamescope, sched-ext schedulers; shader cache 10 GB' 'gamemode, MangoHud, gamescope, планировщики sched-ext; кэш шейдеров 10 ГБ'; echo
  if ! btrfs_root; then
    _ 'no snapshots: the system disk is not btrfs' 'без снимков: системный диск не btrfs'; echo
  elif [[ -f /etc/snapper/configs/root ]]; then
    _ 'a snapshot before every update (snap-pac; snapper is set up here already and stays as it is)' 'снимок системы перед каждым обновлением (snap-pac; snapper здесь уже настроен, он не меняется)'; echo
  else
    _ 'a snapshot before every update (snapper + snap-pac), the last 10 kept' 'снимок системы перед каждым обновлением (snapper + snap-pac), хранятся 10 последних'; echo
  fi
  if btrfs_root && [[ -n "$(boot_snapshots)" ]]; then
    _ 'snapshots in the boot menu: a broken update is undone by booting the one before' 'снимки в меню загрузки: сломало обновление — загрузиться в снимок до него'; echo
  fi
  exit 0
fi

command -v pacman >/dev/null 2>&1 || { warn 'pacman not found' 'pacman не найден'; exit 1; }
[[ -f "$LIST" ]] || { warn "no $LIST" "нет $LIST"; exit 1; }
# Steam lives in [multilib]: on Arch it comes with the author's repositories
if ! grep -Eq '^\[multilib\][[:space:]]*$' /etc/pacman.conf; then
  bash "$HERE/cachyos-repos.sh" ||
    warn 'The [multilib] repository was not added: Steam will be skipped' 'Репозиторий [multilib] не подключился: Steam не поставится'
fi

mapfile -t PKGS < <(packages)
say 'Installing the games part (pacman -Syu)…' 'Ставлю игровую часть (pacman -Syu)…'
# -Syu: Arch does not support partial upgrades. --noconfirm only without a terminal
noconfirm=()
[[ -t 0 ]] || noconfirm=(--noconfirm)
sudo pacman -Syu --needed "${noconfirm[@]}" "${PKGS[@]}"

# shader caches: compiled once, kept (NVIDIA's own cap of 1 GB threw them away mid-game)
mkdir -p "$(dirname "$ENV_FILE")"
cat >"$ENV_FILE" <<'EOF'
# angelOS gaming edition (scripts/game-setup.sh): shader caches big enough to keep
__GL_SHADER_DISK_CACHE_SIZE=10737418240
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
MESA_SHADER_CACHE_MAX_SIZE=10G
EOF

# snapshots: snap-pac takes one before and after each pacman transaction once snapper has a
# config for /; no timeline (a snapshot an hour fills the disk), the last 10 pairs kept.
# A config that is there already (the user's own, CachyOS's) keeps its limits
if btrfs_root && command -v snapper >/dev/null 2>&1; then
  if ! sudo snapper list-configs 2>/dev/null | grep -qE '^root[[:space:]]'; then
    if sudo snapper -c root create-config /; then
      sudo snapper -c root set-config TIMELINE_CREATE=no NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 || true
      say 'Snapshots of the system are on' 'Снимки системы включены'
    else
      warn 'snapper could not set up / (a /.snapshots of another tool?): no snapshots' \
           'snapper не смог настроить / (/.snapshots от другой программы?): снимков не будет'
    fi
  fi
  if sudo snapper list-configs 2>/dev/null | grep -qE '^root[[:space:]]'; then
    if pacman -Q limine-snapper-sync >/dev/null 2>&1; then sudo systemctl enable --now limine-snapper-sync.service >/dev/null 2>&1 || true; fi
    if pacman -Q grub-btrfs >/dev/null 2>&1; then sudo systemctl enable --now grub-btrfsd.service >/dev/null 2>&1 || true; fi
  fi
fi

mkdir -p "$STATE_DIR"
date +%F >"$MARK"
say 'The gaming edition is set up. The shader cache takes effect after the next login.' \
    'Игровая версия готова. Кэш шейдеров заработает после следующего входа.'
