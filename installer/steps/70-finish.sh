# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# gum draws the interface; it is installed before the first question (or plain prompts stay)
bootstrap_tui() {
  ((INTERACTIVE)) || return 0
  if [[ "${NO_TUI:-0}" != 1 ]] && ! command -v gum >/dev/null 2>&1 && [[ "$SKIP_PACKAGES" != 1 ]] &&
     command -v pacman >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
    say "$(_ "The installer's menus and pictures are drawn by gum and chafa (two small tools from the official repositories)." \
             'Меню и картинки установщика рисуют gum и chafa (две маленькие утилиты из официальных репозиториев).')"
    if confirm "$(_ 'Install them now? (No = plain text prompts)' 'Поставить их сейчас? (Нет — обычные текстовые вопросы)')" y; then
      sudo pacman -S --needed gum chafa || warn "$(_ 'gum did not install: plain prompts it is' 'gum не установился: будут обычные вопросы')"
    fi
  fi
  tui_detect
}

# A config niri refuses would leave the next login without a desktop: the run
# ends with an error (after the summary) instead of "Done".
NIRI_INVALID=0
validate() {
  local out
  [[ "$VALIDATE_NIRI" == 1 ]] || return 0
  if ! command -v niri >/dev/null 2>&1; then
    warn "$(_ 'niri is not installed: the Niri config was NOT validated' 'niri не установлен: конфиг Niri НЕ проверен')"
    return 0
  fi
  if out="$(niri validate -c "$HOME_DIR/.config/niri/config.kdl" 2>&1)"; then
    say "$(_ 'Niri config is valid' 'Конфиг Niri валиден')"
  else
    printf '%s\n' "$out" | tail -n 20 >&2
    NIRI_INVALID=1
  fi
}

