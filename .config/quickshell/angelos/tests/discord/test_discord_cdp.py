#!/usr/bin/env python3
"""Alternative client bridge: endpoint boundaries, stores, controls and arRPC."""
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[2] / 'scripts'


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


bridge = load('discord-voice-cdp')
rpc = load('discord-voice')
launcher = load('discord-voice-launcher')


class Bridge(unittest.TestCase):
    def test_config_and_invalid_ports(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'XDG_RUNTIME_DIR': tmp, 'XDG_CONFIG_HOME': tmp, 'ANGELOS_DISCORD_CDP_PORT': ''}):
            self.assertIsNone(bridge.port())
            path = Path(tmp) / 'angelos-discord-voice.json'
            for value, expected in [(9234, 9234), (0, None), (65536, None), ('bad', None)]:
                path.write_text(json.dumps({'port': value}))
                self.assertEqual(bridge.port(), expected)
            with patch.dict(os.environ, {'ANGELOS_DISCORD_CDP_PORT': '9222'}):
                self.assertEqual(bridge.port(), 9222)

    def test_rejects_untrusted_targets_before_connecting(self):
        for url, endpoint in [
            ('https://discord.com.evil.test/', 'ws://127.0.0.1:9234/a'),
            ('https://evil.test/discord.com', 'ws://127.0.0.1:9234/a'),
            ('http://discord.com/', 'ws://127.0.0.1:9234/a'),
            ('https://discord.com/', 'ws://evil.test:9234/a'),
            ('https://discord.com/', 'ws://127.0.0.1:9222/a'),
        ]:
            target = {'url': url, 'webSocketDebuggerUrl': endpoint}
            with patch.object(bridge, 'port', return_value=9234), patch.object(bridge.theme, 'targets', return_value=[target]), patch.object(bridge.theme, 'WS') as ws:
                self.assertIsNone(bridge.connect())
                ws.assert_not_called()

    def test_reader_idle_and_eof(self):
        voice = rpc.Voice(lambda line: None, fetch=False)
        from unittest.mock import Mock
        ws = Mock()
        reader = bridge.Reader(ws, {'state': 'idle', 'channel': '', 'users': []})
        with patch.object(bridge.select, 'select', return_value=([io.StringIO('')], [], [])):
            self.assertEqual(reader.run(voice, io.StringIO('')), 'bye')
        self.assertEqual(voice.state, 'idle')
        self.assertEqual(voice.users, {})

    def test_controls_validate_membership_and_clamp_volume(self):
        from unittest.mock import Mock
        ws = Mock()
        reader = bridge.Reader(ws, {})
        voice = rpc.Voice(lambda line: None, fetch=False)
        voice.users = {'123': {}}
        for line in ('volume 999 40', 'volume 123 -1', 'quiet bad 1', 'auth'):
            reader.control(line, voice)
        ws.evaluate.assert_not_called()
        reader.control('volume 123 999', voice)
        self.assertIn('"123", 200', ws.evaluate.call_args.args[0])
        reader.control('quiet 123 1', voice)
        self.assertIn('"123", true', ws.evaluate.call_args.args[0])

    def test_arrpc_does_not_wait_for_voice_authorization(self):
        from unittest.mock import Mock
        voice = rpc.Voice(lambda line: None, fetch=False)
        session = rpc.Session(Mock(), voice)
        with self.assertRaisesRegex(ConnectionError, 'Rich Presence only'):
            session.handle({'cmd': 'DISPATCH', 'evt': 'READY', 'data': {'user': {'id': '1045800378228281345'}}})

    def test_persistent_configuration_without_runtime_directory(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'XDG_CONFIG_HOME': tmp, 'ANGELOS_DISCORD_CDP_PORT': ''}):
            path = Path(tmp) / 'angelos/discord-voice.json'
            path.parent.mkdir()
            path.write_text('{"port": 9235}')
            with patch.dict(os.environ):
                os.environ.pop('XDG_RUNTIME_DIR', None)
                self.assertEqual(bridge.port(), 9235)

    def test_launcher_survives_vendor_update_and_preserves_custom_entries(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'vendor/vesktop.desktop'
            source.parent.mkdir()
            source.write_text('[Desktop Entry]\nName=Vesktop\nExec=flatpak run dev.vencord.Vesktop @@u %U @@\n')
            apps = root / 'user/applications'
            config = root / 'config/discord-voice.json'
            wrapper = root / 'user/angelos/launcher.py'
            with patch.multiple(launcher, APPS=apps, CONFIG=config, SELF=wrapper):
                target = launcher.enable(source, 9234)
                self.assertIn('%U', target.read_text())
                self.assertIn(str(wrapper), target.read_text())
                self.assertEqual(json.loads(config.read_text()), {'port': 9234})
                self.assertEqual(config.stat().st_mode & 0o777, 0o600)
                before = target.read_text()
                source.write_text('[Desktop Entry]\nName=New Vesktop\nExec=vesktop %U\n')
                self.assertEqual(target.read_text(), before)
                with patch.object(launcher.subprocess, 'call', return_value=0) as call:
                    launcher.launch(['flatpak', 'run', 'dev.vencord.Vesktop', '@@u', '@@'])
                    command = call.call_args.args[0]
                    self.assertIn('--remote-debugging-port=9234', command)
                    self.assertIn('--remote-debugging-address=127.0.0.1', command)
                launcher.disable(source.name)
                self.assertFalse(target.exists())
                target.write_text('[Desktop Entry]\nExec=custom-launcher\n')
                with self.assertRaisesRegex(ValueError, 'refusing'):
                    launcher.enable(source)
                launcher.disable(source.name)
                self.assertIn('custom-launcher', target.read_text())

    @unittest.skipUnless(shutil.which('node'), 'Node.js is needed for stand-in Discord stores')
    def test_snapshots_across_client_apis(self):
        snapshot = (SCRIPTS / 'discord-voice-snapshot.js').read_text()
        script = r'''
const vm = require('node:vm'), assert = require('node:assert/strict');
const snapshot = SNAPSHOT;
for (const flavor of ['vencord', 'equicord', 'betterdiscord', 'vanilla']) {
    let cid = 'call';
    const stores = {
        SelectedChannelStore: {getVoiceChannelId: () => cid},
        VoiceStateStore: {getVoiceStatesForChannel: () => ({a: {userId:'1',selfMute:true}, b:{userId:'2',selfDeaf:true}})},
        UserStore: {getCurrentUser: () => ({id:'1'}), getUser: id => ({username:'user'+id, avatar:'hash'})},
        ChannelStore: {getChannel: () => ({name:'General',guild_id:'guild'})},
        MediaEngineStore: {isLocalMute: id => id === '2', getLocalVolume: () => 150},
        GuildMemberStore: {getMember: (_, id) => ({nick:'nick'+id})}
    };
    for (const [name, store] of Object.entries(stores)) store.getName = () => name;
    const speaker = {isSpeaking: id => id === '1'};
    const window = {};
    const api = {Common:stores, findByProps: () => speaker};
    if (flavor === 'vencord') window.Vencord = {Webpack:api};
    if (flavor === 'equicord') window.Equicord = {Webpack:api};
    if (flavor === 'betterdiscord') window.BdApi = {Webpack:{getStore: name => stores[name]}};
    const cache = Object.fromEntries([...Object.values(stores),speaker].map((exports,i)=>[i,{exports}]));
    const chunks = [];
    chunks.push = entry => { entry[2]({c:cache}); return Array.prototype.push.call(chunks,entry); };
    window.webpackChunkdiscord_app = chunks;
    const context = vm.createContext({window});
    const call = vm.runInContext(snapshot, context);
    assert.equal(call.state, 'call'); assert.equal(call.channel, 'General');
    assert.equal(call.users.length, 2); assert.equal(call.users[0].name, 'nick1');
    assert.equal(call.users[0].me,true); assert.equal(call.users[0].speaking,true);
    assert.equal(call.users[0].muted,true); assert.equal(call.users[1].deaf,true);
    assert.equal(call.users[1].quiet,true); assert.equal(call.users[1].volume,150);
    cid = null;
    assert.equal(vm.runInContext(snapshot, context).state,'idle');
    assert.equal(vm.runInContext(snapshot, context).users.length,0);
}
'''.replace('SNAPSHOT', json.dumps(snapshot))
        subprocess.run(['node', '-e', script], check=True, timeout=20)


if __name__ == '__main__':
    unittest.main()
