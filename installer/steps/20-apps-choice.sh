# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── The author's apps (full profile) ─────────────────────────────────────────

# The catalog .config/quickshell/angelos/data/apps-catalog.json (the setup wizard's too): what the
# author has, in groups. scripts/apps-install.py installs the picked ones (pacman, the AUR through
# paru, Flathub) and remembers the pick, so Settings → Updates later brings the apps the author
# adds to the groups taken here (nothing is ever removed).
APPS_PY="$ROOT/.config/quickshell/angelos/scripts/apps-install.py"
declare -A APP_EN=() APP_RU=() APP_HINT_EN=() APP_HINT_RU=()
APP_GROUPS=()   # id|default|English|Russian|app,ids
load_apps() {
  ((${#APP_GROUPS[@]})) && return 0
  local kind id a b c d
  while IFS=$'\t' read -r kind id a b c d; do
    if [[ "$kind" == G ]]; then
      APP_GROUPS+=("$id|$a|$b|$c|$d")
    elif [[ "$kind" == A ]]; then
      APP_EN["$id"]="$a" APP_RU["$id"]="$b" APP_HINT_EN["$id"]="$c" APP_HINT_RU["$id"]="$d"
    fi
  done < <(python3 "$APPS_PY" tsv 2>/dev/null)
}

# the catalog is read with python3 — a bare Arch Linux may not have it before its packages
need_python() {
  command -v python3 >/dev/null 2>&1 && return 0
  [[ "$SKIP_PACKAGES" != 1 ]] && command -v pacman >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1 || return 1
  say "$(_ 'The list of apps needs python (from the official repositories)' 'Списку программ нужен python (из официальных репозиториев)')"
  sudo pacman -S --needed --noconfirm python >/dev/null && command -v python3 >/dev/null 2>&1
}

APPS_ASKED=0
choose_apps() {
  local entry gid def en ru ids labels=() pre="" picked n i g_ids=() app_ids=() apps_of=() id
  need_python || { warn "$(_ 'python3 is missing: the apps are skipped (later: Settings → Updates)' 'нет python3: программы пропущены (потом: Настройки → Обновления)')"; return 0; }
  load_apps
  ((${#APP_GROUPS[@]})) || return 0
  for entry in "${APP_GROUPS[@]}"; do
    IFS='|' read -r gid def en ru ids <<<"$entry"
    local names=() ; for id in ${ids//,/ }; do names+=("$(_ "${APP_EN[$id]}" "${APP_RU[$id]}")"); done
    # no commas in a label: gum takes the preselected ones as a comma-separated list
    local list; list="$(printf '%s · ' "${names[@]}")"
    labels+=("$(_ "$en" "$ru") — ${list% · }")
    [[ "$def" == 1 ]] && pre+="${#labels[@]} "
  done
  tui_section "$(_ "The author's apps" 'Программы автора')" \
    "$(_ "Everything angelOS's author has, in groups. Ticked = as the author has it; untick what you don't want. Updates later bring what the author adds to the groups you take." \
         'Всё, что стоит у автора angelOS, по группам. Отмечено — как у автора; сними лишнее. Потом обновления доставят то, что автор добавит в выбранные группы.')"
  picked="$(ui_choose_many "$(_ 'Groups' 'Группы')" "$pre" "${labels[@]}")"
  for n in $picked; do g_ids+=("${APP_GROUPS[n-1]}"); done
  APPS_ASKED=1
  if ((${#g_ids[@]})) && ui_confirm "$(_ 'Open the groups and untick single apps?' 'Раскрыть группы и снять отдельные программы?')" n; then
    for entry in "${g_ids[@]}"; do
      IFS='|' read -r gid def en ru ids <<<"$entry"
      IFS=, read -ra apps_of <<<"$ids"; labels=() pre=""
      for id in "${apps_of[@]}"; do
        local label; label="$(_ "${APP_EN[$id]} — ${APP_HINT_EN[$id]}" "${APP_RU[$id]} — ${APP_HINT_RU[$id]}")"
        labels+=("${label//,/ ·}")
        pre+="${#labels[@]} "
      done
      picked="$(ui_choose_many "$(_ "$en" "$ru")" "$pre" "${labels[@]}")"
      for n in $picked; do app_ids+=("${apps_of[n-1]}"); done
    done
  else
    for entry in "${g_ids[@]}"; do
      IFS='|' read -r gid def en ru ids <<<"$entry"
      IFS=, read -ra apps_of <<<"$ids"; app_ids+=("${apps_of[@]}")
    done
  fi
  APPS="$(IFS=,; echo "${app_ids[*]:-}")"
  if [[ -n "$APPS" ]]; then INSTALL_APPS=1; else INSTALL_APPS=0; APPS=none; fi
}

# APPS → app ids, one per line: all = the default groups (as the author has it); a group id
# stands for its apps; none/0/no = nothing
chosen_apps() {
  local entry gid def en ru ids want
  case "${APPS,,}" in ""|none|0|no) return 0 ;; esac
  load_apps
  for want in ${APPS//,/ }; do
    want="${want,,}"
    if [[ -n "${APP_EN[$want]:-}" ]]; then echo "$want"; continue; fi
    for entry in "${APP_GROUPS[@]}"; do
      IFS='|' read -r gid def en ru ids <<<"$entry"
      if [[ "$want" == "$gid" || ( "$want" == all && "$def" == 1 ) ]]; then printf '%s\n' ${ids//,/ }; fi
    done
  done | awk '!seen[$0]++'
}
