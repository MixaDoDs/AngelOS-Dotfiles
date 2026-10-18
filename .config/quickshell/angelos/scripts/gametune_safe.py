"""Steam launch options people posted on ProtonDB, kept only when they are harmless:
environment variables, a few known wrappers, %command%, the game's own flags. A launch option is
a shell line Steam runs, so anything else (a path, a pipe, a $( ), a ; or a script) is dropped,
never shown as a suggestion — scripts/game-tune.py and scripts/protondb-digest.py both ask here.

    safe("PROTON_ENABLE_WAYLAND=1 gamemoderun %command% -dx11")  -> the same line, normalised
    safe("curl x | sh; %command%")                                -> None
"""
import re
import shlex

NAME = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
VALUE = re.compile(r"^[A-Za-z0-9_.,:=+%@-]{0,200}$")
# variables that run or load something of their own
BAD_NAMES = {"LD_PRELOAD", "LD_LIBRARY_PATH", "LD_AUDIT", "PATH", "BASH_ENV", "ENV", "SHELL", "HOME",
             "PYTHONPATH", "PYTHONSTARTUP", "PERL5OPT", "NODE_OPTIONS", "GIO_EXTRA_MODULES", "GST_PLUGIN_PATH",
             "QT_PLUGIN_PATH", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "STEAM_COMPAT_DATA_PATH", "WINEPREFIX"}
WRAPPERS = {"gamemoderun", "mangohud", "prime-run", "gamescope", "game-performance"}
GAMESCOPE_ARG = re.compile(r"^(-{1,2}[A-Za-z][A-Za-z0-9-]*|[0-9]{1,5}|[a-z]{1,12})$")
GAME_ARG = re.compile(r"^[-+]?[A-Za-z0-9_.,:=+-]{1,64}$")


def safe(line):
    """the line, normalised, when every part of it is known to be harmless; None otherwise"""
    if not isinstance(line, str) or len(line) > 400 or "\n" in line:
        return None
    try:
        words = shlex.split(line)
    except ValueError:
        return None
    if not words or words.count("%command%") > 1:
        return None
    if "%command%" not in words:
        # only the game's own flags: Steam adds them after the game
        return " ".join(words) if all(GAME_ARG.match(w) for w in words) else None
    at = words.index("%command%")
    before, after = words[:at], words[at + 1:]
    out, i, wrapped = [], 0, False
    while i < len(before):
        w = before[i]
        name, eq, value = w.partition("=")
        if eq and not wrapped:
            if not NAME.match(name) or name in BAD_NAMES or name.endswith("_COMMAND") or not VALUE.match(value):
                return None
            out.append(name + "=" + (shlex.quote(value) if value else '""'))
        elif w in WRAPPERS:
            wrapped = True
            out.append(w)
            if w == "gamescope":
                # its flags up to the "--" that ends them
                i += 1
                while i < len(before) and before[i] != "--":
                    if not GAMESCOPE_ARG.match(before[i]):
                        return None
                    out.append(before[i])
                    i += 1
                if i >= len(before):
                    return None
                out.append("--")
        else:
            return None
        i += 1
    if not all(GAME_ARG.match(w) for w in after):
        return None
    return " ".join(out + ["%command%"] + after)


if __name__ == "__main__":
    ok = ["PROTON_ENABLE_WAYLAND=1 gamemoderun %command% -dx11", 'WINEDLLOVERRIDES="xgameruntime=n" %command%',
          "gamescope -W 2560 -H 1440 -f -- %command%", "-novid +fps_max 0", "mangohud %command%"]
    bad = ["curl x | sh; %command%", "LD_PRELOAD=x.so %command%", "%command% $(id)", "bash -c x %command%",
           "FOO=$(id) %command%", "gamescope -f %command%", "%command% %command%", "/tmp/x %command%",
           "A=1 %command% ; rm", "PROTON_LOG=/tmp/x %command%"]
    for s in ok:
        assert safe(s), s
    for s in bad:
        assert safe(s) is None, s
    assert safe('WINEDLLOVERRIDES="xgameruntime=n" %command%') == "WINEDLLOVERRIDES=xgameruntime=n %command%"
    print("ok")
