# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── Voxtype ──────────────────────────────────────────────────────────────────

install_voxtype() {
  [[ "$INSTALL_VOXTYPE" == 1 ]] || { say "$(_ 'Voxtype skipped' 'Voxtype пропущен')"; return 0; }
  # one place for this and the setup wizard: scripts/voxtype-install.sh (checked by SHA256)
  local out
  out="$(VOXTYPE_VERSION="$VOXTYPE_VERSION" VOXTYPE_FORCE="$VOXTYPE_FORCE" HOME="$HOME_DIR" \
         bash "$ROOT/.config/quickshell/angelos/scripts/voxtype-install.sh" binary "${VOXTYPE_LANGUAGE:-en}" 2>&1)" || true
  sed -n 's/^STEP /  /p' <<<"$out"
  # voice input is an extra: its download failing doesn't stop the desktop from installing
  grep -q '^DONE' <<<"$out" || { warn "Voxtype: $(sed -n 's/^FAIL //p' <<<"$out" | tail -1) — $(_ 'later: Settings → Sound' 'позже: Настройки → Звук')"; INSTALL_VOXTYPE=0; }
}
install_voxtype_model() {
  [[ "$DOWNLOAD_VOXTYPE_MODEL" == 1 ]] || { say "$(_ 'Voxtype model skipped' 'Модель Voxtype пропущена')"; return 0; }
  [[ -x "$HOME_DIR/.local/bin/voxtype" ]] || { warn "$(_ 'Model skipped: Voxtype is not installed' 'Модель пропущена: Voxtype не установлен')"; return 0; }
  if HOME="$HOME_DIR" bash "$ROOT/.config/quickshell/angelos/scripts/voxtype-install.sh" model | sed -n 's/^STEP /  /p;s/^FAIL /  /p'; then
    [[ -n "$(ls "$HOME_DIR"/.local/share/voxtype/models/*large-v3-turbo* 2>/dev/null)" ]] &&
      say "$(_ 'Voxtype model large-v3-turbo is ready' 'Модель Voxtype large-v3-turbo готова')"
  fi
}

# the steps of this file, in the order of the run (see step() in installer/lib/core.sh)
step 40 install_voxtype "Voxtype" "Voxtype"
step 41 install_voxtype_model "the Whisper model" "модель Whisper"
