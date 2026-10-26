# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── Interactive questions ────────────────────────────────────────────────────

# the setup wizard asks the rest on the first login (angelOS, full profile): the look, the game,
# the keyboard layouts, the apps (and the browser), voice input — so this run doesn't
wizard_next() {
  [[ "${DESKTOP_SHELL:-angelos}" == angelos && "$MODE" == full ]]
}

# Asked here: only what the system needs before the first login (the rest is the setup wizard's).
# The profile (DOTFILES_MODE=tech) and plain niri (DESKTOP_SHELL=none) are for those who know
# them: set from outside, never asked — whoever runs this came for angelOS
ask_profile() {
  ((INTERACTIVE)) || return 0
  if wizard_next; then
    tui_section "$(_ 'The rest comes on the first login' 'Остальное — при первом входе')" \
      "$(_ 'The look, the game, the keyboard layouts, the apps and the browser, voice input: the setup wizard asks them on the first login, with pictures. Here: only the system part.' \
           'Тема, игра, раскладки, программы и браузер, голосовой ввод — это спросит мастер настройки при первом входе, с картинками. Здесь — только системная часть.')"
  fi
  if [[ "$MODE" == full ]] && ! given INSTALL_WALLPAPERS && ! given WALLPAPER_PACKS; then
    choose_wallpapers
  fi
  # asked whenever the login shell isn't fish: a fish that came with the system (or a package)
  # while bash stayed the login shell was skipped without a word, and the terminal looked bare
  if ! given FISH_DEFAULT && [[ "$(getent passwd "$(id -un)" | cut -d: -f7)" != */fish ]] &&
     { ((FISH_WAS_INSTALLED)) || [[ "$SKIP_PACKAGES" != 1 ]]; }; then
    ui_confirm "$(_ 'A pretty terminal, as on the screenshots? (the fish shell with its prompt, fastfetch, colourful ls)' \
                    'Красивый терминал, как на скриншотах? (оболочка fish с подсказкой, fastfetch, цветной ls)')" y \
      && FISH_DEFAULT=1 || FISH_DEFAULT=0
    # shellcheck disable=SC2034  # read through given()
    GIVEN_FISH_DEFAULT=1
  fi
  if ! given INSTALL_SDDM; then
    local dm
    dm="$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" .service 2>/dev/null)"
    if [[ -n "$dm" && "$dm" != sddm ]]; then
      # GDM, plasmalogin and the others list the niri session already: keeping them is the default
      ui_confirm "$(_ "The angelOS login screen (SDDM) instead of your $dm? ($dm is turned off; niri is in its list either way)" \
                      "Экран входа angelOS (SDDM) вместо твоего $dm? ($dm выключится; niri в его списке есть и так)")" n \
        && INSTALL_SDDM=1 || INSTALL_SDDM=0
    else
      ui_confirm "$(_ 'The angelOS login screen (pixel, with your wallpaper)?' \
                      'Экран входа angelOS (пиксельный, с твоими обоями)?')" "$( ((INSTALL_SDDM)) && echo y || echo n)" \
        && INSTALL_SDDM=1 || INSTALL_SDDM=0
    fi
    # shellcheck disable=SC2034  # the DM question in sddm_enable is answered here
    GIVEN_INSTALL_SDDM=1
  fi
  choose_main_screen
  if ! given INSTALL_TOOLS && [[ "$SKIP_PACKAGES" != 1 && -s "$ROOT/packages/tools.txt" ]]; then
    ui_confirm "$(_ 'Handy programs too: a system monitor, an archiver, file compare, phone screen mirroring and small console tools?' \
                    'И полезные программы: монитор системы, архиватор, сравнение файлов, экран телефона и консольные мелочи?')" "$( ((INSTALL_TOOLS)) && echo y || echo n)" \
      && INSTALL_TOOLS=1 || INSTALL_TOOLS=0
  fi
  if ! given INSTALL_GAMING && [[ "$SKIP_PACKAGES" != 1 ]]; then
    ui_confirm "$(_ 'The gaming edition? (Steam, Proton, the drivers for games, a boost while one runs; snapshots of the system on btrfs)' \
                    'Игровая версия? (Steam, Proton, драйверы для игр, ускорение на время игры; снимки системы на btrfs)')" n \
      && INSTALL_GAMING=1 || INSTALL_GAMING=0
  fi
  # voice input is 1.6 GB: the wizard offers it (Settings → Sound later), not this run
  if wizard_next && ! given INSTALL_VOXTYPE; then
    INSTALL_VOXTYPE=0
    DOWNLOAD_VOXTYPE_MODEL=0
  fi
  if ! given INSTALL_VOXTYPE && ! wizard_next; then
    ui_confirm "$(_ 'Install offline voice input (Voxtype + ~1.6 GB Whisper model)?' \
                    'Поставить голосовой ввод (Voxtype + модель Whisper ~1.6 ГБ)?')" y \
      && { INSTALL_VOXTYPE=1; DOWNLOAD_VOXTYPE_MODEL=1; } || { INSTALL_VOXTYPE=0; DOWNLOAD_VOXTYPE_MODEL=0; }
  fi
}

