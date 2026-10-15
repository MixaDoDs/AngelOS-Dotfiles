#!/usr/bin/env python3
"""Optional call reader for Electron Discord clients launched with a loopback DevTools port.
Set ANGELOS_DISCORD_CDP_PORT or put {"port": N} in $XDG_RUNTIME_DIR/angelos-discord-voice.json.
Uses the existing theme DevTools transport. No Discord account token is needed.
"""
import importlib.util
import json
import os
import re
import select
from pathlib import Path
from urllib.parse import urlsplit

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('angelos_discord_theme', HERE / 'discord-theme.py')
theme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(theme)
SNAPSHOT = (HERE / 'discord-voice-snapshot.js').read_text()


def port():
    value = os.environ.get('ANGELOS_DISCORD_CDP_PORT')
    if not value:
        paths = [Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'angelos/discord-voice.json']
        if os.environ.get('XDG_RUNTIME_DIR'):
            paths.insert(0, Path(os.environ['XDG_RUNTIME_DIR']) / 'angelos-discord-voice.json')
        for path in paths:
            try:
                value = json.loads(path.read_text())['port']
                break
            except (KeyError, OSError, ValueError, TypeError):
                continue
    try:
        n = int(value)
        return n if 1 <= n <= 65535 else None
    except (TypeError, ValueError):
        return None


def connect():
    n = port()
    if not n:
        return None
    try:
        for target in theme.targets(n):
            # A substring match would include a hostile https://discord.com.example/ page.
            url = urlsplit(target['url'])
            endpoint = urlsplit(target['webSocketDebuggerUrl'])
            if url.scheme != 'https' or url.hostname not in ('discord.com', 'ptb.discord.com', 'canary.discord.com'):
                continue
            if endpoint.scheme != 'ws' or endpoint.hostname not in ('127.0.0.1', 'localhost', '::1') or endpoint.port != n:
                continue
            ws = theme.WS(target['webSocketDebuggerUrl'], timeout=2)
            try:
                snapshot = ws.evaluate(SNAPSHOT)
                if snapshot:
                    return Reader(ws, snapshot)
            except (OSError, ValueError, RuntimeError):
                pass
            ws.close()
    except (OSError, ValueError, RuntimeError):
        pass
    return None


ID = re.compile(r'\d{1,20}')
AVATAR = re.compile(r'(a_)?[0-9a-f]{32}')


def clean(data):
    """the page's answer → the widget's line, checked: whatever listens on that port is only
    loopback, not necessarily Discord, so nothing it says may name a file outside the avatar
    cache (avatar_path) or crash the reader with an odd shape"""
    if not isinstance(data, dict) or data.get('state') not in ('idle', 'call') or not isinstance(data.get('users'), list):
        raise ValueError('not a Discord call snapshot')
    users = []
    for u in data['users'][:99]:
        if not isinstance(u, dict) or not isinstance(u.get('id'), str) or not ID.fullmatch(u['id']):
            continue
        avatar = (u.get('_user') or {}).get('avatar') if isinstance(u.get('_user'), dict) else None
        volume = u.get('volume')
        users.append({
            'id': u['id'],
            'name': str(u.get('name') or '?')[:100],
            '_user': {'id': u['id'], 'avatar': avatar if isinstance(avatar, str) and AVATAR.fullmatch(avatar) else None},
            'speaking': u.get('speaking') is True, 'muted': u.get('muted') is True, 'deaf': u.get('deaf') is True,
            'me': u.get('me') is True, 'quiet': u.get('quiet') is True,
            'volume': max(0, min(200, round(volume))) if isinstance(volume, (int, float)) and not isinstance(volume, bool) else 100,
        })
    return {'state': data['state'], 'channel': str(data.get('channel') or '')[:100] if data['state'] == 'call' else '',
            'users': users if data['state'] == 'call' else []}


class Reader:
    def __init__(self, ws, snapshot):
        self.ws, self.snapshot = ws, snapshot

    def close(self):
        self.ws.close()

    def run(self, voice, stdin):
        while True:
            if not self.snapshot:
                raise ConnectionError('Discord is loading; reconnecting')
            data = clean(self.snapshot)
            for user in data['users']:
                user['avatar'] = voice._avatar(user.pop('_user', {'id': user['id']}))
            with voice.lock:
                voice.state, voice.channel, voice.error = data['state'], data['channel'], ''
                voice.users = {u['id']: u for u in data['users']}
                voice.order = [u['id'] for u in data['users']]
            voice.emit()
            ready, _, _ = select.select([stdin], [], [], 0.2)
            if ready:
                line = stdin.readline()
                if not line:
                    return 'bye'
                self.control(line, voice)
            self.snapshot = self.ws.evaluate(SNAPSHOT)

    def control(self, line, voice):
        part = line.split()
        if len(part) != 3 or part[0] not in ('quiet', 'volume') or part[1] not in voice.users or not part[1].isdigit() or not part[2].isdigit():
            return
        quiet = part[0] == 'quiet'
        value = part[2] != '0' if quiet else max(0, min(200, int(part[2])))
        # Reuse the client's own actions (found by the snapshot); the next snapshot confirms the
        # result. Discord's audio actions have setLocalVolume and toggleLocalMute (setLocalMute
        # not in every build): toggle only when the state differs, so a repeat cannot flip it back.
        expr = """(() => {
            const id = %s, value = %s, quiet = %s;
            const s = window.__angelosVoiceStores, actions = s?.AudioActions, media = s?.MediaEngineStore;
            if (!actions) return false;
            if (!quiet) { actions.setLocalVolume(id, value); return true; }
            if (typeof actions.setLocalMute === 'function') { actions.setLocalMute(id, value); return true; }
            if (typeof actions.toggleLocalMute !== 'function' || !media) return false;
            if (!!media.isLocalMute(id) !== value) actions.toggleLocalMute(id);
            return true;
        })()""" % (json.dumps(part[1]), json.dumps(value), json.dumps(quiet))
        self.ws.evaluate(expr)
