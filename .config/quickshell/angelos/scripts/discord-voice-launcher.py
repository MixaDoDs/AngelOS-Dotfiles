#!/usr/bin/env python3
"""Persistent, opt-in Discord DevTools launcher.

  discord-voice-launcher.py enable /path/to/client.desktop [PORT]
  discord-voice-launcher.py disable desktop-file-name.desktop

Keeps the original desktop Exec, including Flatpak forwarding and URL placeholders.
No client profile or vendor package is modified. Changes survive package updates.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'angelos/discord-voice.json'
DATA = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
APPS = DATA / 'applications'
SELF = DATA / 'angelos/discord-voice/launcher.py'
MARK = 'X-AngelOS-DiscordVoice=true'


def quoted(text):
    # Desktop Entry Exec quoting (not shell quoting); literal percent is %%.
    return '"' + str(text).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%') + '"'


def enable(source, port=9234):
    port = int(port)
    if not 1 <= port <= 65535:
        raise ValueError('port must be between 1 and 65535')
    source = Path(source).resolve()
    target = APPS / source.name
    original = source.read_text()
    if source == target.resolve():
        raise ValueError('choose the vendor desktop file, not the user override')
    if target.exists() and MARK not in target.read_text():
        raise ValueError('a user desktop override already exists; refusing to overwrite it')
    output = []
    in_entry = False
    for line in original.splitlines():
        if line.startswith('['):
            in_entry = line == '[Desktop Entry]'
        if line.startswith('Exec='):
            line = 'Exec=' + quoted(sys.executable) + ' ' + quoted(SELF) + ' launch -- ' + line[5:]
        if line.startswith(('TryExec=', 'DBusActivatable=')):
            continue
        output.append(line)
        if in_entry and line == '[Desktop Entry]':
            output.append(MARK)
    if not any(line.startswith('Exec=') for line in output):
        raise ValueError('desktop file has no Exec')
    SELF.parent.mkdir(parents=True, exist_ok=True)
    if Path(__file__).resolve() != SELF.resolve():
        SELF.write_text(Path(__file__).read_text())
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(CONFIG, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as file:
        json.dump({'port': port}, file)
    APPS.mkdir(parents=True, exist_ok=True)
    target.write_text('\n'.join(output) + '\n')
    return target


def launch(command):
    port = int(json.loads(CONFIG.read_text())['port'])
    if not 1 <= port <= 65535 or not command:
        raise ValueError('invalid launch configuration')
    # Electron accepts switches after Flatpak's app id and forwarded URL arguments.
    command += ['--remote-debugging-address=127.0.0.1', '--remote-debugging-port=' + str(port)]
    return subprocess.call(command)


def disable(name):
    if Path(name).name != name:
        raise ValueError('expected a desktop file name')
    target = APPS / name
    if target.exists() and MARK in target.read_text():
        target.unlink()
    # Other enabled client entries may still use the shared configuration.


if __name__ == '__main__':
    try:
        args = sys.argv[1:]
        if args[:1] == ['enable'] and len(args) in (2, 3):
            print(enable(args[1], args[2] if len(args) == 3 else 9234))
        elif args[:2] == ['launch', '--']:
            sys.exit(launch(args[2:]))
        elif args[:1] == ['disable'] and len(args) == 2:
            disable(args[1])
        else:
            sys.exit(__doc__)
    except (OSError, ValueError, KeyError) as exc:
        sys.exit(str(exc))