summary() {
  hr
  say "$(_ 'Done.' 'Готово.')  profile=${MODE}  shell=${DESKTOP_SHELL}  home=${HOME_DIR}"
  if [[ "$DESKTOP_SHELL" == angelos ]] && given ANGELOS_THEME; then
    say "$(_ "Theme: $ANGELOS_THEME (later: Settings → Appearance)" "Тема: $ANGELOS_THEME (потом: Настройки → Оформление)")"
  fi
  if [[ "$INSTALL_APPS" == 1 ]]; then
    say "$(_ "Apps: $APPS" "Программы: $APPS")"
  fi
  if [[ "$DESKTOP_SHELL" == angelos ]]; then
    say "$(_ 'angelOS: on the first login a setup wizard and interface tips open by themselves;' \
             'angelOS: при первом входе сами откроются мастер настройки и подсказки по интерфейсу;')"
    say "$(_ '  later: Mod+S — settings, `angelos help` — CLI' '  потом: Mod+S — настройки, `angelos help` — CLI')"
    say "$(_ '  next updates: Settings → Updates' '  следующие обновления: Настройки → Обновления')"
    [[ -z "$QS_STATE" || "$QS_STATE" == ok ]] ||
      warn "$(_ 'angelOS: Quickshell needs an update (see the warning above)' 'angelOS: Quickshell нужно обновить (см. предупреждение выше)')"
  fi
  say "$(_ "Files: $N_INSTALLED installed, $N_UNCHANGED unchanged, $N_KEPT kept" \
           "Файлы: $N_INSTALLED установлено, $N_UNCHANGED без изменений, $N_KEPT сохранено")"
  if ((N_MERGED - ${#MERGED[@]} > 0)); then
    say "$(_ "Shortcuts: angelOS's new keys merged into $((N_MERGED - ${#MERGED[@]})) key profile(s), yours kept (backup: *.bak.$STAMP)" \
             "Горячие клавиши: новые клавиши angelOS добавлены в $((N_MERGED - ${#MERGED[@]})) профил(я/ей), твои сохранены (бэкап: *.bak.$STAMP)")"
  fi
  if [[ "$NIRI_FOREIGN" == 1 ]]; then
    say "$(_ "Niri: the config that was there was not angelOS's — replaced, so angelOS's keys work (the old one: ~/.config/niri/*.bak.$STAMP)" \
             "Niri: прежний конфиг был не от angelOS — заменён, чтобы работали клавиши angelOS (старый: ~/.config/niri/*.bak.$STAMP)")"
  fi
  if ((${#MERGED[@]})); then
    say "$(_ "The author's changes merged into ${#MERGED[@]} config file(s) you had changed — where you both changed the same lines, yours stay (before: *.bak.$STAMP):" \
             "Изменения автора влиты в ${#MERGED[@]} конфиг(ов), которые ты менял — где вы оба меняли одни строки, остались твои (как было: *.bak.$STAMP):")"
    printf '   ~/%s\n' "${MERGED[@]}"
  fi
  if ((N_PARKED)); then
    say "$(_ "Your changes kept in $N_PARKED config file(s); their new versions: ${PARKED_DIR/#$HOME_DIR/\~}/ (OVERWRITE_CONFIGS=1 replaces them, with a backup)" \
             "Твои изменения сохранены в $N_PARKED файл(ах) конфигов; их новые версии: ${PARKED_DIR/#$HOME_DIR/\~}/ (OVERWRITE_CONFIGS=1 заменит их, с бэкапом)")"
  fi
  ((${#PKG_FAILED[@]} == 0)) ||
    warn "$(_ "Packages that did not install: ${PKG_FAILED[*]}  →  sudo pacman -S ${PKG_FAILED[*]}" \
              "Не поставились пакеты: ${PKG_FAILED[*]}  →  sudo pacman -S ${PKG_FAILED[*]}")"
  say "$(_ 'Keyboard' 'Клавиатура'): ${KB_LAYOUTS}${KB_OPTIONS:+  ($KB_OPTIONS)} — $(_ 'layouts, monitors and the look: Settings (Mod+S)' 'раскладки, мониторы и вид: Настройки (Mod+S)')"
  if [[ "$SDDM_STATUS" != skipped ]]; then
    say "$(_ "Login screen: SDDM + $SDDM_THEME ($SDDM_STATUS); it appears after a reboot" \
             "Экран входа: SDDM + $SDDM_THEME ($SDDM_STATUS); появится после перезагрузки")"
    say "$(_ '  preview it now:' '  посмотреть сейчас:') sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/$SDDM_THEME"
  fi
  say "$(_ 'Cheat sheet: Mod+Shift+Esc  (Mod = Super/Windows key)' \
           'Шпаргалка по клавишам: Mod+Shift+Esc  (Mod = клавиша Super/Windows)')"
  # how to get in: through a login screen, or from the console when there is none (an update
  # from Settings runs inside niri already: nothing to say)
  ((INTERACTIVE)) || return 0
  local how
  if systemctl is-enabled display-manager.service >/dev/null 2>&1; then
    how="$(_ 'reboot and pick niri on the login screen — see you on the desktop' 'перезагрузись и выбери niri на экране входа — увидимся на рабочем столе')"
  else
    how="$(_ 'no login screen here: log in on a console (Ctrl+Alt+F2) and type niri-session' 'экрана входа нет: войди в консоли (Ctrl+Alt+F2) и набери niri-session')"
  fi
  tui_section "$(_ "thanks for watching $G_HEART" "спасибо, что смотрели $G_HEART")" "$how"
  if ((TUI)); then chat_line; fi
}

# Settings → Updates of shells older than their own restart prompt runs the
# installer without a terminal: ask in a notification, its buttons answer.
restart_notify() {
  command -v notify-send >/dev/null 2>&1 && command -v setsid >/dev/null 2>&1 || return 1
  setsid -f bash -c '[[ "$(notify-send -a angelOS -i system-software-update -u critical --wait \
      -A restart="$2" -A later="$3" "$4" "$5" 2>/dev/null)" == restart ]] && exec "$1" restart' _ "$1" \
    "$(_ 'Restart the shell' 'Перезагрузить оболочку')" "$(_ 'Later' 'Позже')" \
    "$(_ 'angelOS is updated ♡' 'angelOS обновлён ♡')" \
    "$(_ 'The previous version is still running. Restart the shell now? Windows and apps stay open.' \
         'Работает ещё прошлая версия. Перезагрузить оболочку сейчас? Окна и программы останутся открытыми.')" \
    </dev/null >/dev/null 2>&1
}

# A running angelOS keeps the old version in memory (it only watches its files in
# dev mode), so an update — new settings pages included — shows up after a restart.
restart_shell() {
  [[ "$DESKTOP_SHELL" == angelos ]] || return 0
  # Settings → Updates: the shell asks itself once the update is done
  [[ "${ANGELOS_RESTART:-}" == shell ]] && return 0
  local bin="$HOME_DIR/.local/bin/angelos" qs
  qs="$(command -v qs || echo "$HOME_DIR/.local/bin/qs")"
  [[ -x "$bin" && -x "$qs" ]] || return 0
  [[ "$("$qs" -c angelos list 2>/dev/null)" == *Instance* ]] || return 0
  if ((INTERACTIVE)) && [[ -n "${WAYLAND_DISPLAY:-}" ]] &&
     confirm "$(_ 'angelOS is still running the previous version. Restart it now?' \
                  'angelOS ещё работает на прошлой версии. Перезапустить его сейчас?')" y; then
    if "$bin" restart; then say "$(_ 'angelOS restarted' 'angelOS перезапущен')"
    else warn "$(_ 'Could not restart angelOS: run `angelos restart`' 'Не удалось перезапустить angelOS: выполните `angelos restart`')"; fi
  elif ((!INTERACTIVE)) && [[ -n "${WAYLAND_DISPLAY:-}" ]] && restart_notify "$bin"; then
    say "$(_ 'angelOS asks in a notification whether to restart it now' 'angelOS спросит в уведомлении, перезапустить ли его сейчас')"
  else
    warn "$(_ 'angelOS is still running the previous version: run `angelos restart` or log in again' \
              'angelOS ещё работает на прошлой версии: выполните `angelos restart` или перезайдите в систему')"
  fi
}

# the steps of this file, in the order of the run (see step() in installer/lib/core.sh)
step 90 validate "niri validate" "niri validate"
