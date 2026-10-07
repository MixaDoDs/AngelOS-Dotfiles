#!/usr/bin/env bash
# Repository bug-check. Safe to run anywhere: the installer test uses a
# throw-away $HOME and never touches your real configuration.
#
#   ./scripts/check.sh            everything
#   SKIP_INSTALL_TEST=1 ./scripts/check.sh   static checks only (no installer, no update tests)
#   REQUIRE_UI=1 ./scripts/check.sh          a missing quickshell fails the Updates UI test (CI)
#   CHECK_UI=1 ./scripts/check.sh            the UI self-test (scripts/test-ui.sh) runs along (CI)
#   CHECK_JOBS=N ./scripts/check.sh          N checks at once (default: the CPUs)
#
# The checks run side by side: each block below is a job, the slowest started first, its
# lines printed together when it ends; whatever failed is listed once more at the end.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORK="$(mktemp -d)"
trap 'kill $(jobs -p) 2>/dev/null || true; rm -rf -- "$WORK"' EXIT
# no __pycache__ in the tree while other jobs copy it (the installer, the update tests)
export PYTHONDONTWRITEBYTECODE=1

pass() { printf '[check] OK   %s\n' "$*"; }
fail() { printf '[check] FAIL %s\n' "$*"; }
skip() { printf '[check] SKIP %s\n' "$*"; }

check_file() {
  [[ -f "$ROOT/$1" ]] && pass "file: $1" || fail "missing file: $1"
}

# search REGEX [extra rg args…]: print matches in the repo, succeed when there are some.
search() {
  local regex="$1"; shift
  if command -v rg >/dev/null 2>&1; then
    # .git is a file in a git worktree ("gitdir: /home/…"), a folder otherwise
    rg -n --hidden -g '!.git/**' -g '!.git' -g '!*.png' -g '!*.jpg' -g '!*.jpeg' -g '!*.webp' -g '!*.gif' \
       -g '!*.ttf' -g '!*.otb' -g '!*.svg' -g '!*.cache' "$@" -- "$regex" "$ROOT"
  else
    grep -rInE --exclude-dir=.git --exclude=.git --exclude='*.png' --exclude='*.jpg' --exclude='*.gif' \
         --exclude='*.ttf' --exclude='*.otb' -- "$regex" "$ROOT"
  fi
}

# ── Jobs ─────────────────────────────────────────────────────────────────────

JOBS="${CHECK_JOBS:-$(nproc 2>/dev/null || echo 4)}"
NAMES=()
declare -A SHOWN=()
# job NAME COMMAND…: in the background, at most $JOBS at once; its lines are printed when it ends.
# timed NAME COMMAND…: a job that measures time or waits within limits (the UI's shows and search
# speed, the shell's tests) — the others run niced, so on a busy machine these get the CPU first;
# and a timed job that fails runs once more (JOB_RETRY=0: not): a wait that ran out in the crowd
# passes then, with a warning that names what failed first — a real fault fails twice, and counts
timed() { JOB_NICE=0 JOB_RETRY="${JOB_RETRY:-1}" job "$@"; }
# a job still running after CHECK_TIMEOUT seconds (default 300) hangs: it is stopped, and fails
tree() { local c; echo "$1"; for c in $(pgrep -P "$1" 2>/dev/null); do tree "$c"; done; }
# (frozen first, all of it: a process pool would start new workers for killed ones)
killtree() { local p; p="$(tree "$1")"; kill -STOP $p 2>/dev/null; kill -KILL $p 2>/dev/null || true; }
# run_job NAME COMMAND…: one run; set -e inside, as for the whole script: a step that breaks
# stops the job, which fails, as does a hang
run_job() {
  local name="$1"; shift
  local rc pid dog limit="${JOB_LIMIT:-${CHECK_TIMEOUT:-300}}"
  rm -f "$WORK/job-$name.hung"
  (set -e; renice -n "${JOB_NICE:-15}" -p "$BASHPID" >/dev/null 2>&1 || true; "$@") & pid=$!
  { sleep "$limit"; touch "$WORK/job-$name.hung"; killtree "$pid"; } & dog=$!
  wait "$pid"; rc=$?
  killtree "$dog"
  if [[ -e "$WORK/job-$name.hung" ]]; then fail "$name: still running after $limit s (hangs?) — stopped"
  elif ((rc != 0)); then fail "$name: stopped (exit $rc)"; fi
}
job() {
  local name="$1"; shift
  while (( $(jobs -rp | wc -l) >= JOBS )); do wait -n 2>/dev/null || true; show_done; done
  NAMES+=("$name")
  { set +e; local t=$SECONDS first="$WORK/job-$name.first"
    run_job "$name" "$@" >"$first" 2>&1
    if [[ "${JOB_RETRY:-0}" == 1 ]] && grep -q '^\[check\] FAIL' "$first"; then
      run_job "$name" "$@"
      if ! grep -q '^\[check\] FAIL' "$WORK/job-$name.log"; then
        printf '[check] WARN %s passed only the second time; the first time:\n' "$name"
        grep '^\[check\] FAIL' "$first" | sed 's/^\[check\] FAIL/    /'
      fi
    else
      cat "$first"
    fi
    echo $((SECONDS - t)) >"$WORK/job-$name.done"; } >"$WORK/job-$name.log" 2>&1 &
}
show_done() {
  local name
  for name in "${NAMES[@]}"; do
    [[ -z "${SHOWN[$name]:-}" && -f "$WORK/job-$name.done" ]] || continue
    SHOWN[$name]=1
    printf '[check] ── %s (%ss)\n' "$name" "$(cat "$WORK/job-$name.done")"
    cat "$WORK/job-$name.log"
  done
}

# ── Syntax, the shell's own tests, shellcheck ───────────────────────────────

check_syntax() {
  while IFS= read -r -d '' file; do
    rel="${file#"$ROOT/"}"
    if bash -n "$file"; then pass "shell syntax: $rel"; else fail "shell syntax: $rel"; fi
  done < <(find "$ROOT" -type f \( -name '*.sh' -o -path "$ROOT/.local/bin/*" -o -name .install \) \
             -not -path "$ROOT/.git/*" -print0 | while IFS= read -r -d '' f; do
               head -n1 "$f" | grep -qE '^#!.*(bash|sh)$' && printf '%s\0' "$f"; done)

  if python3 - "$ROOT" <<'PY'
import ast, pathlib, sys
root = pathlib.Path(sys.argv[1])
for path in root.glob(".local/bin/*"):
    if path.is_file():
        text = path.read_text(errors="ignore")
        if text.startswith("#!") and "python" in text.splitlines()[0]:
            ast.parse(text, filename=str(path))
PY
  then pass "Python syntax"; else fail "Python syntax"; fi
}

