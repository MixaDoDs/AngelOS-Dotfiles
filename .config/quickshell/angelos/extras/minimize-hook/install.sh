#!/bin/sh
# angelOS minimize hook: build it and give it to the session's apps (see angelos-minimize.c).
#   - ~/.local/lib/angelos/{lib,lib32}/libangelos-minimize.so      (build.sh)
#   - angelos.service drop-in: the shell and what it starts         (Environment=, $LIB literal)
#   - ~/.config/niri/cfg/angelos-minimize.kdl + include: what niri starts
#   - systemd's user manager now (services/Minimize.qml does it each login): D-Bus-started apps
# Apps running already get it when they start again. uninstall: install.sh --remove (the dotfiles'
# install.sh, which puts it in for everyone, then leaves it out)
set -e
here=$(dirname "$0")
lib='$LIB'
pre="$HOME/.local/lib/angelos/$lib/libangelos-minimize.so"
dropin="$HOME/.config/systemd/user/angelos.service.d/50-minimize-hook.conf"
kdl="$HOME/.config/niri/cfg/angelos-minimize.kdl"
conf="$HOME/.config/niri/config.kdl"
if [ "${1:-}" = --remove ]; then
    rm -f "$dropin" "$kdl"
    # the dotfiles' install.sh builds it for everyone: this file tells it to stay away
    mkdir -p "$HOME/.config/angelos" && : > "$HOME/.config/angelos/minimize-hook.off"
    [ -f "$conf" ] && sed -i '/angelos-minimize.kdl/d; /extras\/minimize-hook/d' "$conf"
    systemctl --user unset-environment LD_PRELOAD 2>/dev/null || true
    systemctl --user daemon-reload
    echo "removed (the libraries stay in ~/.local/lib/angelos)"
    exit 0
fi
"$here/build.sh"
rm -f "$HOME/.config/angelos/minimize-hook.off"
mkdir -p "$(dirname "$dropin")" "$(dirname "$kdl")"
cat > "$dropin" <<UNIT
# angelOS minimize hook (extras/minimize-hook): the windows' own minimize buttons go to angelOS.
# \$LIB is ld.so's (lib / lib32): systemd doesn't expand \$ in Environment=.
[Service]
Environment="LD_PRELOAD=$pre"
UNIT
cat > "$kdl" <<KDL
// angelOS minimize hook (extras/minimize-hook): apps niri starts get the preload.
environment {
    LD_PRELOAD "$pre"
}
KDL
if [ -f "$conf" ] && ! grep -q 'angelos-minimize.kdl' "$conf"; then
    cp "$conf" "$conf.bak-angelos-minimize"
    printf '\n// angelOS: the windows'"'"' own minimize buttons go to angelOS (extras/minimize-hook)\ninclude "./cfg/angelos-minimize.kdl"\n' >> "$conf"
fi
systemctl --user daemon-reload
systemctl --user set-environment "LD_PRELOAD=$pre"
echo "installed; restart the shell (angelos restart) and the apps"
