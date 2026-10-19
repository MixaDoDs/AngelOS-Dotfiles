#!/bin/sh
# angelOS: the screenshot overlay (Circle) in a process of its own. services/CircleHost runs it.
#
#   scripts/circle-proc.sh <shell dir> <root dir>
#
# Why: the shell's main thread is busy about a third of the time even idle (animations, the
# wallpapers, the spectrum), and the pointer's events wait behind it while picking. The overlay
# alone in a second Quickshell has a main thread nobody else shares.
#
# How: <root dir> (in $XDG_RUNTIME_DIR) becomes a tree of links to the shell's files, where
# shell.qml is modules/circle/proc/Root.qml and the services and config the overlay touches are
# the stand-ins of modules/circle/proc/services and config (saving, the island, Quick Share,
# Settings go back to the shell over modules/circle/proc/services/CircleLink). Built anew each
# start, so files an update adds or drops are seen. Settings are read, never written
# (ANGELOS_CONFIG_READONLY: config/Config.qml).
set -eu
DIR="${1:?shell dir}"
ROOT="${2:?root dir}"
STUBS="$DIR/modules/circle/proc"

rm -rf "$ROOT"
mkdir -p "$ROOT/services" "$ROOT/config"
for f in "$DIR"/*; do
  case "${f##*/}" in
    services|config|shell.qml) ;;
    *) ln -s "$f" "$ROOT/" ;;
  esac
done
for d in services config; do
  for f in "$DIR/$d"/*; do
    [ -e "$STUBS/$d/${f##*/}" ] || ln -s "$f" "$ROOT/$d/"
  done
  for f in "$STUBS/$d"/*; do
    ln -s "$f" "$ROOT/$d/"
  done
done
ln -s "$STUBS/Root.qml" "$ROOT/shell.qml"

# the shell's own quickshell (its parent; a dev stand's HOME hides the `qs` wrapper)
QS="$(readlink "/proc/$PPID/exe" 2>/dev/null || true)"
case "${QS##*/}" in quickshell*) ;; *) QS=qs ;; esac

export ANGELOS_CONFIG_READONLY=1
exec "$QS" -p "$ROOT" -n
