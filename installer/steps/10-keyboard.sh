# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── Keyboard layouts ─────────────────────────────────────────────────────────

KB_MENU=(us ru ua by kz de fr es pl cz it pt tr gb)
declare -A KB_NAME=(
  [us]="English (US)"      [ru]="Русский / Russian" [ua]="Українська / Ukrainian"
  [by]="Беларуская / Belarusian" [kz]="Қазақша / Kazakh" [de]="Deutsch / German"
  [fr]="Français / French" [es]="Español / Spanish" [pl]="Polski / Polish"
  [cz]="Čeština / Czech"   [it]="Italiano / Italian" [pt]="Português / Portuguese"
  [tr]="Türkçe / Turkish"  [gb]="English (UK)"
)
# XKB layout code → Whisper language / Tesseract language pack.
declare -A KB_WHISPER=(
  [us]=en [gb]=en [ru]=ru [ua]=uk [by]=be [kz]=kk [de]=de [fr]=fr
  [es]=es [pl]=pl [cz]=cs [it]=it [pt]=pt [tr]=tr
)
declare -A KB_TESS=(
  [ru]=rus [ua]=ukr [by]=bel [kz]=kaz [de]=deu [fr]=fra
  [es]=spa [pl]=pol [cz]=ces [it]=ita [pt]=por [tr]=tur
)

# id|label|XKB option. Win+Space is not offered: Mod+Space opens the launcher.
KB_TOGGLES=(
  "alt_shift|Alt + Shift|grp:alt_shift_toggle"
  "ctrl_shift|Ctrl + Shift|grp:ctrl_shift_toggle"
  "caps|Caps Lock (Caps Lock itself stops working)|grp:caps_toggle"
  "ralt|Right Alt|grp:ralt_toggle"
  "lalt|Left Alt|grp:lalt_toggle"
)

kb_valid_code() {
  local code="$1" lst=/usr/share/X11/xkb/rules/evdev.lst
  [[ "$code" =~ ^[a-z][a-z0-9_]{1,15}$ ]] || return 1
  [[ -r "$lst" ]] || return 0   # cannot verify against the XKB database
  awk '/^! layout/{f=1;next} /^!/{f=0} f{print $1}' "$lst" | grep -qx -- "$code"
}

