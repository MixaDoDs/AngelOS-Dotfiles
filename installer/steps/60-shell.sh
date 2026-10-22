# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

enable_services() {
  [[ "$ENABLE_SERVICES" == 1 ]] || return 0
  command -v systemctl >/dev/null 2>&1 || { warn "$(_ 'systemctl not found; user services not enabled' 'systemctl не найден; user-сервисы не включены')"; return 0; }
  # no user session (su from root, a container): enabling still works offline, the files are linked
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    export SYSTEMD_OFFLINE=1
    warn "$(_ 'No user session here: the services are enabled for the next login' 'Здесь нет пользовательской сессии: сервисы включатся со следующего входа')"
  fi
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable niri-game-mode.service || true
  # a fast mouse thinned in games: idle until gaming.mouseRate is set (the wizard, Settings → Games)
  systemctl --user enable mouse-coalesce.service || true
  # a password dialog even when the shell's own polkit agent is not up (hyprpolkitagent as the fallback)
  [[ -f "$HOME_DIR/.config/systemd/user/polkit-agent-guard.service" ]] &&
    { systemctl --user enable polkit-agent-guard.service || true; }
  if [[ -x "$HOME_DIR/.local/bin/voxtype" ]]; then
    systemctl --user enable voxtype.service voxtype-indicator.service || true
  fi
}

# angelOS: CLI on PATH, theme files for kitty/foot/gtk/niri, shell wiring.
# On the first login angelOS opens its setup wizard and then the interface tips.
# What was asked here is not asked again by angelOS's setup wizard: the game on or off
# (ANGELOS_GAME, when asked or given) → settings.json game.enabled and setup.gameAsked; the
# keyboard layouts (asked or KB_LAYOUTS given) → setup.keyboardAsked. The rest of the file
# stays as it is; the player's save (save.json) is never touched.
apply_setup_answers() {
  local game=""
  if given ANGELOS_GAME; then
    [[ "$ANGELOS_GAME" == 0 || "$ANGELOS_GAME" == 1 ]] || die "ANGELOS_GAME must be 0 or 1"
    game="$ANGELOS_GAME"
  fi
  local theme=""
  given ANGELOS_THEME && theme="$ANGELOS_THEME"
  local screen=""
  given MAIN_SCREEN && screen="$MAIN_SCREEN"
  [[ -z "$screen" || "$screen" =~ ^[A-Za-z0-9._-]{1,40}$ ]] || die "MAIN_SCREEN must be an output name, like DP-1"
  [[ -n "$game" || -n "${KB_ASKED:-}" || -n "$theme" || -n "$LANG_ASKED" || -n "$screen" ]] || return 0
  local f="$HOME_DIR/.config/angelos/settings.json"
  mkdir -p -- "${f%/*}"
  python3 - "$f" "$game" "${KB_ASKED:-}" "$theme" "$MAC_KEYS" "${LANG_ASKED:+$UI}" "$screen" <<'PY' || warn "$(_ 'Could not write the answers into settings.json' 'Не удалось записать ответы в settings.json')"
import json, os, sys, tempfile
path, game, kb, theme, mac_keys = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4], sys.argv[5] == "1"
lang = sys.argv[6]
screen = sys.argv[7]
d = {}
if os.path.exists(path):
    with open(path) as f:
        d = json.load(f)
before = json.dumps(d, sort_keys=True)
if game:
    d.setdefault("game", {})["enabled"] = game == "1"
    d.setdefault("setup", {})["gameAsked"] = True
# only before the wizard is done (an update passes the layouts on too: nothing to write then)
if kb and not d.get("setup", {}).get("complete"):
    d.setdefault("setup", {})["keyboardAsked"] = True
# the look: pixel = angelOS's classic skin, macos = Golden Gate; picked = the wizard won't ask
if theme:
    ui = d.setdefault("settingsUi", {})
    ui["skin"] = "goldengate" if theme == "macos" else "classic"
    ui["skinChosen"] = True
    if theme == "macos":
        d.setdefault("mac", {})["keys"] = mac_keys
