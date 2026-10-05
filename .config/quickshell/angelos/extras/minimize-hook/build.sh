#!/bin/sh
# angelOS minimize hook: builds the preload library for 64-bit apps and, when gcc can, 32-bit ones
# (Steam's games — without it ld.so complains about the wrong ELF class in every one of them).
# usage: build.sh [prefix]   (default ~/.local/lib/angelos; LD_PRELOAD=<prefix>/$LIB/libangelos-minimize.so)
set -e
src=$(dirname "$0")/angelos-minimize.c
out=${1:-$HOME/.local/lib/angelos}
mkdir -p "$out/lib" "$out/lib32"
cc -O2 -fPIC -shared -Wall -Wextra -o "$out/lib/libangelos-minimize.so" "$src" -ldl -lpthread
if cc -m32 -O2 -fPIC -shared -o "$out/lib32/libangelos-minimize.so" "$src" -ldl -lpthread 2>/dev/null; then
    echo "built $out/lib and $out/lib32"
else
    rm -f "$out/lib32/libangelos-minimize.so"
    echo "built $out/lib (no 32-bit gcc: 32-bit apps will warn)"
fi
