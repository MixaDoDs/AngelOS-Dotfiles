# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── The gaming edition ───────────────────────────────────────────────────────

# INSTALL_GAMING=1: Steam, Proton, the drivers for games, snapshots on btrfs — the shell's own
# scripts/game-setup.sh, the same as Settings → Maintenance → Games. After the packages: the
# author's repositories ([multilib] for Steam) are there by then
install_gaming() {
  [[ "$INSTALL_GAMING" == 1 && "$SKIP_PACKAGES" != 1 ]] || return 0
  command -v pacman >/dev/null 2>&1 || return 0
  local -a run=(env HOME="$HOME_DIR" ANGELOS_LANG="$UI" bash "$ROOT/.config/quickshell/angelos/scripts/game-setup.sh")
  # without a terminal nobody answers pacman: game-setup.sh adds --noconfirm when stdin isn't one
  if ((INTERACTIVE)); then "${run[@]}"; else "${run[@]}" </dev/null; fi ||
    warn "$(_ 'The gaming edition did not finish: later, Settings → Maintenance → Games' \
              'Игровая версия не доустановилась: потом — Настройки → Обслуживание → Игры')"
}

# the steps of this file, in the order of the run (see step() in installer/lib/core.sh)
step 12 install_gaming "the gaming edition" "игровая версия"
