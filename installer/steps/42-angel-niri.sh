# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── angel-niri ───────────────────────────────────────────────────────────────
# angelOS's fork of niri: the build pinned in data/angel-niri.json, from its GitHub release
# (checked by SHA256) or built from source when that fails, made the session's niri from the next
# login. One place for this and Settings → Updates: scripts/angel-niri-install.sh. It failing
# leaves niri from the package: angelOS works on it, without the fork's features.

ANGEL_NIRI="${ANGEL_NIRI:-1}"

install_angel_niri() {
  [[ "$ANGEL_NIRI" == 1 ]] || { say "$(_ 'angel-niri skipped: niri from the package' 'angel-niri пропущен: niri из пакета')"; return 0; }
  # the author's machine: its session's niri is switched by hand (each build is tried first)
  [[ -d "$HOME_DIR/.config/quickshell/angelos/owner" ]] && { say "$(_ "angel-niri: the author's machine, left as it is" 'angel-niri: машина автора — не трогаю')"; return 0; }
  local out
  out="$(HOME="$HOME_DIR" ANGELOS_LANG="$UI" bash "$ROOT/.config/quickshell/angelos/scripts/angel-niri-install.sh" install 2>&1)" || true
  sed -n 's/^STEP /  /p' <<<"$out"
  grep -q '^DONE' <<<"$out" || warn "angel-niri: $(sed -n 's/^FAIL //p' <<<"$out" | tail -1)"
}

# the steps of this file, in the order of the run (see step() in installer/lib/core.sh)
step 42 install_angel_niri "angel-niri (angelOS's niri)" "angel-niri (niri angelOS)"
