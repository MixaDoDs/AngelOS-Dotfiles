#!/usr/bin/env bash
# Settings → Updates the way a user meets it: angelOS installed from an older commit of
# this repository, and that install's own (old) update script bringing it to this
# working tree — the old script, the new installer. A throw-away $HOME, a local origin
# holding the old commit with this tree on top, stand-ins for qs, systemctl and the like
# (the real `niri validate` when niri is installed). Nothing of your session is touched.
#
#   scripts/test-update-old.sh            the pinned versions below
#   scripts/test-update-old.sh SHA[:alarm] …   other commits (":alarm" = installed on Arch Linux ARM)
#   REQUIRE_OLD=1 …                       an old commit that can't be had is a failure, not a skip
#   KEEP_TEST_DIR=1 …                     keep the scratch folder for a look afterwards
#
# The old commits come from this clone's history, else from GitHub (a shallow fetch: CI
# checks out one commit). After the old script's update, the new one must update again.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
OFFICIAL="https://github.com/MixaDoDs/AngelOS-Dotfiles"
# commit | the install it stands for
PINNED=(
  "ab3a21cd42ed6641dc9ed64538d911579884d1b1|2026-09-30, the first Settings → Updates, the repository's old name"
  "504f77f6d2f9ca1ec21cc62ea486e342101cdaf5|2026-10-01, the update with a snapshot and restore"
  "ee6d51cc615caa6f102b4729babb6aff4d4500b9:alarm|2026-10-02 on Arch Linux ARM with DOTFILES_FORCE_DISTRO=1 (issue #36)"
)
W="$(mktemp -d)"
if [[ -n "${KEEP_TEST_DIR:-}" ]]; then trap 'echo "[update-old] scratch kept: $W"' EXIT; else trap 'rm -rf -- "$W"' EXIT; fi
failures=0 skipped=0
pass() { printf '[update-old] OK   %s\n' "$*"; }
fail() { printf '[update-old] FAIL %s\n' "$*" >&2; failures=$((failures + 1)); }
skip() { printf '[update-old] SKIP %s\n' "$*"; skipped=$((skipped + 1)); }
check() { local what="$1"; shift; if "$@"; then pass "$what"; else fail "$what"; fi; }
show() { sed 's/^/    | /' "$1" | tail -n "${2:-25}" >&2; }
G=(git -c user.name=test -c user.email=test@invalid -c init.defaultBranch=main -c commit.gpgsign=false -c advice.detachedHead=false)

# ── stand-ins ────────────────────────────────────────────────────────────────
STUBS="$W/stubs"
mkdir -p "$STUBS"
if REAL_NIRI="$(command -v niri)"; then
  printf '#!/bin/sh\n[ "$1" = validate ] && exec %s "$@"\necho "niri $*" >>"$HOME/stub-calls"\nexit 0\n' "$REAL_NIRI" >"$STUBS/niri"
else
  printf '#!/bin/sh\necho "niri $*" >>"$HOME/stub-calls"\nexit 0\n' >"$STUBS/niri"
fi
for c in qs quickshell notify-send pkill systemctl setsid fc-cache xdg-user-dirs-update gsettings dconf; do
  printf '#!/bin/sh\necho "%s $*" >>"$HOME/stub-calls"\nexit 0\n' "$c" >"$STUBS/$c"
