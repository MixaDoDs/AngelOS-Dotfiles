#!/bin/sh
# Is the Quickshell angelOS runs on new enough? Prints one line: <state> <found> <wanted>
#   ok       0.3.2 or newer
#   old      0.3.0 or 0.3.1: angelOS runs, without 0.3.2's crash fixes (the lock on a monitor
#            plugged in later, a reload while a page loads, PAM, PipeWire volume, sockets)
#   too-old  older than 0.3.0: angelOS uses its blur, networking and idle API and won't load
#   missing  no quickshell/qs found
# Exit 0 for ok, 1 otherwise. Used by install.sh and the shell (services/QsVersion).
# $1: the quickshell binary to ask (default: quickshell, else qs, on PATH).
MIN=0.3.0
WANT=0.3.2

bin="${1:-}"
[ -n "$bin" ] || bin="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null)"
if [ -z "$bin" ]; then
    echo "missing - $WANT"
    exit 1
fi
# "Quickshell 0.3.2 (revision …)", "quickshell 0.3.2-git…" → 0.3.2
found="$("$bin" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
if [ -z "$found" ]; then
    echo "missing - $WANT"
    exit 1
fi
case "$found" in *.*.*) ;; *) found="$found.0" ;; esac

# is $1 older than $2 (versions a.b.c)?
older() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]
}
if older "$found" "$MIN"; then
    echo "too-old $found $WANT"
    exit 1
elif older "$found" "$WANT"; then
    echo "old $found $WANT"
    exit 1
fi
echo "ok $found $WANT"