check_plugin_studio() {
  if python3 "$ROOT/scripts/test-plugin-studio.py"; then
    pass "Plugin Studio: offline integration tests"
  else
    fail "Plugin Studio: offline integration tests"
  fi
}

# py_test LOG FILE "what passes" [77]: a test of the shell (tests/FILE), its log shown when it fails;
# with 77, its exit 77 means it can't run here (no gi / dbus): skipped
py_test() {
  local rc=0
  python3 "$ROOT/.config/quickshell/angelos/tests/$2" >"$WORK/$1.log" 2>&1 || rc=$?
  if ((rc == 0)); then
    pass "$3"
  elif ((rc == 77)) && [[ "${4:-}" == 77 ]]; then
    skip "${3%%:*}: $(tail -1 "$WORK/$1.log")"
  else
    sed 's/^/    /' "$WORK/$1.log"; fail "${3%%:*}: tests/$2"
  fi
}

check_author_tools() {
  if bash "$ROOT/.config/quickshell/angelos/tests/author/run.sh" >"$WORK/author.log" 2>&1; then
    pass "author's tools: only for an account GitHub lets in (stand-in gh)"
  else
    sed 's/^/    /' "$WORK/author.log"
    fail "author's tools: tests/author/run.sh"
  fi

  # the author's tools never ship (E): the chapter editor and owner/ live in the private repo
  if [[ -e "$ROOT/.config/quickshell/angelos/novel/editor" || -e "$ROOT/.config/quickshell/angelos/owner" ]] ||
     search 'novel/editor/nov-editor\.py' -g '!scripts/check.sh' >/dev/null 2>&1; then
    fail "the author's tools (novel/editor, owner/) are in the public tree"
  else
    pass "the author's tools stay out of the public tree"
  fi
}

check_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S warning "$ROOT/install.sh" "$ROOT/installer/tui.sh" "$ROOT/scripts/check.sh" "$ROOT/scripts/test-update.sh" "$ROOT/scripts/test-update-old.sh" "$ROOT/scripts/ci-local.sh" \
         "$ROOT/.config/quickshell/angelos/scripts/dotfiles-update.sh" "$ROOT/.config/quickshell/angelos/tests/updates/run.sh" &&
       shellcheck -s sh -S warning "$ROOT/.config/quickshell/angelos/bin/angelos" "$ROOT/.config/quickshell/angelos/scripts/author-tools.sh"; then
      pass "shellcheck"
    else
      fail "shellcheck"
    fi
  else
    skip "shellcheck (not installed)"
  fi
}

# ── Required files, Noctalia, SDDM theme, Niri config ────────────────────────

noctalia_cfg="$ROOT/.config/noctalia/config.toml"
wallpaper="$(sed -n 's|^path = "@HOME@/\(.*\)"$|\1|p' "$noctalia_cfg" | head -n 1)"