done
chmod +x "$STUBS"/*
printf 'NAME="Arch Linux ARM"\nID=archarm\nID_LIKE=arch\nPRETTY_NAME="Arch Linux ARM"\n' >"$W/os-alarm"

# this tree, as `git add -A` would commit it
TREE="$W/tree"
mkdir -p "$TREE"
(cd "$ROOT" && git ls-files -co --exclude-standard -z | while IFS= read -r -d '' f; do
   [[ -e "$f" || -L "$f" ]] && printf '%s\0' "$f"; done | tar --null -T - -cf -) | tar -C "$TREE" -xf -

# the shell's files, as installed from a tree: same bytes (placeholders aside)
same_shell() { # TREE_DIR HOME
  python3 - "$1/.config/quickshell/angelos" "$2/.config/quickshell/angelos" <<'PY'
import os, sys
src, dst = sys.argv[1], sys.argv[2]
bad = []
for base, dirs, files in os.walk(src):
    dirs[:] = [d for d in dirs if d not in ("__pycache__", "owner")]
    for f in files:
        if f.endswith(".pyc"):
            continue
        a = os.path.join(base, f)
        b = os.path.join(dst, os.path.relpath(a, src))
        if not os.path.isfile(b):
            bad.append("missing " + os.path.relpath(a, src))
            continue
        x, y = open(a, "rb").read(), open(b, "rb").read()
        if x != y and b"@HOME@" not in x:
            bad.append("differs " + os.path.relpath(a, src))
if bad:
    print("\n".join(bad[:10]), file=sys.stderr)
    sys.exit(1)
PY
}

one() { # SHA[:alarm] LABEL
  local spec="$1" label="$2" sha="${1%%:*}" alarm=0 short D H SRC REPO NEW rc
  [[ "$spec" == *:alarm ]] && alarm=1
  short="${sha:0:7}"
  D="$W/$short"; H="$D/home"; SRC="$D/src"
  mkdir -p "$H" "$SRC"
  "${G[@]}" -C "$SRC" init -q
  if git -C "$ROOT" cat-file -e "$sha^{commit}" 2>/dev/null; then
    "${G[@]}" -C "$SRC" fetch -q "$ROOT" "$sha"
  elif ! "${G[@]}" -C "$SRC" fetch -q --depth 1 "$OFFICIAL" "$sha" 2>"$D/fetch.log"; then
    if [[ "${REQUIRE_OLD:-0}" == 1 ]]; then fail "$short: the old commit can't be had (no history, no network)"; show "$D/fetch.log"
    else skip "$short ($label): not in this clone's history and GitHub can't be reached"; fi
    return 0
  fi
  "${G[@]}" -C "$SRC" checkout -q -b main "$sha"
  # this tree on top of the old commit: what `origin/main` brings
  "${G[@]}" -C "$SRC" rm -rq --cached . && find "$SRC" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -a "$TREE/." "$SRC/"
  "${G[@]}" -C "$SRC" add -A && "${G[@]}" -C "$SRC" commit -qm "this tree"
  NEW="$(git -C "$SRC" rev-parse HEAD)"
  "${G[@]}" clone -q --bare "$SRC" "$D/origin.git"
  # the user's clone, still on the old commit; before 2026-09-30 evening it had the old name
  REPO="$H/AngelOS-Dotfiles"
  git -C "$SRC" cat-file -e "$sha:.config/quickshell/angelos/scripts/update-txn.py" 2>/dev/null || REPO="$H/PixelStreetArt_Dotfiles_Niri"
  "${G[@]}" clone -q "$D/origin.git" "$REPO"
  "${G[@]}" -C "$REPO" reset -q --hard "$sha"

  local ENVS=(env -i HOME="$H" PATH="$STUBS:$PATH" LANG=C USER=test GSETTINGS_BACKEND=memory)
  # Arch Linux ARM: installed past the distribution check, then updated without the switch
  local DISTRO=() FORCE=()
  ((alarm)) && DISTRO=(DOTFILES_OS_RELEASE="$W/os-alarm") && FORCE=(DOTFILES_FORCE_DISTRO=1)
  if ! "${ENVS[@]}" "${DISTRO[@]}" "${FORCE[@]}" SKIP_PACKAGES=1 INSTALL_VOXTYPE=0 \
       DOWNLOAD_VOXTYPE_MODEL=0 ENABLE_SERVICES=0 INSTALL_WALLPAPERS=0 INSTALL_SDDM=0 DESKTOP_SHELL=angelos \
       bash "$REPO/install.sh" </dev/null >"$D/install.log" 2>&1; then
    fail "$short: the old install itself"; show "$D/install.log"; return 0
  fi
  printf '{"setup":{"complete":true},"mine":1}\n' >"$H/.config/angelos/settings.json"
  echo '// my own binds' >>"$H/.config/niri/cfg/keybinds.kdl"      # the user's change, kept by every update

  # the old install's own updater: what its Settings → Updates button runs
  local OLD_SCRIPT="$H/.config/quickshell/angelos/scripts/dotfiles-update.sh"
  "${ENVS[@]}" "${DISTRO[@]}" bash "$OLD_SCRIPT" --check "$REPO" >"$D/check.out" 2>&1 || true
  check "$short: its check sees the new commit" grep -q '^BEHIND 1$' "$D/check.out"
  local protocol=0                            # UPDATED/FAILED lines came on 2026-10-01
  grep -q 'UPDATED' "$OLD_SCRIPT" && protocol=1
  rc=0
  "${ENVS[@]}" "${DISTRO[@]}" bash "$OLD_SCRIPT" "$REPO" >"$D/update.out" 2>&1 || rc=$?
  if ((rc == 0)); then pass "$short ($label): the old update script exits 0"; else fail "$short ($label): the old update script, exit $rc"; show "$D/update.out"; fi
  if ((protocol)); then
    check "$short: UPDATED $short… is the last line" bash -c "tail -n 1 '$D/update.out' | grep -q '^UPDATED $sha $NEW 1\$'"
  fi
  check "$short: no FAILED line, no installer error" bash -c "! grep -qE '^FAILED |\\[dotfiles\\] ERROR' '$D/update.out'"
  check "$short: the clone is on the new commit" test "$(git -C "$REPO" rev-parse HEAD)" = "$NEW"
  check "$short: the installed shell is this tree's" same_shell "$TREE" "$H"
  check "$short: the user's binds kept" grep -q 'my own binds' "$H/.config/niri/cfg/keybinds.kdl"
  check "$short: settings.json untouched" grep -qx '{"setup":{"complete":true},"mine":1}' "$H/.config/angelos/settings.json"

  # and the next update goes through the new script
  (cd "$SRC" && echo '// v3' >>.config/quickshell/angelos/services/Updates.qml && "${G[@]}" commit -qam v3 && "${G[@]}" push -q "$D/origin.git" HEAD:main)
  rc=0
  "${ENVS[@]}" "${DISTRO[@]}" bash "$OLD_SCRIPT" "$REPO" >"$D/update2.out" 2>&1 || rc=$?
  check "$short: the new script updates once more (UPDATED, the change installed)" \
    bash -c "[[ $rc == 0 ]] && tail -n 1 '$D/update2.out' | grep -q '^UPDATED $NEW ' && grep -q '// v3' '$H/.config/quickshell/angelos/services/Updates.qml'"
  ((rc == 0)) || show "$D/update2.out"
}

if (($#)); then
  for s in "$@"; do one "$s" "$s"; done
else
  for p in "${PINNED[@]}"; do one "${p%%|*}" "${p#*|}"; done
fi

if ((failures)); then
  printf '[update-old] %d check(s) failed\n' "$failures" >&2
  exit 1
fi
printf '[update-old] all checks passed%s\n' "$( ((skipped)) && echo " ($skipped version(s) skipped)")"
