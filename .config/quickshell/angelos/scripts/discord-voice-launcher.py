#!/usr/bin/env python3
"""Persistent, opt-in Discord DevTools launcher.

  discord-voice-launcher.py enable /path/to/client.desktop [PORT]
  discord-voice-launcher.py disable desktop-file-name.desktop
  discord-voice-launcher.py enable-aur [PORT]
  discord-voice-launcher.py disable-aur

Keeps the original desktop Exec, including Flatpak forwarding and URL placeholders.
No client profile or vendor package is modified. Changes survive package updates.
"""
import configparser
import json
import os
import re
from pathlib import Path
import shlex
import sys

CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'angelos/discord-voice.json'
DATA = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
APPS = DATA / 'applications'
SELF = DATA / 'angelos/discord-voice/launcher.py'
MARK = 'X-AngelOS-DiscordVoice=true'
FLAGS = CONFIG.parent.parent / 'vesktop-flags.conf'
FLAGS_BEGIN = '# BEGIN angelOS Discord voice'
FLAGS_END = '# END angelOS Discord voice'


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
            if in_entry:
                # Resolve the vendor command at every launch: an updater can move
                # an AppImage or replace its desktop Exec after setup.
                forwarded = '%F' if '%F' in line or '%f' in line else '%U'
                line = ('Exec=' + quoted(sys.executable) + ' ' + quoted(SELF)
                        + ' launch-source ' + quoted(source) + ' -- ' + forwarded)
            else:
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
    # Become the client: no Python process left waiting behind it for as long as it runs.
    os.execvp(command[0], command)


def launch_source(source, arguments):
    source = Path(source)
    entry = configparser.ConfigParser(interpolation=None, strict=False)
    entry.read(source)
    desktop = entry['Desktop Entry']
    command = []
    for word in shlex.split(desktop['Exec']):
        if word in ('%U', '%F'):
            command.extend(arguments)
        elif word in ('%u', '%f'):
            command.extend(arguments[:1])
        elif word == '%i':
            if desktop.get('Icon'):
                command.extend(['--icon', desktop['Icon']])
        elif word == '%c':
            command.append(desktop.get('Name', 'Discord'))
        elif word == '%k':
            command.append(str(source))
        elif word not in ('%d', '%D', '%n', '%N', '%v', '%m'):
            command.append(word.replace('%%', '%'))
    return launch(command)


def native_desktop():
    directories = os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')
    for directory in directories:
        source = Path(directory) / 'applications/vesktop.desktop'
        if source.is_file():
            return source
    raise ValueError('native Vesktop desktop file not found; install vesktop-bin or vesktop-git first')


def flags_text(original, port=None):
    if original.count(FLAGS_BEGIN) != original.count(FLAGS_END) or original.count(FLAGS_BEGIN) > 1:
        raise ValueError('malformed angelOS block in vesktop-flags.conf')
    pattern = r'(?m)^' + re.escape(FLAGS_BEGIN) + r'\n.*?^' + re.escape(FLAGS_END) + r'(?:\n|$)'
    clean = re.sub(pattern, '', original, flags=re.DOTALL)
    if port is None:
        return clean
    port = int(port)
    if not 1 <= port <= 65535:
        raise ValueError('port must be between 1 and 65535')
    if any('--remote-debugging-' in line for line in clean.splitlines() if not line.lstrip().startswith('#')):
        raise ValueError('existing custom debugging flags in vesktop-flags.conf; refusing to override them')
    separator = '' if not clean or clean.endswith('\n') else '\n'
    return (clean + separator + FLAGS_BEGIN + '\n--remote-debugging-address=127.0.0.1\n'
            + '--remote-debugging-port=' + str(port) + '\n' + FLAGS_END + '\n')


def enable_aur(port=9234):
    # AUR wrappers read this user file for CLI, autostart and desktop launches.
    # It is outside /usr and /opt, so yay/pacman upgrades leave it intact.
    source = native_desktop()
    original = FLAGS.read_text() if FLAGS.exists() else ''
    updated = flags_text(original, port)
    target = enable(source, port)
    FLAGS.parent.mkdir(parents=True, exist_ok=True)
    FLAGS.write_text(updated)
    return target


def disable_aur():
    if FLAGS.exists():
        original = FLAGS.read_text()
        updated = flags_text(original)
        if updated != original:
            FLAGS.write_text(updated)
    disable('vesktop.desktop')


def disable(name):
    if Path(name).name != name:
        raise ValueError('expected a desktop file name')
    target = APPS / name
    if target.exists() and MARK in target.read_text():
        target.unlink()
        # The port goes with the last managed entry: no reader left trying it. Other enabled
        # client entries still use the shared configuration.
        if not any(MARK in p.read_text(errors='replace') for p in APPS.glob('*.desktop') if p.is_file()):
            try:
                CONFIG.unlink()
            except FileNotFoundError:
                pass


if __name__ == '__main__':
    try:
        args = sys.argv[1:]
        if args[:1] == ['enable-aur'] and len(args) in (1, 2):
            print(enable_aur(args[1] if len(args) == 2 else 9234))
        elif args == ['disable-aur']:
            disable_aur()
        elif args[:1] == ['enable'] and len(args) in (2, 3):
            print(enable(args[1], args[2] if len(args) == 3 else 9234))
        elif args[:1] == ['launch-source'] and len(args) >= 3 and args[2] == '--':
            sys.exit(launch_source(args[1], args[3:]))
        elif args[:2] == ['launch', '--']:
            sys.exit(launch(args[2:]))
        elif args[:1] == ['disable'] and len(args) == 2:
            disable(args[1])
        else:
            sys.exit(__doc__)
    except (OSError, ValueError, KeyError, configparser.Error) as exc:
        sys.exit(str(exc))
