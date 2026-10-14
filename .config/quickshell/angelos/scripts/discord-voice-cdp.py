#!/usr/bin/env python3
"""Optional call reader for Electron Discord clients launched with a loopback DevTools port.
Set ANGELOS_DISCORD_CDP_PORT or put {"port": N} in $XDG_RUNTIME_DIR/angelos-discord-voice.json.
Uses the existing theme DevTools transport. No Discord account token is needed.
"""
import importlib.util
import json
import os
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


class Reader:
    def __init__(self, ws, snapshot):
        self.ws, self.snapshot = ws, snapshot

    def close(self):
        self.ws.close()

    def run(self, voice, stdin):
        while True:
            data = self.snapshot
            if not data:
                raise ConnectionError('Discord is loading; reconnecting')
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
        method = 'setLocalMute' if part[0] == 'quiet' else 'setLocalVolume'
        value = part[2] != '0' if part[0] == 'quiet' else max(0, min(200, int(part[2])))
        # Reuse the client's own actions; the next snapshot confirms its result.
        expr = """(() => {
            const api = window.Vencord?.Webpack || window.Equicord?.Webpack;
            const method = %s;
            const actions = api?.findByProps?.('setLocalVolume', 'setLocalMute')
                || window.BdApi?.Webpack?.getByKeys('setLocalVolume', 'setLocalMute')
                || (window.__angelosVoiceExports || []).find(x => typeof x.setLocalVolume === 'function' && typeof x.setLocalMute === 'function');
            if (!actions) return false;
            actions[method](%s, %s); return true;
        })()""" % (json.dumps(method), json.dumps(part[1]), json.dumps(value))
        self.ws.evaluate(expr)