# the language picked in the installer, until the wizard is done (later it is Settings → Account)
if lang in ("ru", "en") and not d.get("setup", {}).get("complete"):
    d.setdefault("appearance", {})["language"] = lang
# the main screen: the login's password field and pointer, the lock, the widgets
if screen:
    d.setdefault("system", {})["primaryScreen"] = screen
if json.dumps(d, sort_keys=True) == before:
    sys.exit(0)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".settings-")
with os.fdopen(fd, "w") as f:
    json.dump(d, f, ensure_ascii=False, indent=4)
os.replace(tmp, path)
PY
}

install_shell() {
  local shell_dir="$HOME_DIR/.config/quickshell/angelos"
  [[ "$DESKTOP_SHELL" != none && -d "$shell_dir" ]] || return 0
  if [[ "$DESKTOP_SHELL" == angelos ]]; then
    say "$(_ 'Setting up angelOS…' 'Настройка angelOS…')"
    apply_setup_answers
    ln -sfn "$shell_dir/bin/angelos" "$HOME_DIR/.local/bin/angelos"
    mkdir -p -- "$HOME_DIR/.config/angelos"
    printf 'angelos\n' > "$HOME_DIR/.config/angelos/active"
    # where Settings → Updates pulls from
    printf 'repo=%s\nremote=%s\n' "$ROOT" "$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)" \
      > "$HOME_DIR/.config/angelos/dotfiles-source"
    # the first run's intro: its minute of sound is mixed now (~20 s, in the background), not
    # while the wizard waits for it (scripts/intro-sounds.py; INTRO_SOUNDS=0: never)
    if [[ "$INTRO_SOUNDS" == 1 ]] && command -v python3 >/dev/null 2>&1 && command -v ffmpeg >/dev/null 2>&1; then
      (setsid python3 "$shell_dir/scripts/intro-sounds.py" "$HOME_DIR/.local/share/angelos/sounds/intro" >/dev/null 2>&1 &)
    fi
    # Fresh installs have no owner marker. Preserve an existing owner's marker
    # so updating the dotfiles does not disable their publishing controls.
    # The generated theme files are shipped with the repository and are
    # installed by install_configs. Do not regenerate them here: doing so
    # would overwrite the shipped palette and make a second install dirty.
  fi
}

