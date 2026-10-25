# shellcheck shell=bash
# angelOS installer — sourced by install.sh in name order (see installer/README.md)

# ── Config files ─────────────────────────────────────────────────────────────

N_INSTALLED=0 N_UNCHANGED=0 N_KEPT=0 N_PARKED=0 N_MERGED=0
MERGED=()     # configs the user had changed that took the author's changes (merge_config)
OVERWRITE_CONFIGS="${OVERWRITE_CONFIGS:-0}"
STATE_DIR="${XDG_STATE_HOME:-$HOME_DIR/.local/state}/angelos"
MANIFEST="$STATE_DIR/installed-files.sha256"
PARKED_DIR="$STATE_DIR/kept-updates"
BASES_DIR="$STATE_DIR/key-profile-bases"   # the repository versions merges start from (key profiles, configs)
declare -A PREV_SUM=() NEW_SUM=()
# filled once per run by install_configs (one grep, two sha256sum runs instead of a few
# processes per file): repo files holding a placeholder, checksums of repo and installed files
declare -A HAS_PH=() SRC_SUM=() DST_SUM=() MADE_DIR=()
NVIM_OURS=0
NIRI_FOREIGN=0

sed_escape() { printf '%s' "$1" | sed -e 's/[\/&|\\]/\\&/g'; }

# Files that hold @PLACEHOLDERS@ are rendered; everything else is copied as is.
PLACEHOLDERS='@(HOME|KB_LAYOUT|KB_OPTIONS|KB_VARIANT|VOXTYPE_LANG)@'

render() {
  local src="$1" dst="$2"
  if grep -IqE "$PLACEHOLDERS" "$src"; then
    sed -e "s|@HOME@|$(sed_escape "$HOME_DIR")|g" \
        -e "s|@KB_LAYOUT@|$(sed_escape "$KB_LAYOUTS")|g" \
        -e "s|@KB_OPTIONS@|$(sed_escape "$KB_OPTIONS")|g" \
        -e "s|@KB_VARIANT@|$(sed_escape "$KB_VARIANT")|g" \
        -e "s|@VOXTYPE_LANG@|$(sed_escape "$VOXTYPE_LANGUAGE")|g" \
        "$src" >"$dst"
  else
    cp -- "$src" "$dst"
  fi
  chmod --reference="$src" "$dst"
}

backup() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    mv -- "$target" "$target.bak.$STAMP"
    say "backup: ${target/#$HOME_DIR/\~}.bak.$STAMP"
  fi
}

# Files that belong to the user (or are rewritten by the system itself): seeded
# on the first install, never overwritten afterwards. mimeapps.list holds the
# default apps (browser, file manager…) that apps and angelOS's settings set.
keep_existing() {
  case "$1" in
    .config/niri/monitor.kdl|.config/user-dirs.dirs|.config/user-dirs.locale|.config/mimeapps.list) return 0 ;;
    # the terminal Settings → Default apps picked; the file manager's places
    .config/xdg-terminals.list|.config/gtk-3.0/bookmarks|.config/gtk-4.0/bookmarks) return 0 ;;
  esac
  return 1
}