check_files() {
  for file in \
    install.sh .install installer/tui.sh \
    .config/niri/config.kdl .config/niri/cfg/keybinds.kdl .config/niri/cfg/keybinds-common.kdl \
    .config/niri/cfg/keybinds-pixel.kdl .config/niri/cfg/keybinds-macos.kdl .config/fish/config.fish \
    packages/fish.txt packages/nvim.txt packages/apps.txt packages/apps-flatpak.txt \
    .config/niri/config-no-noctalia.kdl .config/niri/noctalia.kdl \
    .config/niri/monitor.kdl .config/niri/cfg/input.kdl .config/niri/cfg/rules.kdl \
    .config/voxtype/config.toml \
    .config/gtk-3.0/bookmarks .config/gtk-4.0/bookmarks \
    .config/kitty/themes/noctalia.conf .config/alacritty/themes/noctalia.toml \
    .config/foot/themes/noctalia \
    .local/bin/niri-screenshot-region .local/bin/niri-record-region \
    .local/bin/niri-screenshot-region-simple .local/bin/niri-record-region-simple \
    .local/bin/niri-record-overlay .local/bin/niri-record-overlay-simple \
    .local/bin/niri-ocr .local/bin/voxtype-indicator \
    .config/systemd/user/niri-game-mode.service .config/systemd/user/voxtype.service \
    .config/systemd/user/voxtype-indicator.service \
    packages/pacman.txt packages/sddm.txt sddm/zz-pixelstreetart.conf \
    sddm/themes/pixel-cyberpunk/metadata.desktop sddm/themes/pixel-cyberpunk/Main.qml \
    sddm/themes/pixel-cyberpunk/BackgroundVideo.qml sddm/themes/pixel-cyberpunk/theme.conf \
    sddm/themes/pixel-cyberpunk/bg.mp4 sddm/themes/pixel-cyberpunk/LICENSE \
    LICENSE THIRD-PARTY.md LICENSES/OFL-1.1.txt .config/quickshell/angelos/docs/ICON-CREDITS.md; do
    check_file "$file"
  done

  # the theme key profiles are angelOS's templates, and keybinds.kdl picks one of them
  for prof in common pixel macos; do
    if cmp -s "$ROOT/.config/niri/cfg/keybinds-$prof.kdl" "$ROOT/.config/quickshell/angelos/templates/keybinds/keybinds-$prof.kdl"; then
      pass "niri keys: keybinds-$prof.kdl is angelOS's template"
    else
      fail "niri keys: keybinds-$prof.kdl differs from templates/keybinds (copy the template)"
    fi
  done
  if grep -qx 'include "keybinds-common.kdl"' "$ROOT/.config/niri/cfg/keybinds.kdl" &&
     grep -qx 'include "keybinds-pixel.kdl"' "$ROOT/.config/niri/cfg/keybinds.kdl"; then
    pass "niri keys: the selector picks the common and the pixel profile"
  else
    fail "niri keys: cfg/keybinds.kdl must include keybinds-common.kdl and keybinds-pixel.kdl"
  fi

  if [[ -n "$wallpaper" && -f "$ROOT/$wallpaper" ]]; then
    pass "Noctalia: default wallpaper $wallpaper is in the repository"
  else
    fail "Noctalia: default wallpaper '$wallpaper' is missing from the repository"
  fi
  if grep -q '^setup_wizard_enabled = false$' "$noctalia_cfg"; then
    pass "Noctalia: first-run wizard is off (the config is preseeded)"
  else
    fail "Noctalia: setup_wizard_enabled = false is missing"
  fi
  # A plugin widget whose plugin is not enabled renders nothing and warns.
  while read -r plugin; do
    if sed -n '/^enabled = \[/,/\]/p' "$noctalia_cfg" | grep -q "\"$plugin\""; then
      pass "Noctalia: widget plugin $plugin is enabled"
    else
      fail "Noctalia: a widget uses plugin $plugin, which is not in [plugins].enabled"
    fi
  done < <(sed -n 's|^type = "\([^":]*/[^":]*\):.*"$|\1|p' "$noctalia_cfg" | sort -u)

  theme_dir="$ROOT/sddm/themes/pixel-cyberpunk"
  current="$(sed -n 's/^Current=//p' "$ROOT/sddm/zz-pixelstreetart.conf")"
  main_script="$(sed -n 's/^MainScript=//p' "$theme_dir/metadata.desktop")"
  if [[ "$current" == pixel-cyberpunk && -n "$main_script" && -f "$theme_dir/$main_script" ]]; then
    pass "SDDM: drop-in selects the bundled theme, its MainScript exists"
  else
    fail "SDDM: drop-in theme ($current) / MainScript ($main_script) mismatch"
  fi
  if compgen -G "$theme_dir/font/*.ttf" >/dev/null; then
    pass "SDDM: theme font is bundled"
  else
    fail "SDDM: theme font is missing"
  fi
  # Every QML module the theme imports must come from a package in sddm.txt.
  declare -A qml_pkg=([QtQuick]=qt6-declarative [QtQuick.Window]=qt6-declarative
                      [Qt.labs.folderlistmodel]=qt6-declarative [Qt5Compat.GraphicalEffects]=qt6-5compat
                      [QtMultimedia]=qt6-multimedia [SddmComponents]=sddm)
  while read -r module; do
    pkg="${qml_pkg[$module]:-}"
    if [[ -n "$pkg" ]] && grep -qx "$pkg" "$ROOT/packages/sddm.txt"; then
      pass "SDDM: QML import $module is provided by $pkg"
    else
      fail "SDDM: QML import $module has no package in packages/sddm.txt"
    fi
  done < <(sed -n 's/^import[[:space:]]\+\([A-Za-z0-9_.]\+\).*/\1/p' "$theme_dir"/*.qml | sort -u)

  if command -v niri >/dev/null 2>&1; then
    if niri validate -c "$ROOT/.config/niri/config.kdl" >/dev/null 2>&1 &&
       niri validate -c "$ROOT/.config/niri/config-no-noctalia.kdl" >/dev/null 2>&1; then
      pass "Niri KDL validation (both variants)"
    else
      fail "Niri KDL validation"
    fi
  else
    skip "Niri KDL validation (niri is not installed)"
  fi

  # The mouse must stay at libinput defaults: forcing a flat/slow profile is what
  # made the pointer feel sluggish for other people.
  if grep -Eq '^[[:space:]]*(accel-speed|accel-profile)' "$ROOT/.config/niri/cfg/input.kdl"; then
    fail "input.kdl sets a mouse acceleration profile/speed"
  else
    pass "input.kdl leaves pointer speed at libinput defaults"
  fi

  # Glowing windows: translucent + blurred windows, inactive dimming, or the thick
  # default focus ring all "lit up" windows as focus followed the mouse.
  if grep -Eq '^[[:space:]]*(blur[[:space:]]+true|opacity[[:space:]]+0\.[0-9]+)' "$ROOT/.config/niri/cfg/rules.kdl"; then
    fail "rules.kdl makes windows translucent/blurred (they glow under focus-follows-mouse)"
  else
    pass "rules.kdl keeps windows opaque, no blur"
  fi
  ring_width="$(awk '/focus-ring[[:space:]]*\{/{f=1} f && /width/{print $2; exit}' "$ROOT/.config/niri/cfg/layout.kdl")"
  if [[ -n "$ring_width" ]] && ((ring_width <= 2)); then
    pass "layout.kdl uses a thin focus ring (${ring_width}px)"
  else
    fail "layout.kdl must set a thin focus-ring width (Niri's default 4px ring looks like a glow)"
  fi
}

# ── Installer, end to end ────────────────────────────────────────────────────

# fc-cache waits out the second the fonts were written in (2 s a run): a stand-in, as in the update tests
mkdir -p "$WORK/stubs"
printf '#!/bin/sh\nexit 0\n' >"$WORK/stubs/fc-cache"
chmod +x "$WORK/stubs/fc-cache"

# install_case NAME [VAR=value…] runs the installer in a fresh fake $HOME.
install_case() {
  local name="$1"; shift
  local home="$WORK/$name"
  mkdir -p "$home"
  env -i HOME="$home" PATH="$WORK/stubs:$PATH" LANG=C \
      SKIP_PACKAGES=1 INSTALL_VOXTYPE=0 DOWNLOAD_VOXTYPE_MODEL=0 \
      ENABLE_SERVICES=0 INSTALL_WALLPAPERS=0 INSTALL_SDDM=0 "$@" \
      "$ROOT/install.sh" >"$WORK/$name.log" 2>&1 </dev/null
}

expect_line() { # NAME FILE REGEX DESCRIPTION
  if grep -Eq "$3" "$WORK/$1/$2"; then pass "$4"; else fail "$4"; fi
}

input=".config/niri/cfg/input.kdl"

inst_default() {
  if install_case default; then
    pass "installer: default run"
    if [[ -L "$WORK/default/.local/bin/angelos" &&
          -f "$WORK/default/.config/quickshell/angelos/shell.qml" &&
          ! -e "$WORK/default/.config/angelos/owner" ]] &&
       grep -qx angelos "$WORK/default/.config/angelos/active"; then
      pass "installer: angelOS is the default, fresh installs have no owner marker"
    else
      fail "installer: angelOS default/owner marker"
    fi
    expect_line default "$input" '^[[:space:]]*layout "us,ru"$'                  "installer: default layouts us,ru"
    expect_line default "$input" '^[[:space:]]*options "grp:alt_shift_toggle"$'  "installer: default switch Alt+Shift"
    # what the installer asked ("with the game?", the layouts) the first-run wizard won't ask again;
    # the default run asked nothing, so it wrote nothing
    if install_case nogame ANGELOS_GAME=0 KB_LAYOUTS=us,de &&
       python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); s = d["setup"]; sys.exit(0 if d["game"]["enabled"] is False and s["gameAsked"] is True and s["keyboardAsked"] is True else 1)' \
         "$WORK/nogame/.config/angelos/settings.json" 2>/dev/null && [[ ! -e "$WORK/default/.config/angelos/settings.json" ]]; then
      pass "installer: ANGELOS_GAME=0 and KB_LAYOUTS are kept, the wizard won't ask them again"
    else
      fail "installer: ANGELOS_GAME=0 and KB_LAYOUTS are kept, the wizard won't ask them again"
    fi
    if grep -rEq '@(HOME|KB_LAYOUT|KB_OPTIONS|KB_VARIANT|VOXTYPE_LANG)@' \
         "$WORK/default/.config" "$WORK/default/.local/bin" 2>/dev/null; then
      fail "installer: unresolved @PLACEHOLDER@ left in installed files"
    else
      pass "installer: every placeholder resolved"
    fi
    if command -v niri >/dev/null 2>&1; then
      niri validate -c "$WORK/default/.config/niri/config.kdl" >/dev/null 2>&1 &&
        pass "installer: installed config validates" || fail "installer: installed config validates"
    fi
    # Updating the owner's installation must not disable publishing.
    printf 'remote=fixture\n' > "$WORK/default/.config/angelos/owner"
    printf '{"setup":{"complete":true}}\n' > "$WORK/default/.config/angelos/settings.json"
    # Second run must change nothing except what the user owns.
    if install_case default && grep -q 'Files: 0 installed' "$WORK/default.log"; then
      pass "installer: re-run is idempotent"
    else
      fail "installer: re-run is idempotent"
    fi
    # fish's snippet and the LazyVim config come with a fresh install…
    if [[ -f "$WORK/default/.config/fish/conf.d/angelos-tools.fish" &&
          -f "$WORK/default/.config/nvim/lua/config/lazy.lua" ]]; then
      pass "installer: fish snippet and the Neovim config installed"
    else
      fail "installer: fish snippet and the Neovim config installed"
    fi
    # …but someone's own Neovim config is left whole, never mixed with ours
    mkdir -p "$WORK/ownnvim/.config/nvim"
    echo '-- my own' >"$WORK/ownnvim/.config/nvim/init.lua"
    if install_case ownnvim && grep -qx -- '-- my own' "$WORK/ownnvim/.config/nvim/init.lua" &&
       [[ ! -e "$WORK/ownnvim/.config/nvim/lua" ]]; then
      pass "installer: an existing ~/.config/nvim stays the user's own"
    else
      fail "installer: an existing ~/.config/nvim stays the user's own"
    fi
    if grep -qx 'remote=fixture' "$WORK/default/.config/angelos/owner" &&
       grep -qx '{"setup":{"complete":true}}' "$WORK/default/.config/angelos/settings.json"; then
      pass "installer: existing angelOS settings and owner marker survive an update"
    else
      fail "installer: existing angelOS settings and owner marker survive an update"
    fi
    # An update keeps what the user (or angelOS's settings) changed, and still
    # brings new versions of the files nobody touched (issue #23).
    d="$WORK/default"
    echo '// my own binds' >>"$d/.config/niri/cfg/keybinds.kdl"
    printf '[Default Applications]\nx-scheme-handler/http=firefox.desktop\n' >"$d/.config/mimeapps.list"
    ff=".config/fastfetch/config.jsonc"
    echo '{ "old": true }' >"$d/$ff"
    manifest="$d/.local/state/angelos/installed-files.sha256"
    sed -i "s|^[0-9a-f]*  $ff\$|$(sha256sum "$d/$ff" | cut -d' ' -f1)  $ff|" "$manifest"
    install_case default || fail "installer: update run with changed configs"
    if grep -q '// my own binds' "$d/.config/niri/cfg/keybinds.kdl" &&
       grep -q 'firefox.desktop' "$d/.config/mimeapps.list" &&
       [[ -f "$d/.local/state/angelos/kept-updates/.config/niri/cfg/keybinds.kdl" ]]; then
      pass "installer: an update keeps changed configs (new versions parked)"
    else
      fail "installer: an update keeps changed configs (new versions parked)"
    fi
    # (the repository's file as installed: @HOME@ filled in, as the fastfetch config has it)
    if cmp -s <(sed "s|@HOME@|$d|g" "$ROOT/$ff") "$d/$ff"; then
      pass "installer: an update refreshes configs the user did not change"
    else
      fail "installer: an update refreshes configs the user did not change"
    fi
    # (valid KDL: an invalid niri config now fails the installer)
    echo 'output "X" { scale 2; }' >"$WORK/default/.config/niri/monitor.kdl"
    install_case default || fail "installer: run with the user's monitor.kdl"
    if grep -q 'scale 2' "$WORK/default/.config/niri/monitor.kdl"; then
      pass "installer: existing monitor.kdl is preserved"
    else
      fail "installer: existing monitor.kdl is preserved"
    fi
    # A config niri refuses: the installer says so and exits with an error instead of "Done".
    if command -v niri >/dev/null 2>&1; then
      echo 'output "X" { scale 2 }' >"$WORK/default/.config/niri/monitor.kdl"
      if install_case default; then
        fail "installer: a config niri refuses fails the run"
      elif grep -q 'failed validation' "$WORK/default.log"; then
        pass "installer: a config niri refuses fails the run"
      else
        fail "installer: a config niri refuses fails the run (no validation message)"
      fi
    else
      skip "installer: a config niri refuses fails the run (niri is not installed)"
    fi
  else
    fail "installer: default run"; sed 's/^/    /' "$WORK/default.log"
  fi
}

inst_noctalia() {
  if install_case noctalia DESKTOP_SHELL=noctalia; then
    expect_line noctalia .config/noctalia/config.toml '^setup_wizard_enabled = false$' \
      "installer: Noctalia config is preseeded"
    if command -v noctalia >/dev/null 2>&1; then
      if noctalia config validate "$WORK/noctalia/.config/noctalia/config.toml" >"$WORK/noctalia-validate" 2>&1 &&
         ! grep -Eq '^(WARN|ERROR)' "$WORK/noctalia-validate"; then
        pass "installer: installed Noctalia config validates without warnings"
      else
        fail "installer: installed Noctalia config validates without warnings"; sed 's/^/    /' "$WORK/noctalia-validate"
      fi
    else
      skip "Noctalia config validation (noctalia is not installed)"
    fi
    if [[ -f "$WORK/noctalia/$wallpaper" ]]; then
      pass "installer: default wallpaper installed for Noctalia"
    else
      fail "installer: default wallpaper installed for Noctalia"
    fi
  else
    fail "installer: Noctalia run"; sed 's/^/    /' "$WORK/noctalia.log"
  fi
}

inst_layouts() {
  if install_case layouts KB_LAYOUTS="us de ua" KB_TOGGLE=ctrl_shift; then
    expect_line layouts "$input" '^[[:space:]]*layout "us,de,ua"$'                  "installer: custom layouts (KB_LAYOUTS)"
    expect_line layouts "$input" '^[[:space:]]*options "grp:ctrl_shift_toggle"$'    "installer: custom switch (KB_TOGGLE)"
  else
    fail "installer: custom layouts"; sed 's/^/    /' "$WORK/layouts.log"
  fi
}

inst_macos() {
  # the theme step: Golden Gate (macOS) in settings.json and the Mac key profile in front
  if install_case macos ANGELOS_THEME=macos; then
    if python3 -c 'import json, sys; u = json.load(open(sys.argv[1]))["settingsUi"]; sys.exit(0 if u["skin"] == "goldengate" and u["skinChosen"] is True else 1)' \
         "$WORK/macos/.config/angelos/settings.json" 2>/dev/null; then
      pass "installer: ANGELOS_THEME=macos picks Golden Gate (the wizard won't ask again)"
    else
      fail "installer: ANGELOS_THEME=macos picks Golden Gate"
    fi
    expect_line macos .config/niri/cfg/keybinds.kdl '^include "keybinds-macos\.kdl"$' "installer: ANGELOS_THEME=macos puts the Mac keys in front"
    if command -v niri >/dev/null 2>&1; then
      niri validate -c "$WORK/macos/.config/niri/config.kdl" >/dev/null 2>&1 &&
        pass "installer: the Mac key profile validates" || fail "installer: the Mac key profile validates"
    fi
    if install_case macos ANGELOS_THEME=macos && grep -q 'Files: 0 installed' "$WORK/macos.log" &&
       [[ ! -d "$WORK/macos/.local/state/angelos/kept-updates/.config/niri/cfg" ]]; then
      pass "installer: the theme's key profile is the installer's own (re-run changes nothing)"
    else
      fail "installer: re-run after ANGELOS_THEME=macos"
    fi
  else
    fail "installer: ANGELOS_THEME=macos"; sed 's/^/    /' "$WORK/macos.log"
  fi
}

inst_mackeys0() {
  # Golden Gate without the Mac keys: the look, the pixel key profile
  if install_case mackeys0 ANGELOS_THEME=macos MAC_KEYS=0 &&
     python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); sys.exit(0 if d["settingsUi"]["skin"] == "goldengate" and d["mac"]["keys"] is False else 1)' \
       "$WORK/mackeys0/.config/angelos/settings.json" 2>/dev/null; then
    expect_line mackeys0 .config/niri/cfg/keybinds.kdl '^include "keybinds-pixel\.kdl"$' "installer: MAC_KEYS=0 keeps the pixel keys with Golden Gate"
  else
    fail "installer: ANGELOS_THEME=macos MAC_KEYS=0"
  fi
}

inst_pixel() {
  if install_case pixel ANGELOS_THEME=pixel &&
     python3 -c 'import json, sys; sys.exit(0 if json.load(open(sys.argv[1]))["settingsUi"]["skin"] == "classic" else 1)' \
       "$WORK/pixel/.config/angelos/settings.json" 2>/dev/null; then
    expect_line pixel .config/niri/cfg/keybinds.kdl '^include "keybinds-pixel\.kdl"$' "installer: ANGELOS_THEME=pixel keeps the pixel keys"
  else
    fail "installer: ANGELOS_THEME=pixel"
  fi
}

inst_fish() {
  # fish as the login shell: /etc/shells and chsh land in a fake system root (no real chsh)
  if command -v fish >/dev/null 2>&1; then
    fishroot="$WORK/fishroot"; mkdir -p "$fishroot/etc"; printf '/bin/bash\n' >"$fishroot/etc/shells"
    if install_case fishsh FISH_DEFAULT=1 SYSROOT="$fishroot" &&
       grep -qx "$(command -v fish)" "$fishroot/etc/shells" && grep -qx '/bin/bash' "$fishroot/etc/shells" &&
       grep -q " $(command -v fish)\$" "$fishroot/chsh.log"; then
      pass "installer: FISH_DEFAULT=1 adds fish to /etc/shells and makes it the login shell"
    else
      fail "installer: FISH_DEFAULT=1"; sed 's/^/    /' "$WORK/fishsh.log"
    fi
    # a fish that was there already is left alone unless asked for
    if install_case fishkeep SYSROOT="$WORK/fishkeep-root" && [[ ! -e "$WORK/fishkeep-root/chsh.log" && ! -e "$WORK/fishkeep-root/etc/shells" ]]; then
      pass "installer: an installed fish is left alone (no chsh without FISH_DEFAULT=1)"
    else
      fail "installer: an installed fish is left alone"
    fi
  else
    skip "installer: fish login shell (fish is not installed)"
  fi
}

inst_single() {
  if install_case single KB_LAYOUTS=us; then
    expect_line single "$input" '^[[:space:]]*options ""$' "installer: single layout has no switch shortcut"
  else
    fail "installer: single layout"
  fi
}

inst_tech() {
  if install_case tech DOTFILES_MODE=tech; then
    if [[ ! -e "$WORK/tech/.local/share" && ! -e "$WORK/tech/.config/noctalia" && ! -e "$WORK/tech/Pictures" ]] &&
       ! grep -q noctalia "$WORK/tech/.config/niri/config.kdl"; then
      pass "installer: tech profile is minimal"
    else
      fail "installer: tech profile is minimal"
    fi
  else
    fail "installer: tech profile"; sed 's/^/    /' "$WORK/tech.log"
  fi
}

inst_nonoctalia() {
  if install_case nonoctalia NOCTALIA=0 && [[ ! -e "$WORK/nonoctalia/.config/noctalia" ]]; then
    pass "installer: NOCTALIA=0 skips Noctalia files"
  else
    fail "installer: NOCTALIA=0 skips Noctalia files"
  fi
}

inst_voice() {
  # Dictation language follows the layouts (fake binary, so nothing is downloaded).
  mkdir -p "$WORK/voice/.local/bin"
  printf '#!/bin/sh\necho "voxtype 1.1.0"\n' >"$WORK/voice/.local/bin/voxtype"
  chmod +x "$WORK/voice/.local/bin/voxtype"
  if install_case voice INSTALL_VOXTYPE=1 KB_LAYOUTS="us ua"; then
    expect_line voice .config/voxtype/config.toml '^language = "uk"$' "installer: Voxtype language follows layouts (ua -> uk)"
  else
    fail "installer: Voxtype config"; sed 's/^/    /' "$WORK/voice.log"
  fi
}

inst_sddm() {
  # SDDM: theme and drop-in land in a fake system root; a theme pinned in
  # /etc/sddm.conf (read last by SDDM) gets commented out with a backup.
  sysroot="$WORK/sysroot"
  mkdir -p "$sysroot/etc"
  printf '[Autologin]\nUser=\n\n[Theme]\nCurrent=breeze\n\n[Users]\nCurrent=keep-me\n' >"$sysroot/etc/sddm.conf"
  if install_case sddm INSTALL_SDDM=1 SYSROOT="$sysroot"; then
    if diff -rq "$ROOT/sddm/themes/pixel-cyberpunk" "$sysroot/usr/share/sddm/themes/pixel-cyberpunk" >/dev/null &&
       cmp -s "$ROOT/sddm/zz-pixelstreetart.conf" "$sysroot/etc/sddm.conf.d/zz-pixelstreetart.conf"; then
      pass "installer: SDDM theme and drop-in installed"
    else
      fail "installer: SDDM theme and drop-in installed"
    fi
    if grep -q '^# Current=breeze' "$sysroot/etc/sddm.conf" && grep -q '^Current=keep-me' "$sysroot/etc/sddm.conf" &&
       compgen -G "$sysroot/etc/sddm.conf.bak.*" >/dev/null; then
      pass "installer: theme pinned in /etc/sddm.conf is unpinned (other sections untouched, backup kept)"
    else
      fail "installer: theme pinned in /etc/sddm.conf is unpinned"
    fi
    if [[ -z "$(find "$sysroot/usr/share/sddm/themes/pixel-cyberpunk" \! -perm -o=r)" ]]; then
      pass "installer: SDDM theme is readable by the sddm user"
    else
      fail "installer: SDDM theme is readable by the sddm user"
    fi
  else
    fail "installer: SDDM"; sed 's/^/    /' "$WORK/sddm.log"
  fi
}

inst_bad() {
  # Bad input must be refused, not written into the config.
  i=0
  for bad in "KB_LAYOUTS=us zz9" "KB_TOGGLE=nonsense" "DOTFILES_MODE=nope" "NOCTALIA=2" "GITHUB_LOGIN=2" \
             "ANGELOS_THEME=windows" "FISH_DEFAULT=2" "INSTALL_APPS=yes" "MAC_KEYS=2"; do
    i=$((i + 1))
    if install_case "bad$i" "$bad"; then fail "installer rejects: $bad"; else pass "installer rejects: $bad"; fi
  done
}

inst_reset() {
  # Noctalia GUI settings from an earlier run: kept unless a reset is asked for.
  reset="$1"
  state="$WORK/reset$reset/.local/state/noctalia"
  mkdir -p "$state"
  echo '[bar.default]' >"$state/settings.toml"
  if install_case "reset$reset" DESKTOP_SHELL=noctalia NOCTALIA_RESET_SETTINGS=$reset; then
    if [[ "$reset" == 1 ]]; then
      [[ ! -e "$state/settings.toml" ]] && compgen -G "$state/settings.toml.bak.*" >/dev/null &&
        pass "installer: NOCTALIA_RESET_SETTINGS=1 moves old Noctalia settings aside" ||
        fail "installer: NOCTALIA_RESET_SETTINGS=1 moves old Noctalia settings aside"
    else
      [[ -f "$state/settings.toml" ]] &&
        pass "installer: existing Noctalia settings are kept by default" ||
        fail "installer: existing Noctalia settings are kept by default"
    fi
  else
    fail "installer: Noctalia settings reset=$reset"; sed 's/^/    /' "$WORK/reset$reset.log"
  fi
}

# Arch Linux and CachyOS only: an install with packages on anything else is refused before
# a file changes. pacman and sudo are stand-ins here: a refusal that slipped would reach them
printf 'NAME="Ubuntu"\nID=ubuntu\nID_LIKE=debian\nPRETTY_NAME="Ubuntu 26.04 LTS"\n' > "$WORK/os-ubuntu"
printf 'NAME="EndeavourOS"\nID=endeavouros\nID_LIKE=arch\nPRETTY_NAME="EndeavourOS"\n' > "$WORK/os-eos"
printf 'NAME="Arch Linux ARM"\nID=archarm\nID_LIKE=arch\nPRETTY_NAME="Arch Linux ARM"\n' > "$WORK/os-alarm"
printf 'NAME="Arch Linux"\nID=arch\nPRETTY_NAME="Arch Linux"\n' > "$WORK/os-arch"
mkdir -p "$WORK/nopkg"
for c in pacman sudo; do printf '#!/bin/sh\necho "%s must not run in this test" >&2\nexit 1\n' "$c" >"$WORK/nopkg/$c"; done
chmod +x "$WORK/nopkg"/*
PKG=(SKIP_PACKAGES=0 PATH="$WORK/nopkg:$WORK/stubs:$PATH")

inst_distro_ubuntu() {
  if ! install_case distro-ubuntu "${PKG[@]}" DOTFILES_OS_RELEASE="$WORK/os-ubuntu" && grep -q 'Only Arch Linux and CachyOS are supported' "$WORK/distro-ubuntu.log" &&
     [[ -z "$(find "$WORK/distro-ubuntu" -mindepth 1 -print -quit)" ]]; then
    pass "installer refuses Ubuntu, nothing written"
  else
    fail "installer refuses Ubuntu, nothing written"; sed 's/^/    /' "$WORK/distro-ubuntu.log"
  fi
}

inst_distro_eos() {
  if ! install_case distro-eos "${PKG[@]}" DOTFILES_OS_RELEASE="$WORK/os-eos" && grep -q 'based on Arch, but only Arch Linux and CachyOS' "$WORK/distro-eos.log"; then
    pass "installer refuses an Arch-based distribution with its own repositories (EndeavourOS)"
  else
    fail "installer refuses EndeavourOS"; sed 's/^/    /' "$WORK/distro-eos.log"
  fi
}

inst_distro_force() {
  # forced past the check (then stopped by bad input, so the run stays short)
  if ! install_case distro-force "${PKG[@]}" DOTFILES_OS_RELEASE="$WORK/os-ubuntu" DOTFILES_FORCE_DISTRO=1 KB_TOGGLE=nonsense &&
     grep -q 'going on because DOTFILES_FORCE_DISTRO=1' "$WORK/distro-force.log" && ! grep -q 'Only Arch Linux' "$WORK/distro-force.log"; then
    pass "installer: DOTFILES_FORCE_DISTRO=1 goes on with a warning"
  else
    fail "installer: DOTFILES_FORCE_DISTRO=1"; sed 's/^/    /' "$WORK/distro-force.log"
  fi
}

inst_distro_arch() {
  if install_case distro-arch "${PKG[@]}" DOTFILES_OS_RELEASE="$WORK/os-arch" KB_TOGGLE=nonsense; grep -qE 'Only Arch|not supported' "$WORK/distro-arch.log"; then
    fail "installer accepts Arch Linux"
  else
    pass "installer accepts Arch Linux"
  fi
}

inst_distro_alarm() {
  # configs only (SKIP_PACKAGES=1, the way Settings → Updates runs it) installs no packages: a system
  # set up with DOTFILES_FORCE_DISTRO=1 (Arch Linux ARM, issue #36) must be able to update
  if install_case distro-alarm DOTFILES_OS_RELEASE="$WORK/os-alarm" && grep -q 'SKIP_PACKAGES=1 installs no packages' "$WORK/distro-alarm.log" &&
     [[ -f "$WORK/distro-alarm/.config/quickshell/angelos/shell.qml" ]]; then
    pass "installer: configs only (SKIP_PACKAGES=1) on Arch Linux ARM goes on with a warning"
  else
    fail "installer: configs only on Arch Linux ARM"; sed 's/^/    /' "$WORK/distro-alarm.log"
  fi
  if ! grep -q $'\033' "$WORK/distro-alarm.log"; then
    pass "installer: no colour codes when the output is not a terminal (the Updates log)"
  else
    fail "installer: colour codes in a log that is not a terminal"
  fi
}

# ── Settings → Updates: update, failures, restore ────────────────────────────

# A throw-away $HOME and a local origin (scripts/test-update.sh): a good update,
# a failing installer, a niri config niri refuses, niri missing, a snapshot that
# cannot be written, restores that work, conflict and fail — and the UI's view
# (tests/updates/run.sh, a job of its own here)
check_updates() {
  if UPDATE_UI=0 bash "$ROOT/scripts/test-update.sh" >"$WORK/update.log" 2>&1; then
    grep -E '^\[update\] SKIP|^  ✕' "$WORK/update.log" | grep -v 'UPDATE_UI=0' || true
    pass "updates: success, failures, restore"
  else
    sed 's/^/    /' "$WORK/update.log"
    fail "updates: scripts/test-update.sh"
  fi
}
check_updates_ui() {
  local rc=0 shell="$ROOT/.config/quickshell/angelos"
  bash "$shell/tests/updates/run.sh" "$shell" >"$WORK/update-ui.log" 2>&1 || rc=$?
  if ((rc == 0)); then
    pass "updates: the Settings → Updates UI handles failure, restore and success"
  elif ((rc == 77)) && [[ "${REQUIRE_UI:-0}" != 1 ]]; then
    skip "updates: the Settings → Updates UI (quickshell is not installed)"
  else
    sed 's/^/    /' "$WORK/update-ui.log"; fail "updates: the Settings → Updates UI (tests/updates/run.sh, exit $rc)"
  fi
}
# the way a user meets it: installed from older commits, their own old script updating to
# this tree, then the new one once more (scripts/test-update-old.sh; issue #36 among them)
check_updates_old() {
  if bash "$ROOT/scripts/test-update-old.sh" >"$WORK/update-old.log" 2>&1; then
    grep -E '^\[update-old\] SKIP' "$WORK/update-old.log" || true
    pass "updates: old installs (2026-09-30, 10-01, 10-02 on Arch Linux ARM) → this tree → UPDATED"
  else
    sed 's/^/    /' "$WORK/update-old.log"
    fail "updates: scripts/test-update-old.sh"
  fi
}
# the offscreen UI self-test, alongside the rest (CHECK_UI=1, as in CI)
check_ui() {
  if bash "$ROOT/.config/quickshell/angelos/scripts/test-ui.sh" "$ROOT/.config/quickshell/angelos" >"$WORK/ui.log" 2>&1; then
    grep '⚠' "$WORK/ui.log" || true
    pass "UI self-test: $(grep -c '✓' "$WORK/ui.log") checks (scripts/test-ui.sh)"
  else
    grep -v '✓' "$WORK/ui.log" | sed 's/^/    /'
    fail "UI self-test (scripts/test-ui.sh)"
  fi
}

# ── Hygiene ──────────────────────────────────────────────────────────────────

check_hygiene() {
  # API keys and tokens: never in the repository (the author's or anyone's)
  if search '(sk-ant-[A-Za-z0-9_-]{16,}|sk-(proj-)?[A-Za-z0-9]{32,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[abprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|(API_KEY|AUTH_TOKEN|ACCESS_TOKEN|SECRET)[A-Z_]*[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9_./+-]{20,})' \
       -g '!scripts/check.sh' >"$WORK/tokens" 2>/dev/null; then
    cat "$WORK/tokens"
    fail "an API key or token is in the repository"
  else
    pass "no API keys or tokens"
  fi

  if search '/home/mixad|/home/[A-Za-z0-9_.-]+/\.config/gh/hosts\.yml|Cookies|Login Data|Bitwarden/data\.json|keyrings|voxtype/models' \
       -g '!scripts/check.sh' -g '!README.md' -g '!.gitignore' -g '!install.sh' >"$WORK/sensitive" 2>/dev/null; then
    cat "$WORK/sensitive"
    fail "personal path or secret-like data detected"
  else
    pass "no personal paths or secret-like data"
  fi

  {
    grep -nE '^[[:space:]]*output "[^"]+"' \
      "$ROOT/.config/niri/monitor.kdl" "$ROOT/.config/niri/cfg/display.kdl" 2>/dev/null || true
    grep -RInE '^[[:space:]]*Environment=WAYLAND_DISPLAY=wayland-[0-9]+' \
      "$ROOT/.config/systemd" 2>/dev/null || true
    grep -RInE '"(screen|connectorName)"[[:space:]]*:' \
      "$ROOT/.config/angelos" "$ROOT/.config/kwinoutputconfig.json" 2>/dev/null || true
  } >"$WORK/machine"
  if [[ -s "$WORK/machine" ]]; then
    cat "$WORK/machine"
    fail "machine-specific monitor/runtime state detected"
  else
    pass "no machine-specific monitor/runtime state"
  fi

  if grep -Eq '^(bitwarden|discord|firefox|helium-browser-bin|telegram-desktop|steam|spotify-launcher|throne-bin|openai-codex-bin)$' \
       "$ROOT/packages/pacman.txt" "$ROOT/packages/aur.txt" 2>/dev/null; then
    fail "non-rice applications found in the default package manifests"
  else
    pass "default package manifests stay rice-focused"
  fi

  # Inline comments in a package list would be passed to pacman verbatim.
  for list in pacman.txt sddm.txt angelos.txt tools.txt fish.txt nvim.txt apps.txt apps-flatpak.txt; do
    if grep -Ev '^[[:space:]]*(#|$)' "$ROOT/packages/$list" | grep -q '[[:space:]#]'; then
      fail "packages/$list: package lines must contain only the name"
    else
      pass "packages/$list: one clean package name per line"
    fi
  done
}

# ── Run ──────────────────────────────────────────────────────────────────────

# the slowest first, so none of them waits for a free slot at the end
# (its own shards stop at 8 min each, and a failed one runs once more by itself)
[[ "${CHECK_UI:-0}" == 1 ]] && JOB_LIMIT=600 JOB_RETRY=0 timed ui check_ui
if [[ "${SKIP_INSTALL_TEST:-0}" == 1 ]]; then
  skip "installer tests (SKIP_INSTALL_TEST=1)"
  skip "update tests (SKIP_INSTALL_TEST=1)"
  skip "old installs → update (SKIP_INSTALL_TEST=1)"
else
  # the longest: not niced either, the run waits for them
  timed updates check_updates
  timed updates-old check_updates_old
  timed updates-ui check_updates_ui
  timed installer-default inst_default
fi
job plugin-studio check_plugin_studio
job sprite-rig py_test sprite-rig sprites/test_sprite_rig.py "sprite-rig: authored frame strips"
timed audio-tap py_test audio-tap audio/test_audio_tap.py "cava's audio tap: no hangs (stand-ins for cava and pw-record)"
# the Golden Gate menu bar's helper: menus found by the window's pid, on a private bus (77 = no gi / dbus)
timed appmenu py_test appmenu appmenu/test_appmenu.py "global menu: Qt, GTK, appmenu-gtk-module and X11 menus found by pid, clicks reach the app" 77
timed appmenu-profiles py_test profiles appmenu/test_profiles.py "global menu: standard menus for apps without their own — every item runnable"
# the Golden Gate skin outside the shell: system font, icons and GTK module on and back, Qt's look,
# the templates' Mac variants and their niri config (stand-ins for gsettings and fc-list)
timed goldengate py_test goldengate goldengate/test_goldengate.py "Golden Gate: system settings on and back, Qt's look, template variants, niri-mac.kdl valid"
# the Golden Gate Dock's icons: MacTahoe put together from its release, nothing executed, no link out
timed mac-icons py_test macicons goldengate/test_mac_icons.py "Golden Gate Dock icons: MacTahoe built from its archive, links kept inside, only ours removed"
timed browsers py_test browsers browsers/test_browser_theme.py "browser themes: profile edits, undo, gentle restart (stand-in browsers)"
# the way out of the first-run wizard: `angelos setup skip` works with no shell answering
timed setup py_test setup setup/test_cli.py "setup wizard: \`angelos setup skip\` gets out, with or without a running shell"
# the settings tree: every group on one page, no setting lost since the rebuild, every direct link
timed settings-tree py_test tree settings/test_tree.py "settings tree: every group once, no setting lost, every direct link leads somewhere"
timed qt-look py_test qt qt/test_qt_theme.py "Qt look: Telegram's own fields left to it, running apps told (throw-away HOME)"
# the avatar's file chooser: the portal's, else zenity; a word when there is none (77 = no gi / dbus)
timed file-chooser py_test pick settings/test_pick_file.py "file chooser: the XDG portal's, zenity when it can't, a reason when there is none" 77
timed switch py_test switch theme/test_switch.py "switch.py on an update: the user's palette, not the stock one; one Voxtype (throw-away HOME)"
job author-tools check_author_tools
job shellcheck check_shellcheck
if [[ "${SKIP_INSTALL_TEST:-0}" != 1 ]]; then
  for c in noctalia layouts macos mackeys0 pixel fish single tech nonoctalia voice sddm bad; do
    job "installer-$c" "inst_$c"
  done
  job installer-reset0 inst_reset 0
  job installer-reset1 inst_reset 1
  for c in ubuntu eos force arch alarm; do
    job "installer-distro-$c" "inst_distro_$c"
  done
fi
job syntax check_syntax
job files check_files
job hygiene check_hygiene

while (( $(jobs -rp | wc -l) )); do wait -n 2>/dev/null || true; show_done; done
wait || true
show_done
for name in "${NAMES[@]}"; do
  [[ -z "${SHOWN[$name]:-}" ]] || continue
  cat "$WORK/job-$name.log"; fail "$name: did not finish" | tee -a "$WORK/job-unfinished.log"
done

failed="$(cat "$WORK"/job-*.log | grep '^\[check\] FAIL' || true)"
# what passed only the second time, once more here: worth a look, not a reason to stop
cat "$WORK"/job-*.log | grep -E '^\[check\] WARN|⚠' || true
if [[ -n "$failed" ]]; then
  printf '\n%s\n' "$failed" >&2
  printf '[check] %d check(s) failed\n' "$(grep -c . <<<"$failed")" >&2
  exit 1
fi
printf '[check] all checks passed\n'
