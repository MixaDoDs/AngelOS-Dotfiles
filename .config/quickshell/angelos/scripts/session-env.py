#!/usr/bin/env python3
"""Save the session environment for the angelOS systemd service.

  session-env.py self|<pid> <file>

The shell runs as a systemd user service (bin/angelos start), and systemd only
hands it the manager's environment. niri's `environment {}` block (GDK_BACKEND,
NVIDIA variables, Electron hints…) reaches processes niri spawns, so
`angelos start` — spawned by niri at login — writes its own environment here
and the unit reads it back (EnvironmentFile=). `<pid>` takes the environment of
a running shell instead (moving an older instance under the service).

Only what an app started from the shell should inherit is kept: the variables
bin/angelos and the local quickshell wrapper add for the shell itself are put
back, systemd's per-service variables, terminal ones and coding agents' markers
are dropped.

At login (`self`) the look-and-backend variables of niri's `environment {}` also go
to the D-Bus / systemd activation environment (ACTIVATION): apps started by D-Bus
— Nautilus for the file chooser portal or «show in folder», the portals themselves —
otherwise start without them (GSK_RENDERER: Nautilus fell back to Vulkan and spammed
VK_ERROR_OUT_OF_DATE_KHR on NVIDIA; QT_QPA_PLATFORMTHEME: Qt apps without qt6ct).
"""
import os
import re
import sys

DROP = {
    "INVOCATION_ID", "JOURNAL_STREAM", "MANAGERPID", "MANAGERPIDFDID", "SYSTEMD_EXEC_PID",
    "MEMORY_PRESSURE_WATCH", "MEMORY_PRESSURE_WRITE", "NOTIFY_SOCKET", "WATCHDOG_PID",
    "WATCHDOG_USEC", "LISTEN_PID", "LISTEN_FDS", "LISTEN_FDNAMES", "DESKTOP_STARTUP_ID",
    "XDG_ACTIVATION_TOKEN", "SHLVL", "PWD", "OLDPWD", "_", "TERM", "COLORTERM",
    "WINDOWID", "VTE_VERSION", "CLAUDECODE", "ANGELOS_SERVICE", "ANGELOS_DEV",
    "ANGELOS_SCREENS", "ANGELOS_DEMO", "QS_CONFIG_NAME", "QS_CONFIG_PATH",
}
DROP_PREFIX = ("CLAUDE_", "CODEX_", "KITTY_", "WEZTERM_", "ALACRITTY_", "TERM_PROGRAM",
               "__QUICKSHELL_", "ANGELOS_PRE_", "BASH_FUNC_")
NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
ACTIVATION = ("GSK_RENDERER", "GDK_BACKEND", "QT_QPA_PLATFORM", "QT_QPA_PLATFORMTHEME",
              "ELECTRON_OZONE_PLATFORM_HINT", "MOZ_ENABLE_WAYLAND", "XCURSOR_THEME", "XCURSOR_SIZE")


def read(src):
    if src == "self":
        return dict(os.environ)
    env = {}
    with open(f"/proc/{int(src)}/environ", "rb") as f:
        for kv in f.read().split(b"\0"):
            if b"=" in kv:
                k, v = kv.split(b"=", 1)
                env[k.decode(errors="replace")] = v.decode(errors="replace")
    return env


def clean(env):
    # bin/angelos remembers the originals of what it changes for the shell
    for key in ("QT_PLUGIN_PATH", "QSG_RHI_BACKEND", "QT_QPA_PLATFORMTHEME", "QT_WAYLAND_DISABLE_WINDOWDECORATION"):
        pre = "ANGELOS_PRE_" + key
        if pre in env:
            if env[pre]:
                env[key] = env[pre]
            else:
                env.pop(key, None)
    # ~/.local/bin/qs points the loader at the local quickshell copy
    for key in ("LD_LIBRARY_PATH", "QML_IMPORT_PATH"):
        parts = [p for p in env.get(key, "").split(":") if p and "/.local/opt/quickshell/" not in p]
        if parts:
            env[key] = ":".join(parts)
        else:
            env.pop(key, None)
    out = {}
    for k, v in env.items():
        if k in DROP or k.startswith(DROP_PREFIX) or not NAME.match(k) or "\n" in v:
            continue
        out[k] = v
    return out


def quote(v):
    # systemd EnvironmentFile: double quotes, backslash before \ " ` $
    return '"' + re.sub(r'([\\"`$])', r"\\\1", v) + '"'


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    env = clean(read(sys.argv[1]))
    target = sys.argv[2]
    os.makedirs(os.path.dirname(target), exist_ok=True)
    tmp = target + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write("# written by angelOS (scripts/session-env.py); the shell service reads it\n")
        for k in sorted(env):
            f.write(f"{k}={quote(env[k])}\n")
    os.replace(tmp, target)
    if sys.argv[1] == "self":
        export(env)


def export(env):
    """niri's look-and-backend variables for apps D-Bus starts (see the top)"""
    pairs = [f"{k}={env[k]}" for k in ACTIVATION if env.get(k)]
    if not pairs:
        return
    import subprocess
    try:
        subprocess.run(["dbus-update-activation-environment", "--systemd", *pairs],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        pass


if __name__ == "__main__":
    main()