# Turn "1 2 de" / "us,ru" into a clean comma list. Prints it, returns 1 on error.
kb_parse_layouts() {
  local input="${1//,/ }" tok code out=() seen=" "
  for tok in $input; do
    if [[ "$tok" =~ ^[0-9]+$ ]] && ((tok >= 1 && tok <= ${#KB_MENU[@]})); then
      code="${KB_MENU[tok-1]}"
    else
      code="${tok,,}"
    fi
    kb_valid_code "$code" || { printf '%s' "$tok"; return 1; }
    [[ "$seen" == *" $code "* ]] && continue
    seen+="$code "
    out+=("$code")
  done
  ((${#out[@]})) || { printf '%s' "$1"; return 1; }
  local IFS=,
  printf '%s' "${out[*]}"
}

# Resolve KB_TOGGLE (id or raw grp:… option) to an XKB option string.
kb_toggle_option() {
  local entry id label opt
  case "$1" in
    none|"") return 0 ;;
    grp:*)   printf '%s' "$1"; return 0 ;;
  esac
  for entry in "${KB_TOGGLES[@]}"; do
    IFS='|' read -r id label opt <<<"$entry"
    [[ "$id" == "$1" ]] && { printf '%s' "$opt"; return 0; }
  done
  return 1
}

choose_keyboard() {
  local reply bad n code i entry id label opt

  # the setup wizard asks them on the first login (its «Keyboard layouts»): the defaults (us,ru)
  # until then, worked out as for an unattended run
  if wizard_next && ! given KB_LAYOUTS; then local INTERACTIVE=0; fi
  # asked here or given: the setup wizard won't ask again (apply_setup_answers)
  if ((INTERACTIVE)) || given KB_LAYOUTS; then KB_ASKED=1; fi
  if ((INTERACTIVE)) && ! given KB_LAYOUTS && ((TUI)); then
    tui_section "$(_ 'Keyboard layouts' 'Раскладки клавиатуры')" \
      "$(_ 'Tick the ones you type in (space ticks, enter goes on).' 'Отметь те, на которых печатаешь (пробел — отметить, Enter — дальше).')"
    local labels=() picked first other
    for code in "${KB_MENU[@]}"; do labels+=("$(printf '%-3s %s' "$code" "${KB_NAME[$code]}")"); done
    labels+=("$(_ '✎ another XKB code…' '✎ другой XKB-код…')")
    while :; do
      picked="$(ui_choose_many "$(_ 'Layouts' 'Раскладки')" "1 2" "${labels[@]}")"
      reply=""
      for n in $picked; do
        if ((n == ${#labels[@]})); then
          other="$(ui_input "$(_ 'XKB codes, e.g. se jp' 'XKB-коды, например se jp')" "")"
          reply+=" $other"
        else
          reply+=" ${KB_MENU[n-1]}"
        fi
      done
      reply="${reply# }"
      [[ -n "$reply" ]] || reply="us ru"
      if KB_LAYOUTS="$(kb_parse_layouts "$reply")"; then break; fi
      bad="$KB_LAYOUTS"
      warn "$(_ "Unknown layout: $bad" "Неизвестная раскладка: $bad")"
      KB_LAYOUTS=us,ru
    done
    # the first one is active after login
    IFS=, read -r -a picked <<<"$KB_LAYOUTS"
    if ((${#picked[@]} > 1)); then
      labels=()
      for code in "${picked[@]}"; do labels+=("$code  ${KB_NAME[$code]:-}"); done
      first="$(ui_choose "$(_ 'Which one is on after login?' 'Какая включена после входа?')" 1 "${labels[@]}")"
      KB_LAYOUTS="${picked[first-1]}"
      for i in "${!picked[@]}"; do ((i == first - 1)) || KB_LAYOUTS+=",${picked[i]}"; done
    fi
  elif ((INTERACTIVE)) && ! given KB_LAYOUTS; then
    hr
    _ "Keyboard layouts" "Раскладки клавиатуры"; echo
    _ "Pick the layouts you type in, in order. The first one is active after login." \
      "Выберите раскладки, на которых печатаете. Первая будет активна после входа."; echo
    for i in "${!KB_MENU[@]}"; do
      code="${KB_MENU[i]}"
      printf '  %2d) %-3s %s\n' $((i + 1)) "$code" "${KB_NAME[$code]}"
    done
    _ "  Or type any XKB code yourself (e.g. \"se\", \"jp\"). Examples: \"1 2\"  \"us de\"  \"1,3\"" \
      "  Или введите любой XKB-код (например \"se\", \"jp\"). Примеры: \"1 2\"  \"us de\"  \"1,3\""; echo
    while :; do
      read -r -p "$(_ 'Layouts' 'Раскладки') [1 2 = us,ru]: " reply || true
      reply="${reply:-1 2}"
      if KB_LAYOUTS="$(kb_parse_layouts "$reply")"; then break; fi
      bad="$KB_LAYOUTS"
      warn "$(_ "Unknown layout: $bad" "Неизвестная раскладка: $bad")"
      KB_LAYOUTS=us,ru
    done
  else
    KB_LAYOUTS="$(kb_parse_layouts "$KB_LAYOUTS")" ||
      die "$(_ "Unknown keyboard layout in KB_LAYOUTS: $KB_LAYOUTS" "Неизвестная раскладка в KB_LAYOUTS: $KB_LAYOUTS")"
  fi

  IFS=, read -r -a KB_LIST <<<"$KB_LAYOUTS"

  if ((${#KB_LIST[@]} > 1)); then
    if ((INTERACTIVE)) && ! given KB_TOGGLE && ((TUI)); then
      local toggles=()
      for entry in "${KB_TOGGLES[@]}"; do IFS='|' read -r id label opt <<<"$entry"; toggles+=("$label"); done
      tui_note "$(_ '(Win+Space is skipped on purpose: it opens the launcher.)' '(Win+Space намеренно не предлагается: это запуск лаунчера.)')"
      reply="$(ui_choose "$(_ 'Shortcut to switch layouts' 'Сочетание для переключения раскладки')" 1 "${toggles[@]}")"
      IFS='|' read -r KB_TOGGLE label opt <<<"${KB_TOGGLES[reply-1]}"
    elif ((INTERACTIVE)) && ! given KB_TOGGLE; then
      hr
      _ "Shortcut to switch between layouts" "Сочетание для переключения раскладки"; echo
      for i in "${!KB_TOGGLES[@]}"; do
        IFS='|' read -r id label opt <<<"${KB_TOGGLES[i]}"
        printf '  %d) %s\n' $((i + 1)) "$label"
      done
      _ "  (Win+Space is skipped on purpose: it opens the launcher.)" \
        "  (Win+Space намеренно не предлагается: это запуск лаунчера.)"; echo
      while :; do
        read -r -p "$(_ 'Shortcut' 'Сочетание') [1]: " reply || true
        reply="${reply:-1}"
        if [[ "$reply" =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= ${#KB_TOGGLES[@]})); then
          IFS='|' read -r KB_TOGGLE label opt <<<"${KB_TOGGLES[reply-1]}"
          break
        fi
        warn "$(_ "Enter a number from the list" "Введите номер из списка")"
      done
    fi
    KB_OPTIONS="$(kb_toggle_option "$KB_TOGGLE")" ||
      die "$(_ "Unknown KB_TOGGLE: $KB_TOGGLE (use alt_shift, ctrl_shift, caps, ralt, lalt, none or grp:…)" \
               "Неизвестный KB_TOGGLE: $KB_TOGGLE (alt_shift, ctrl_shift, caps, ralt, lalt, none или grp:…)")"
  else
    KB_OPTIONS=""
  fi

  # Dictation language: first non-English layout, otherwise English.
  if [[ -z "$VOXTYPE_LANGUAGE" ]]; then
    VOXTYPE_LANGUAGE=en
    for code in "${KB_LIST[@]}"; do
      n="${KB_WHISPER[$code]:-en}"
      if [[ "$n" != en ]]; then
        VOXTYPE_LANGUAGE="$n"
        break
      fi
    done
  fi
}