# ── The main screen ───────────────────────────────────────────────────────────

# With two screens or more: which one is the main one. The login (SDDM) puts its password field
# and the pointer there, so does the lock, the widgets and the angel live there
# (settings.json system.primaryScreen; Settings → Monitor → Main screen later). Asked only
# inside niri, which knows the screens; elsewhere the setup wizard asks. MAIN_SCREEN=DP-1 says
# it without asking.
choose_main_screen() {
  given MAIN_SCREEN && return 0
  # niri running while this runs from a console or SSH: its socket is still there
  if [[ -z "${NIRI_SOCKET:-}" ]]; then
    NIRI_SOCKET="$(compgen -G "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/niri.*.sock" | head -1 || true)"
    [[ -n "$NIRI_SOCKET" ]] && export NIRI_SOCKET
  fi
  command -v niri >/dev/null 2>&1 && [[ -n "${NIRI_SOCKET:-}" ]] || return 0
  local lines=() names=() labels=() cur="" def=1 i answer
  cur="$(python3 -c 'import json,sys
try: print((json.load(open(sys.argv[1])).get("system") or {}).get("primaryScreen") or "")
except Exception: print("")' "$HOME_DIR/.config/angelos/settings.json" 2>/dev/null)"
  mapfile -t lines < <(niri msg --json outputs 2>/dev/null | python3 -c 'import json, sys
try: d = json.load(sys.stdin)
except Exception: d = {}
rows = []
for name, o in d.items():
    m = o.get("current_mode")
    mode = (o.get("modes") or [])[m] if isinstance(m, int) and m < len(o.get("modes") or []) else {}
    w, h = mode.get("width", 0), mode.get("height", 0)
    t = (o.get("logical") or {}).get("transform", "Normal")
    if t in ("90", "270", "Flipped90", "Flipped270"):
        w, h = h, w
    who = " ".join(x for x in (o.get("make"), o.get("model")) if x and x != "Unknown")
    rows.append((-w * h, name, "%s  %dx%d  %s" % (name, w, h, who)))
for _, name, label in sorted(rows):
    print(name + "\t" + label)')
  ((${#lines[@]} > 1)) || return 0
  for i in "${!lines[@]}"; do
    names+=("${lines[i]%%$'\t'*}")
    labels+=("${lines[i]#*$'\t'}")
    [[ "${names[i]}" == "$cur" ]] && def=$((i + 1))
  done
  tui_section "$(_ 'The main screen' 'Главный экран')" \
    "$(_ 'The login screen puts its password field and the pointer there, the lock too.' 'Там при входе будут поле пароля и курсор, и на блокировке тоже.')" \
    "$(_ 'Later: Settings → Monitor → Main screen.' 'Потом: Настройки → Монитор → Главный экран.')"
  answer="$(ui_choose "$(_ 'Which screen is the main one?' 'Какой экран главный?')" "$def" "${labels[@]}")"
  [[ "$answer" =~ ^[0-9]+$ ]] && ((answer >= 1 && answer <= ${#names[@]})) || answer="$def"
  MAIN_SCREEN="${names[answer - 1]}"
  # shellcheck disable=SC2034  # read through given()
  GIVEN_MAIN_SCREEN=1
}

# ── Before the start: everything this run will do, one screen ────────────────

# what happens to the system, in words, with the download — then Start / Change the answers / Quit.
# Nothing has been touched before this screen (gum aside)
review() {
  ((INTERACTIVE)) || return 0
  local lines=() mb="" n=0 packs=0 id count size en ru dm answer
  if [[ "$SKIP_PACKAGES" != 1 ]] && command -v pacman >/dev/null 2>&1; then
    wanted_packages
    n="$(printf '%s\n' "${PACKAGES[@]}" | xargs -r pacman -T 2>/dev/null | wc -l || true)"
    mb="$(pacman -Sp --needed --print-format '%s' "${PACKAGES[@]}" 2>/dev/null | awk '{s+=$1} END {printf "%d", s/1048576}' || true)"
    lines+=("$(_ "• the system is updated (pacman -Syu) and $n packages of angelOS come${mb:+ (~$mb MB)}" \
                 "• система обновится (pacman -Syu) и встанут $n пакетов angelOS${mb:+ (~$mb МБ)}")")
  fi
  [[ "$MODE" == full ]] && for id in "${WALLPAPER_LIST[@]}"; do
    IFS='|' read -r id count size en ru <<<"$id"
    [[ ",$(wallpaper_folders | paste -sd, -)," == *",$id,"* ]] && packs=$((packs + size))
  done
  ((packs)) && lines+=("$(_ "• wallpapers: ~$packs MB" "• обои: ~$packs МБ")")
  [[ "$CACHYOS_REPOS" == 1 && "$DISTRO_ID" == arch ]] &&
    lines+=("$(_ "• Arch: the author's repositories [cachyos] (below Arch's own) and [multilib], with CachyOS's signing key" \
                 "• Arch: репозитории автора [cachyos] (ниже арчевых) и [multilib], с ключом подписи CachyOS")")
  if [[ "$INSTALL_SDDM" == 1 ]]; then
    dm="$(basename "$(readlink /etc/systemd/system/display-manager.service 2>/dev/null)" .service 2>/dev/null)"
    lines+=("$(_ "• the angelOS login screen (SDDM)${dm:+, $dm is turned off}" "• экран входа angelOS (SDDM)${dm:+, $dm выключится}")")
  fi
  [[ "$FISH_DEFAULT" == 1 ]] && [[ "$(getent passwd "$(id -un)" | cut -d: -f7)" != */fish ]] &&
    lines+=("$(_ '• fish becomes your login shell' '• fish станет оболочкой входа')")
  [[ "$DESKTOP_SHELL" == angelos ]] &&
    lines+=("$(_ '• you join the input group (the Meta key, the mouse in games) and a udev rule reads the charge of wireless mice' \
                 '• ты войдёшь в группу input (клавиша Meta, мышь в играх), правило udev читает заряд беспроводных мышей')")
  [[ "$DESKTOP_SHELL" == angelos && "$DISCORD_SHIELD" == 1 ]] &&
    lines+=("$(_ '• WirePlumber: with a mixer (RØDECaster and the like) Discord streams its mixes, not each program' \
                 '• WirePlumber: с пультом (RØDECaster и похожие) Discord стримит его миксы, а не каждую программу')")
  if [[ "$INSTALL_GAMING" == 1 && "$SKIP_PACKAGES" != 1 ]]; then
    local g
    while IFS= read -r g; do
      [[ -n "$g" ]] && lines+=("• $(_ 'games' 'игры'): $g")
    done < <(bash "$ROOT/.config/quickshell/angelos/scripts/game-setup.sh" --plan 2>/dev/null || true)
  fi
  [[ "${ANGEL_NIRI:-1}" == 1 ]] &&
    lines+=("$(_ "• angel-niri, angelOS's own niri, is downloaded (~10 MB) and starts from the next login; the niri package stays" \
                 "• скачается angel-niri, свой niri angelOS (~10 МБ), и запустится со следующего входа; niri из пакета остаётся")")
  lines+=("$(_ "• your configs that differ are kept or backed up (*.bak.$STAMP); a log: ${INSTALL_LOG/#$HOME_DIR/\~}" \
               "• твои отличающиеся конфиги остаются или уходят в копию (*.bak.$STAMP); журнал: ${INSTALL_LOG/#$HOME_DIR/\~}")")
  lines+=("$(_ '• about 10–30 minutes, mostly the download; the admin password is asked once' \
               '• примерно 10–30 минут, в основном загрузка; пароль администратора — один раз')")
  tui_section "$(_ 'Ready to go live — this is what happens' 'Готовы к эфиру — вот что будет')" "$(printf '%s\n' "${lines[@]}")"
  answer="$(ui_choose "$(_ 'Start?' 'Начинаем?')" 1 "$(_ "Start $G_HEART" "Начать $G_HEART")" \
              "$(_ 'Change the answers' 'Изменить ответы')" "$(_ 'Quit — nothing changed' 'Выйти — ничего не изменено')")"
  case "$answer" in
    2) ANGELOS_SELF_UPDATED=1 exec bash "$ROOT/install.sh" "${ARGS[@]}" ;;
    3) say "$(_ 'Nothing changed. See you ♡' 'Ничего не изменено. До встречи ♡')"; exit 0 ;;
  esac
}