# The windows' own minimize buttons (GTK's yellow light, Qt's, Firefox's): niri ignores
# xdg_toplevel.set_minimized, so extras/minimize-hook (an LD_PRELOAD library) hands it to angelOS
# (services/Minimize.qml) — without it the Golden Gate skin's yellow light did nothing (#56).
# Built here for everyone, as extras/minimize-hook/install.sh does it: the library, angelos.service's
# drop-in, cfg/angelos-minimize.kdl and its include in niri's config.kdl (the manifest isn't told:
# the next update merges config.kdl, the include stays as the user's line; carry_includes keeps it
# when the file is replaced). Rebuilt only when the source changed, put in place by rename (running
# apps keep the old one mapped). MINIMIZE_HOOK=0, or `extras/minimize-hook/install.sh --remove`
# (minimize-hook.off), leaves it out. No compiler: a warning, nothing else.
install_minimize_hook() {
  [[ "$DESKTOP_SHELL" == angelos && "$MINIMIZE_HOOK" == 1 ]] || return 0
  [[ -e "$HOME_DIR/.config/angelos/minimize-hook.off" ]] && return 0
  local src="$ROOT/.config/quickshell/angelos/extras/minimize-hook" out="$HOME_DIR/.local/lib/angelos"
  local built d pre kdl="$HOME_DIR/.config/niri/cfg/angelos-minimize.kdl" cfg="$HOME_DIR/.config/niri/config.kdl"
  local dropin="$HOME_DIR/.config/systemd/user/angelos.service.d/50-minimize-hook.conf" inc
  [[ -f "$src/angelos-minimize.c" ]] || return 0
  if ! command -v cc >/dev/null 2>&1; then
    warn "$(_ "no C compiler (gcc): the windows' own minimize buttons won't work (⌘M and the Dock do)" \
              "нет компилятора C (gcc): кнопки «свернуть» в окнах не заработают (⌘M и Dock работают)")"
    return 0
  fi
  built="$(mktemp -d)"; TMP_DIRS+=("$built")
  if ! sh "$src/build.sh" "$built" >/dev/null 2>&1; then
    warn "$(_ 'the minimize hook did not build (extras/minimize-hook/build.sh)' \
              'перехват сворачивания не собрался (extras/minimize-hook/build.sh)')"
    return 0
  fi
  for d in lib lib32; do
    [[ -f "$built/$d/libangelos-minimize.so" ]] || continue
    cmp -s "$built/$d/libangelos-minimize.so" "$out/$d/libangelos-minimize.so" 2>/dev/null && continue
    mkdir -p -- "$out/$d"
    cp -- "$built/$d/libangelos-minimize.so" "$out/$d/.libangelos-minimize.so.new"
    mv -f -- "$out/$d/.libangelos-minimize.so.new" "$out/$d/libangelos-minimize.so"
  done
  # ld.so's own $LIB (lib / lib32): a 32-bit game gets the 32-bit build
  pre="$out/\$LIB/libangelos-minimize.so"
  mkdir -p -- "${dropin%/*}" "${kdl%/*}"
  cat >"$dropin" <<UNIT
# angelOS minimize hook (extras/minimize-hook): the windows' own minimize buttons go to angelOS.
# \$LIB is ld.so's (lib / lib32): systemd doesn't expand \$ in Environment=.
[Service]
Environment="LD_PRELOAD=$pre"
UNIT
  cat >"$kdl" <<KDL
// angelOS minimize hook (extras/minimize-hook): apps niri starts get the preload.
environment {
    LD_PRELOAD "$pre"
}
KDL
  if [[ -f "$cfg" ]] && ! grep -q 'angelos-minimize\.kdl' "$cfg"; then
    # a copy (backup() moves the file away) — not of the author's own just put there, and one
    # already made by this run is the older one
    [[ -e "$cfg.bak.$STAMP" || "$(sum_of "$cfg")" == "${NEW_SUM[.config/niri/config.kdl]:-}" ]] ||
      cp -p -- "$cfg" "$cfg.bak.$STAMP"
    inc="$(mktemp)"; TMP_FILES+=("$inc")
    printf 'include "./cfg/angelos-minimize.kdl"\n' >"$inc"
    carry_includes "$inc" "$cfg"
  fi
}

# Discord's Go Live with sound crashes now and then when a program's sound stream comes or goes.
# With a mixer whose virtual outputs carry all the sound (a RØDECaster and the like: the default
# output is a PipeWire loopback), extras/discord-shield hides single programs' streams from
# Discord, which streams the mixes instead; without one it does nothing. A WirePlumber 0.5 script,
# linked into WirePlumber's own folders and read at its next start. DISCORD_SHIELD=0, or
# ~/.config/angelos/discord-shield.off, leaves it out.
install_discord_shield() {
  [[ "$DESKTOP_SHELL" == angelos && "$DISCORD_SHIELD" == 1 ]] || return 0
  [[ -e "$HOME_DIR/.config/angelos/discord-shield.off" ]] && return 0
  local src="$HOME_DIR/.config/quickshell/angelos/extras/discord-shield"
  local scripts="$HOME_DIR/.local/share/wireplumber/scripts/angelos"
  local conf="$HOME_DIR/.config/wireplumber/wireplumber.conf.d"
  [[ -f "$src/discord-shield.lua" ]] || return 0
  wireplumber --version 2>/dev/null | grep -q 'libwireplumber 0\.5' || return 0
  mkdir -p -- "$scripts" "$conf"
  ln -sfn -- "$src/discord-shield.lua" "$scripts/discord-shield.lua"
  ln -sfn -- "$src/90-angelos-discord-shield.conf" "$conf/90-angelos-discord-shield.conf"
}

