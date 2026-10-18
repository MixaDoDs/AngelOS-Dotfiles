# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── Wallpaper packs ──────────────────────────────────────────────────────────

choose_wallpapers() {
  local i entry id count mb en ru answer total=0 picked=()
  if ((TUI)); then
    local labels=() all="" n
    for i in "${!WALLPAPER_LIST[@]}"; do
      IFS='|' read -r id count mb en ru <<<"${WALLPAPER_LIST[i]}"
      labels+=("$(printf '%-27s %s' "$id" "$(_ "$count pictures, ~$mb MB — $en" "$count картинок, ~$mb МБ — $ru")")")
      all+="$((i + 1)) "
    done
    tui_section "$(_ 'Wallpaper packs' 'Паки обоев')" "$(_ "downloaded from $WALLPAPERS_REPO; none = only the 3 default pictures" \
                                                          "скачиваются из $WALLPAPERS_REPO; ничего — только 3 картинки по умолчанию")"
    for n in $(ui_choose_many "$(_ 'Packs' 'Паки')" "$all" "${labels[@]}"); do picked+=("${WALLPAPER_LIST[n-1]%%|*}"); done
    if ((${#picked[@]})); then WALLPAPER_PACKS="$(IFS=,; echo "${picked[*]}")"; else WALLPAPER_PACKS=none; fi
    return 0
  fi
  _ "Wallpaper packs (downloaded from $WALLPAPERS_REPO)" "Паки обоев (скачиваются из $WALLPAPERS_REPO)"; echo
  for i in "${!WALLPAPER_LIST[@]}"; do
    IFS='|' read -r id count mb en ru <<<"${WALLPAPER_LIST[i]}"
    total=$((total + mb))
    printf '  %d) %-28s %s\n' "$((i + 1))" "$id" "$(_ "$count pictures, ~$mb MB — $en" "$count картинок, ~$mb МБ — $ru")"
  done
  _ "  a) all (~$total MB)    n) none (only the 3 default pictures)" \
    "  a) все (~$total МБ)    n) никаких (только 3 картинки по умолчанию)"; echo
  read -r -p "$(_ 'Packs, e.g. 1 3' 'Паки, например 1 3') [a]: " answer || true
  case "${answer:-a}" in
    a|A|all|все|а|А) WALLPAPER_PACKS=all ;;
    n|N|none|0|нет|н|Н) WALLPAPER_PACKS=none ;;
    *)
      for i in ${answer//,/ }; do
        [[ "$i" =~ ^[0-9]+$ ]] && ((i >= 1 && i <= ${#WALLPAPER_LIST[@]})) || continue
        picked+=("${WALLPAPER_LIST[i-1]%%|*}")
      done
      if ((${#picked[@]})); then WALLPAPER_PACKS="$(IFS=,; echo "${picked[*]}")"; else WALLPAPER_PACKS=none; fi
      ;;
  esac
}

# WALLPAPER_PACKS → folder names, one per line: exact names (any case) or a part of
# one name ("lain", "green"); unknown or ambiguous ones are skipped with a warning
wallpaper_folders() {
  local want entry name id hits
  case "${WALLPAPER_PACKS,,}" in
    ""|none|0|no) return 0 ;;
    all|1|yes) for entry in "${WALLPAPER_LIST[@]}"; do echo "${entry%%|*}"; done; return 0 ;;
  esac
  for want in ${WALLPAPER_PACKS//,/ }; do
    id="" hits=0
    for entry in "${WALLPAPER_LIST[@]}"; do
      name="${entry%%|*}"
      [[ "${name,,}" == "${want,,}" ]] && { id="$name"; hits=1; break; }
      [[ "${name,,}" == *"${want,,}"* ]] && { id="$name"; hits=$((hits + 1)); }
    done
    if ((hits == 1)); then echo "$id"
    else warn "$(_ "Unknown wallpaper pack: $want" "Неизвестный пак обоев: $want")"; fi
  done | awk '!seen[$0]++'
}

# Only the chosen folders are fetched (partial clone + sparse checkout).
install_wallpaper_packs() {
  local folders tmp
  mapfile -t folders < <(wallpaper_folders)
  ((${#folders[@]})) || return 0
  if ! command -v git >/dev/null 2>&1; then
    warn "$(_ 'git is missing: wallpaper packs skipped' 'Нет git: паки обоев пропущены')"
    return 0
  fi
  say "$(_ "Downloading wallpapers: ${folders[*]}…" "Скачиваю обои: ${folders[*]}…")"
  # on the disk of ~/Pictures, not in /tmp: a tmpfs of half the RAM has no room for all the packs
  mkdir -p -- "$HOME_DIR/.cache"
  tmp="$(mktemp -d "$HOME_DIR/.cache/angelos-wallpapers.XXXXXX")"
  trap 'rm -rf -- "$tmp"' EXIT
  if git clone --quiet --depth 1 --filter=blob:none --sparse -- "$WALLPAPERS_REPO" "$tmp/w" &&
     git -C "$tmp/w" sparse-checkout set -- "${folders[@]}"; then
    mkdir -p -- "$HOME_DIR/Pictures"
    for f in "${folders[@]}"; do
      [[ -d "$tmp/w/$f" ]] && cp -au -- "$tmp/w/$f" "$HOME_DIR/Pictures/"
    done
    say "$(_ 'Wallpapers are in ~/Pictures' 'Обои лежат в ~/Pictures')"
  else
    warn "$(_ "Could not download wallpapers from $WALLPAPERS_REPO; run the installer again later" \
               "Не удалось скачать обои из $WALLPAPERS_REPO; запустите установщик позже ещё раз")"
  fi
  rm -rf -- "$tmp"
  return 0
}

normalize_mode() {
  case "$MODE" in
    1|full) MODE=full ;;
    2|tech) MODE=tech ;;
    *) die "$(_ "DOTFILES_MODE must be full or tech (got: $MODE)" "DOTFILES_MODE должен быть full или tech (получено: $MODE)")" ;;
  esac
}