# Two layers: the author's configs are the base, the user's changes go on top. A config the user
# never changed simply follows the author on every update. One they changed (by hand, or through
# angelOS's settings) is merged three ways (merge_config: git merge-file): base = the version the
# installer put there last time, ours = the file as it is, theirs = the repository's now. What the
# author changed comes in; where both changed the same lines, the user's lines win — the author's
# are the backup. The key profiles merge by key instead (merge_key_profile). Files angelOS
# generates (the palette's theme files, GTK's, fastfetch's style; Voxtype's own)
# are not merged: the user's stay, the new version is parked. So is anything without a known base
# (an install older than the manifest), and everything on the author's own machine (owner/).
# One's own lines can also go in files the repository never ships, read last:
# ~/.config/fish/user.fish and ~/.config/niri/cfg/user.kdl (its binds and rules win).
generated() {
  case "$1" in
    .config/niri/angelos.kdl|.config/kitty/themes/*|.config/foot/themes/*|.config/alacritty/themes/*) return 0 ;;
    .config/btop/themes/*|.config/gtk-3.0/*|.config/gtk-4.0/*|.config/fastfetch/*) return 0 ;;
    .config/voxtype/*|.config/nvim/lazy-lock.json) return 0 ;;
  esac
  return 1
}
mergeable() { # a text config of the author's (not the shell's code, a font or an icon)
  [[ "$1" == .config/* ]] && ! is_program "$1" && ! generated "$1" || return 1
  case "$1" in *.png|*.svg|*.ttf|*.otf|*.otb|*.cache) return 1 ;; esac
  return 0
}
OWNER_HOME=0
[[ -d "$HOME_DIR/.config/quickshell/angelos/owner" ]] && OWNER_HOME=1

# niri's config.kdl replaced: the includes angelOS's services added to it (cfg/angelos-windows.kdl,
# -laptop, -minimize; CachyOS's cfg/display.kdl) go into the new one too, before user.kdl
carry_includes() { # old-file new-file
  local line missing=()
  while IFS= read -r line; do
    grep -qxF -- "$line" "$2" || missing+=("$line")
  done < <(grep -E '^include "\./cfg/(angelos-[a-z0-9-]+|display)\.kdl"$' "$1" 2>/dev/null)
  ((${#missing[@]})) || return 0
  python3 - "$2" "${missing[@]}" <<'PY' 2>/dev/null || printf '%s\n' "${missing[@]}" >>"$2"
import sys
path, lines = sys.argv[1], sys.argv[2:]
text = open(path).read()
anchor = "\n// yours, read last"
add = "".join(l + "\n" for l in lines)
text = text.replace(anchor, "\n" + add + anchor, 1) if anchor in text else text.rstrip("\n") + "\n" + add
open(path, "w").write(text)
PY
}

sum_of() { sha256sum -- "$1" | cut -d' ' -f1; }

# sums_into MAP FILE… : MAP[file]=sha256 for every FILE that exists, in one sha256sum run
sums_into() {
  local -n into="$1"; shift
  local line
  (($#)) || return 0
  while IFS= read -r -d '' line; do
    # shellcheck disable=SC2034  # a nameref: the caller's map
    into["${line#*  }"]="${line%%  *}"
  done < <(printf '%s\0' "$@" | xargs -0 -r sha256sum -z -- 2>/dev/null)
}

# CUR = the installed file's checksum: from the run's first look, unless it changed since
dst_sum() { CUR="${DST_SUM[$1]:-}"; [[ -n "$CUR" ]] || CUR="$(sum_of "$1")"; }

mkdir_for() { # the folder of file $1, made once per run
  local dir="${1%/*}"
  [[ -n "${MADE_DIR[$dir]:-}" ]] || { mkdir -p -- "$dir"; MADE_DIR["$dir"]=1; }
}

load_manifest() {
  local sum rel
  [[ -f "$MANIFEST" ]] || return 0
  while read -r sum rel; do
    [[ -n "$rel" ]] && PREV_SUM["$rel"]="$sum"
  done <"$MANIFEST"
}

save_manifest() {
  local rel
  mkdir -p -- "$STATE_DIR"
  for rel in "${!NEW_SUM[@]}"; do
    printf '%s  %s\n' "${NEW_SUM[$rel]}" "$rel"
  done | sort -k2 >"$MANIFEST.tmp" && mv -f -- "$MANIFEST.tmp" "$MANIFEST"
}

# Files the installer itself changed after installing them (rewiring): record
# them as they are now, so the next update does not take them for the user's.
remember() {
  local rel
  for rel in "$@"; do
    [[ -f "$HOME_DIR/$rel" ]] && NEW_SUM["$rel"]="$(sum_of "$HOME_DIR/$rel")"
  done
  save_manifest
}

# A niri config angelOS never wrote — the one niri makes on its first start, CachyOS's own
# (cfg/keybinds.kdl with Noctalia's keys)… Kept as "the user's changes", it left angelOS's
# keys, rules and theme unplugged while Settings → Shortcuts listed them. The whole of it is
# replaced instead (each file backed up); outputs from CachyOS's cfg/display.kdl move to
# monitor.kdl. Ours = known to the manifest, or wired like angelOS's config.kdl.
niri_foreign_check() {
  local cfg="$HOME_DIR/.config/niri/config.kdl" old="$HOME_DIR/.config/niri/cfg/display.kdl"
  NIRI_FOREIGN=0
  [[ -f "$cfg" && -z "${PREV_SUM[.config/niri/config.kdl]:-}" ]] || return 0
  grep -Eq '^[[:space:]]*include "(angelos|noctalia)\.kdl"|^[[:space:]]*include "(\./)?cfg/(game-mode|privacy-block)\.kdl"' "$cfg" && return 0
  NIRI_FOREIGN=1
  if [[ -f "$old" && ! -e "$HOME_DIR/.config/niri/monitor.kdl" ]] && grep -Eq '^[[:space:]]*output[[:space:]]' "$old"; then
    cp -- "$old" "$HOME_DIR/.config/niri/monitor.kdl"
  fi
}
niri_foreign() { [[ "$NIRI_FOREIGN" == 1 && "$1" == .config/niri/* ]]; }

# The shell's own code: always brought up to date (the old copy is backed up).
is_program() {
  case "$1" in
    .config/quickshell/angelos/*|.local/bin/*) return 0 ;;
  esac
  return 1
}

# Is the file at $2 still what the installer put there? The manifest says so for
# installs that have one; before it existed, any earlier version of the repo
# file $3 (rendered like now) counts as untouched.
untouched() {
  local rel="$1" dst="$2" srel="$3" cur h raw tmp CUR
  dst_sum "$dst"; cur="$CUR"
  if [[ -n "${PREV_SUM[$rel]:-}" ]]; then
    [[ "$cur" == "${PREV_SUM[$rel]}" ]]
    return
  fi
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 1
  raw="$(mktemp)" tmp="$(mktemp)"; TMP_FILES+=("$raw" "$tmp")
  while read -r h; do
    git -C "$ROOT" show "$h:$srel" >"$raw" 2>/dev/null || continue
    render "$raw" "$tmp"
    [[ "$(sum_of "$tmp")" == "$cur" ]] && return 0
  done < <(git -C "$ROOT" log --format=%H -n 80 -- "$srel" 2>/dev/null)
  return 1
}

install_file() {
  local src="$1" rel="$2" dst="$HOME_DIR/$2" new sum CUR srel="${1#"$ROOT/"}"
  if keep_existing "$rel" && [[ -e "$dst" ]]; then
    N_KEPT=$((N_KEPT + 1)); return 0
  fi
  # $new: the repository's version as it lands here — the repo file itself, or rendered
  # (placeholders filled, the theme's key profile picked) into a temporary file
  if [[ -n "${HAS_PH[$src]:-}" || -z "${SRC_SUM[$src]:-}" || "$rel" == .config/niri/cfg/keybinds.kdl ]]; then
    new="$(mktemp)"; TMP_FILES+=("$new")
    render "$src" "$new"
    [[ "$rel" == .config/niri/cfg/keybinds.kdl ]] && key_profile_into "$new" "$dst"
    sum="$(sum_of "$new")"
  else
    new="$src" sum="${SRC_SUM[$src]}"
  fi
  if [[ -e "$dst" ]] && dst_sum "$dst" && [[ "$CUR" == "$sum" ]]; then
    NEW_SUM["$rel"]="$sum"
    save_base "$rel" "$new"
    N_UNCHANGED=$((N_UNCHANGED + 1)); return 0
  fi
  # changed since the installer wrote it (by hand, or by angelOS's settings:
  # hotkeys, animations, the default browser…): the user's version stays —
  # a theme's key profile gets the repository's new keys merged in around the user's
  # changed since the installer wrote it: merged (the user's lines win), else the user's stays
  # and the new version is parked
  if [[ -e "$dst" && "$OVERWRITE_CONFIGS" != 1 ]] && ! is_program "$rel" && ! niri_foreign "$rel" \
     && ! untouched "$rel" "$dst" "$srel"; then
    if ((OWNER_HOME == 0)); then
      merge_key_profile "$rel" "$dst" "$srel" "$new" "$src" && return 0
      merge_config "$rel" "$dst" "$srel" "$new" "$src" && return 0
    fi
    mkdir -p -- "$(dirname -- "$PARKED_DIR/$rel")"
    cp -- "$new" "$PARKED_DIR/$rel"
    chmod --reference="$src" "$PARKED_DIR/$rel"
    [[ -n "${PREV_SUM[$rel]:-}" ]] && NEW_SUM["$rel"]="${PREV_SUM[$rel]}"
    N_PARKED=$((N_PARKED + 1)); return 0
  fi
  mkdir_for "$dst"
  backup "$dst"
  unset 'DST_SUM[$dst]'
  cp -- "$new" "$dst"
  chmod --reference="$src" "$dst"
  NEW_SUM["$rel"]="$sum"
  if [[ "$rel" == .config/niri/config.kdl && -e "$dst.bak.$STAMP" ]]; then
    carry_includes "$dst.bak.$STAMP" "$dst"
    NEW_SUM["$rel"]="$(sum_of "$dst")"   # as it is now: the next update takes it for untouched
  fi
  save_base "$rel" "$new"
  N_INSTALLED=$((N_INSTALLED + 1))
}

# The themes' niri key profiles (cfg/keybinds-{common,pixel,macos}.kdl) are edited by
# Settings → Shortcuts, so they are the user's — and still have to receive the keys
# angelOS adds or changes. An update merges them three ways (scripts/keyprofile.py merge):
# base = the repository's version the installer put there last time (a copy in
# $BASES_DIR, else found in git history by the manifest's checksum), ours = the file as it
# is, new = the repository's now. Keys the user left as they came follow the repository,
# new keys come in unless the user binds that key or took it out, the user's own stay.
# The manifest keeps the repository version's checksum, not the merged file's: the next
# update sees the user's edits again and merges again. No base, or a file it can't merge
# (multi-line binds): parked like any other config.
is_key_profile() { [[ "$1" =~ ^\.config/niri/cfg/keybinds-(common|pixel|macos)\.kdl$ ]]; }

save_base() { # rel rendered-repo-file
  is_key_profile "$1" || mergeable "$1" || return 0
  mkdir -p -- "$(dirname -- "$BASES_DIR/$1")" && cp -- "$2" "$BASES_DIR/$1" || true
}

base_of() { # rel repo-file dest: the repository's version the installer put at rel last time
  local rel="$1" srel="$2" dest="$3" want="${PREV_SUM[$1]:-}" h raw
  [[ -n "$want" ]] || return 1
  if [[ -f "$BASES_DIR/$rel" && "$(sum_of "$BASES_DIR/$rel")" == "$want" ]]; then
    cp -- "$BASES_DIR/$rel" "$dest"; return 0
  fi
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || return 1
  raw="$(mktemp)"; TMP_FILES+=("$raw")
  # the plain niri variants were *-no-noctalia.kdl until Noctalia left the dotfiles
  local was="${srel/-plain.kdl/-no-noctalia.kdl}"
  while read -r h; do
    git -C "$ROOT" show "$h:$srel" >"$raw" 2>/dev/null || git -C "$ROOT" show "$h:$was" >"$raw" 2>/dev/null || continue
    render "$raw" "$dest"
    [[ "$(sum_of "$dest")" == "$want" ]] && return 0
  done < <(git -C "$ROOT" log --format=%H -n 200 -- "$srel" "$was" 2>/dev/null)
  return 1
}

merge_key_profile() { # rel installed-file repo-file rendered-new src
  local rel="$1" dst="$2" srel="$3" tmp="$4" src="$5" base merged
  is_key_profile "$rel" && command -v python3 >/dev/null 2>&1 || return 1
  base="$(mktemp)" merged="$(mktemp)"; TMP_FILES+=("$base" "$merged")
  base_of "$rel" "$srel" "$base" || return 1
  python3 "$ROOT/.config/quickshell/angelos/scripts/keyprofile.py" merge "$base" "$dst" "$tmp" >"$merged" 2>/dev/null \
    && [[ -s "$merged" ]] || return 1
  NEW_SUM["$rel"]="$(sum_of "$tmp")"
  save_base "$rel" "$tmp"
  if cmp -s -- "$merged" "$dst"; then
    N_UNCHANGED=$((N_UNCHANGED + 1)); return 0
  fi
  backup "$dst"
  cp -- "$merged" "$dst"
  chmod --reference="$src" "$dst"
  N_MERGED=$((N_MERGED + 1))
}

# git merge-file --diff3's output on stdin → resolved (see merge_config)
MERGE_RESOLVE='
import sys
out, part, ours, base, theirs = [], None, [], [], []
for line in sys.stdin.read().splitlines(keepends=True):
    if line.startswith("<<<<<<< ") and part is None:
        part, ours, base, theirs = "ours", [], [], []
    elif line.startswith("||||||| ") and part == "ours":
        part = "base"
    elif line.startswith("=======") and part == "base":
        part = "theirs"
    elif line.startswith(">>>>>>> ") and part == "theirs":
        out += ours
        if not "".join(base).strip():
            out += [l for l in theirs if l not in ours]
        part = None
    elif part == "ours":
        ours.append(line)
    elif part == "base":
        base.append(line)
    elif part == "theirs":
        theirs.append(line)
    else:
        out.append(line)
if part is not None:
    sys.exit(1)
sys.stdout.write("".join(out))
'

merge_config() { # rel installed-file repo-file rendered-new src — see generated()
  local rel="$1" dst="$2" srel="$3" new="$4" src="$5" base merged
  mergeable "$rel" && command -v git >/dev/null 2>&1 || return 1
  grep -Iq . "$dst" 2>/dev/null || [[ ! -s "$dst" ]] || return 1   # text only
  base="$(mktemp)" merged="$(mktemp)"; TMP_FILES+=("$base" "$merged")
  base_of "$rel" "$srel" "$base" || return 1
  # conflicts: both added lines at one place → both stay (the user's first); both changed the
  # same lines → the user's stay
  if command -v python3 >/dev/null 2>&1; then
    { git merge-file -p --diff3 -- "$dst" "$base" "$new" 2>/dev/null; [[ $? -lt 128 ]]; } |
      python3 -c "$MERGE_RESOLVE" >"$merged" && [[ "${PIPESTATUS[0]}" == 0 ]] || return 1
  else
    git merge-file -p --ours -- "$dst" "$base" "$new" >"$merged" 2>/dev/null || return 1
  fi
  # the manifest keeps the repository version's checksum: the next update merges again
  NEW_SUM["$rel"]="$(sum_of "$new")"
  save_base "$rel" "$new"
  if cmp -s -- "$merged" "$dst"; then
    N_UNCHANGED=$((N_UNCHANGED + 1)); return 0
  fi
  backup "$dst"
  unset 'DST_SUM[$dst]'
  cp -- "$merged" "$dst"
  chmod --reference="$src" "$dst"
  MERGED+=("$rel")
  N_MERGED=$((N_MERGED + 1))
}

# A merged niri file that niri refuses (two edits that only made sense apart): the user's own
# version goes back and the author's new one is parked — never a desktop that doesn't start
niri_merge_guard() {
  local rel bad=() cfg="$HOME_DIR/.config/niri/config.kdl"
  ((${#MERGED[@]})) && command -v niri >/dev/null 2>&1 && [[ -f "$cfg" ]] || return 0
  niri validate -c "$cfg" >/dev/null 2>&1 && return 0
  for rel in "${MERGED[@]}"; do
    [[ "$rel" == .config/niri/* && -e "$HOME_DIR/$rel.bak.$STAMP" ]] || continue
    mkdir -p -- "$(dirname -- "$PARKED_DIR/$rel")"
    cp -- "$HOME_DIR/$rel" "$PARKED_DIR/$rel"
    mv -f -- "$HOME_DIR/$rel.bak.$STAMP" "$HOME_DIR/$rel"
    bad+=("$rel"); N_PARKED=$((N_PARKED + 1)); N_MERGED=$((N_MERGED - 1))
  done
  ((${#bad[@]})) && warn "$(_ "niri refused the merged ${bad[*]}: yours kept, the author's new version parked" \
                               "niri не принял слитые ${bad[*]}: оставлены твои, новая версия автора отложена")"
  local keep=() m b
  for m in "${MERGED[@]}"; do
    for b in "${bad[@]}"; do [[ "$m" == "$b" ]] && continue 2; done
    keep+=("$m")
  done
  MERGED=("${keep[@]}")
}

# The theme's niri keys: cfg/keybinds.kdl picks the pixel or the Mac profile (angelOS's
# scripts/keyprofile.py switches it when the theme changes later). The installed copy of the
# selector already says the chosen one: ANGELOS_THEME when asked or given, else the profile
# the installed selector has now — an update never flips someone's Mac keys back.
key_profile_into() { # rendered-file installed-file
  local want=pixel
  if given ANGELOS_THEME; then
    [[ "$DESKTOP_SHELL" == angelos && "$ANGELOS_THEME" == macos && "$MAC_KEYS" == 1 ]] && want=macos
  elif [[ -f "$2" ]] && grep -Eq '^[[:space:]]*include "(\./)?keybinds-macos\.kdl"' "$2"; then
    want=macos
  fi
  [[ "$want" == macos ]] && sed -i 's/keybinds-pixel\.kdl/keybinds-macos.kdl/' "$1"
  return 0
}

# Where does repo file $1 go for the chosen options? Sets DEST, empty to skip it.
destination() {
  local rel="$1"
  DEST=""
  case "$rel" in
    */__pycache__/*|*.pyc|*.bak.*|.config/quickshell/angelos/owner/*) return 0 ;;
    # Niri: the files wired for angelOS and their plain variants (no desktop shell) share one
    # destination.
    .config/niri/config.kdl|.config/niri/cfg/autostart.kdl|.config/niri/cfg/keybinds.kdl)
      [[ "$DESKTOP_SHELL" != none ]] || return 0 ;;
    *-plain.kdl)
      [[ "$DESKTOP_SHELL" == none ]] || return 0
      rel="${rel/-plain/}" ;;
    .config/quickshell/angelos/*)
      [[ "$DESKTOP_SHELL" != none ]] || return 0 ;;
    .config/systemd/user/*)
      [[ "$ENABLE_SERVICES" == 1 ]] || return 0 ;;
    .config/voxtype/*)
      [[ "$INSTALL_VOXTYPE" == 1 || -x "$HOME_DIR/.local/bin/voxtype" ]] || return 0 ;;
    # Neovim with LazyVim: a whole config or nothing — never mixed into someone's own
    .config/nvim/*)
      [[ "$NVIM_OURS" == 1 ]] || return 0 ;;
    # Helper scripts: tech uses the light GTK variants, full the overlay ones.
    .local/bin/*-simple)
      [[ "$MODE" == tech ]] || return 0 ;;
    .local/bin/niri-record-region|.local/bin/niri-screenshot-region|.local/bin/niri-record-overlay)
      [[ "$MODE" == full ]] || return 0 ;;
  esac
  DEST="$rel"
}

install_configs() {
  local src i
  mkdir -p -- "$HOME_DIR/.config" "$HOME_DIR/.local/bin"
  say "$(_ 'Installing configuration…' 'Установка конфигурации…')"
  load_manifest
  rm -rf -- "$PARKED_DIR"
  niri_foreign_check
  # the Neovim config goes in only where there is none yet, or where it is the one we put there
  if [[ ! -e "$HOME_DIR/.config/nvim" || -n "${PREV_SUM[.config/nvim/init.lua]:-}" ]]; then
    NVIM_OURS=1
  else
    NVIM_OURS=0
    say "$(_ 'The LazyVim config is not installed: ~/.config/nvim is your own' \
             'Конфиг LazyVim не ставится: ~/.config/nvim — ваш')"
  fi

  local -a srcs=() rels=() dsts=()
  while IFS= read -r -d '' src; do
    destination "${src#"$ROOT/"}"
    [[ -n "$DEST" ]] || continue
    srcs+=("$src"); rels+=("$DEST"); dsts+=("$HOME_DIR/$DEST")
  done < <(find "$ROOT/.config" "$ROOT/.local/bin" -type f -print0 | sort -z)
  HAS_PH=() SRC_SUM=() DST_SUM=() MADE_DIR=()
  while IFS= read -r -d '' src; do HAS_PH["$src"]=1; done \
    < <(printf '%s\0' "${srcs[@]}" | xargs -0 -r grep -lIZE -- "$PLACEHOLDERS" 2>/dev/null)
  sums_into SRC_SUM "${srcs[@]}"
  sums_into DST_SUM "${dsts[@]}"
  for i in "${!srcs[@]}"; do
    install_file "${srcs[i]}" "${rels[i]}"
  done

  user_layer
  niri_merge_guard

  # The light variants also answer to the regular command names.
  if [[ "$MODE" == tech ]]; then
    install_file "$ROOT/.local/bin/niri-screenshot-region-simple" ".local/bin/niri-screenshot-region"
    install_file "$ROOT/.local/bin/niri-record-region-simple" ".local/bin/niri-record-region"
  fi
  remove_dropped
  save_manifest
}

# Files the repository no longer ships (deleted or renamed upstream) used to stay behind:
# a stale QML file failed qml-check, and `angelos restart` refused to restart (#118, #112).
# Gone from the repository = in the last manifest but not installed now, or (the installs
# whose manifest already forgot them) deleted from the shell's folder in git history. The
# shell's own code goes whatever it holds, as an update overwrites it anyway; a config only
# when the user never changed it. Each one is moved to $REMOVED_DIR/<its path>.
N_REMOVED=0
REMOVED_DIR="$STATE_DIR/removed-files/$STAMP"
still_shipped() { # rel: some repository file still lands there, for some choice of options
  [[ -e "$ROOT/$1" || -e "$ROOT/${1%.kdl}-plain.kdl" || -e "$ROOT/$1-simple" ]]
}
remove_dropped() {
  local rel dst CUR
  ((OWNER_HOME == 0)) || return 0      # the author's machine: the live shell is the source of truth
  declare -A gone=()
  for rel in "${!PREV_SUM[@]}"; do [[ -z "${NEW_SUM[$rel]:-}" ]] && gone["$rel"]=1; done
  if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] && gone["$rel"]=1
    done < <(git -C "$ROOT" log --diff-filter=D --name-only --format= -- .config/quickshell/angelos 2>/dev/null | sort -u)
  fi
  for rel in "${!gone[@]}"; do
    case "$rel" in */__pycache__/*|*.pyc|*.bak.*|.config/quickshell/angelos/owner/*) continue ;; esac
    dst="$HOME_DIR/$rel"
    [[ -n "${NEW_SUM[$rel]:-}" || ! -f "$dst" || -L "$dst" ]] && continue
    still_shipped "$rel" && continue
    if ! is_program "$rel"; then
      dst_sum "$dst"
      [[ -n "${PREV_SUM[$rel]:-}" && "$CUR" == "${PREV_SUM[$rel]}" ]] || continue
    fi
    mkdir -p -- "$(dirname -- "$REMOVED_DIR/$rel")"
    mv -- "$dst" "$REMOVED_DIR/$rel"
    N_REMOVED=$((N_REMOVED + 1))
  done
  ((N_REMOVED == 0)) ||
    say "$(_ "Removed $N_REMOVED file(s) the new version no longer has (kept in ${REMOVED_DIR/#$HOME_DIR/\~}/)" \
             "Убрано $N_REMOVED файл(ов), которых больше нет в новой версии (копии: ${REMOVED_DIR/#$HOME_DIR/\~}/)")"
}

# The user's own layer (see generated()): made once with a word on what it is, never touched again
user_layer() {
  local kdl="$HOME_DIR/.config/niri/cfg/user.kdl" fish="$HOME_DIR/.config/fish/user.fish"
  if [[ -f "$HOME_DIR/.config/niri/config.kdl" && ! -e "$kdl" ]]; then
    mkdir -p -- "${kdl%/*}"
    cat >"$kdl" <<'KDL'
// Yours: niri reads this file last, so a bind or a rule here wins over angelOS's.
// Updates bring the author's changes into the rest of ~/.config/niri; this file is never touched.
// For example:
// binds {
//     Mod+Shift+T { spawn "foot"; }
// }
KDL
  fi
  if [[ -d "$HOME_DIR/.config/fish" && ! -e "$fish" ]]; then
    cat >"$fish" <<'FISH'
# Yours: config.fish reads this file last, so what you set here wins. Updates bring the
# author's changes into config.fish; this file is never touched. For example:
# alias ll 'eza -l'
FISH
  fi
  return 0
}

install_assets() {
  [[ "$MODE" == full ]] || return 0
  say "$(_ 'Installing fonts and icons…' 'Установка шрифтов и иконок…')"
  if [[ -d "$ROOT/.local/share" ]]; then
    mkdir -p -- "$HOME_DIR/.local/share"
    cp -au -- "$ROOT/.local/share/." "$HOME_DIR/.local/share/"
  fi
  # the few default pictures ship with the dotfiles; the packs come from WALLPAPERS_REPO
  if [[ -d "$ROOT/Pictures" ]]; then
    mkdir -p -- "$HOME_DIR/Pictures"
    cp -au -- "$ROOT/Pictures/." "$HOME_DIR/Pictures/"
  fi
  install_wallpaper_packs
  # the folders Nautilus's sidebar names (gtk-3.0/bookmarks): a missing one showed as a warning sign
  local dir
  while IFS= read -r dir; do
    [[ -n "$dir" && "$dir" != */.* ]] && mkdir -p -- "$HOME_DIR/$dir"
  done < <(sed -n "s|^file://$HOME_DIR/\([^ ]*\).*|\1|p" "$HOME_DIR/.config/gtk-3.0/bookmarks" 2>/dev/null)
  command -v fc-cache >/dev/null 2>&1 && { fc-cache -f "$HOME_DIR/.local/share/fonts" >/dev/null 2>&1 || true; }
  command -v xdg-user-dirs-update >/dev/null 2>&1 && { xdg-user-dirs-update || true; }
  return 0
}

# the steps of this file, in the order of the run (see step() in installer/lib/core.sh)
step 20 install_configs "configs" "конфиги"
step 35 install_assets "fonts, icons, wallpapers" "шрифты, значки, обои"