# fish as the login shell (FISH_DEFAULT): fish installed by this run is added to /etc/shells
# and made the login shell; one that was there before is left as it is unless asked for.
# SYSROOT (tests): /etc/shells under it and a log line instead of chsh.
setup_fish_shell() {
  [[ "$FISH_DEFAULT" == 1 ]] || return 0
  if ((FISH_WAS_INSTALLED)) || [[ "$SKIP_PACKAGES" == 1 ]]; then given FISH_DEFAULT || return 0; fi
  local fish shells="$SYSROOT/etc/shells" user current
  fish="$(command -v fish 2>/dev/null || true)"
  if [[ -z "$fish" ]]; then
    warn "$(_ 'fish is not installed: the login shell stays as it is' 'fish не установлен: оболочка входа остаётся прежней')"
    return 0
  fi
  user="$(id -un)"
  if ! grep -qx -- "$fish" "$shells" 2>/dev/null; then
    as_root mkdir -p -- "${shells%/*}"
    printf '%s\n' "$fish" | as_root tee -a -- "$shells" >/dev/null
    say "$(_ "$fish added to /etc/shells" "$fish добавлен в /etc/shells")"
  fi
  if [[ -n "$SYSROOT" ]]; then
    printf '%s %s\n' "$user" "$fish" >>"$SYSROOT/chsh.log"
  else
    current="$(getent passwd "$user" | cut -d: -f7)"
    if [[ "$current" == "$fish" ]]; then
      say "$(_ 'fish is your login shell already' 'fish уже оболочка входа')"; return 0
    fi
    as_root chsh -s "$fish" "$user" ||
      { warn "$(_ "Could not change the login shell: chsh -s $fish" "Не удалось сменить оболочку входа: chsh -s $fish")"; return 0; }
  fi
  say "$(_ 'fish is your login shell from the next login ♡' 'fish — оболочка входа со следующего входа ♡')"
  fish_prompt_fallback
}

# Arch Linux has no fish-pure-prompt package: fisher fetches the same prompt (and done) instead
fish_prompt_fallback() {
  [[ -n "$SYSROOT" ]] && return 0
  [[ -d /usr/share/fish/vendor_functions.d && -f /usr/share/fish/vendor_functions.d/fish_prompt.fish ]] && return 0
  command -v fish >/dev/null 2>&1 && fish -c 'type -q fisher' 2>/dev/null || return 0
  fish -c 'fisher install pure-fish/pure franciscolourenco/done jorgebucaran/autopair.fish' >/dev/null 2>&1 &&
    say "$(_ 'fish: the pure prompt installed with fisher' 'fish: prompt pure поставлен через fisher')" ||
    warn "$(_ 'fisher could not fetch the pure prompt (offline?): fish keeps its own prompt' 'fisher не скачал prompt pure (нет сети?): у fish останется свой prompt')"
}

# the author's apps: scripts/apps-install.py installs them (pacman, the AUR, Flathub) and remembers
# the pick; "none" picked in the menu is remembered too (updates then offer only new groups' apps… none)
install_apps() {
  [[ "$SKIP_PACKAGES" != 1 ]] || return 0
  local ids=()
  [[ "$INSTALL_APPS" == 1 ]] && mapfile -t ids < <(chosen_apps)
  if ((${#ids[@]} == 0)); then
    ((APPS_ASKED)) && command -v python3 >/dev/null 2>&1 && python3 "$APPS_PY" pick >/dev/null 2>&1
    return 0
  fi
  need_python || { warn "$(_ 'python3 is missing: the apps are skipped' 'нет python3: программы пропущены')"; return 0; }
  # the first ticked browser becomes the default one (Mod+B, links)
  ANGELOS_LANG="$UI" python3 "$APPS_PY" install --no-wait --browser auto "${ids[@]}" ||
    warn "$(_ 'Not every app installed (see above); again: Settings → Updates → the apps' \
              'Не все программы поставились (смотри выше); ещё раз: Настройки → Обновления → программы')"
  return 0
}

# the steps of this file, in the order of the run (see step() in installer/lib/core.sh)
step 25 install_shell "angelOS" "angelOS"
step 30 install_minimize_hook "the windows' minimize button" "кнопка «свернуть» у окон"
step 32 install_discord_shield "Discord streams with a mixer" "стрим Discord с пультом"
step 45 install_apps "the apps" "программы"
step 50 setup_fish_shell "fish" "fish"
step 75 enable_services "user services" "user-сервисы"
