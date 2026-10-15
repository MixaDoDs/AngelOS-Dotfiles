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
        self.assertIn('id = "123", value = 200, quiet = false', ws.evaluate.call_args.args[0])
        reader.control('quiet 123 1', voice)
        self.assertIn('id = "123", value = true, quiet = true', ws.evaluate.call_args.args[0])

    def test_snapshot_from_the_port_is_checked(self):
        # loopback is not proof of Discord: nothing it answers may name a file outside the
        # avatar cache or crash the reader
        for bad in (None, [], 'call', {'state': 'call'}, {'state': 'weird', 'users': []}, {'state': 'call', 'users': 'x'}):
            with self.assertRaises(ValueError):
                bridge.clean(bad)
        data = bridge.clean({'state': 'call', 'channel': 'General', 'users': [
            {'id': '12', 'name': 'a', '_user': {'id': '12', 'avatar': '../../../.bashrc'}, 'volume': 999, 'speaking': 1},
            {'id': '../../x', 'name': 'b'}, 'junk',
            {'id': '13', '_user': {'avatar': 'a_' + 'f' * 32}, 'me': True, 'volume': True}]})
        self.assertEqual([u['id'] for u in data['users']], ['12', '13'])
        self.assertIsNone(data['users'][0]['_user']['avatar'])
        self.assertEqual(data['users'][0]['volume'], 200)
        self.assertFalse(data['users'][0]['speaking'])
        self.assertEqual(data['users'][1]['_user']['avatar'], 'a_' + 'f' * 32)
        self.assertEqual(data['users'][1]['volume'], 100)
        self.assertTrue(data['users'][1]['me'])
        self.assertEqual(bridge.clean({'state': 'idle', 'channel': 'x', 'users': [{'id': '1'}]}), {'state': 'idle', 'channel': '', 'users': []})

    def test_arrpc_does_not_wait_for_voice_authorization(self):
        from unittest.mock import Mock
        voice = rpc.Voice(lambda line: None, fetch=False)
        session = rpc.Session(Mock(), voice)
        with self.assertRaisesRegex(ConnectionError, 'Rich Presence only') as caught:
            session.handle({'cmd': 'DISPATCH', 'evt': 'READY', 'data': {'user': {'id': '1045800378228281345'}}})
        # its own state for the widget («rpc-only»), not «Discord is not running»
        self.assertIsInstance(caught.exception, rpc.RichPresenceOnly)

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
                with patch.object(launcher.os, 'execvp') as call:
                    launcher.launch_source(source, ['discord://channel/123'])
                    self.assertEqual(call.call_args.args[1][:2], ['vesktop', 'discord://channel/123'])
                with patch.object(launcher.os, 'execvp') as call:
                    launcher.launch(['flatpak', 'run', 'dev.vencord.Vesktop', '@@u', '@@'])
                    command = call.call_args.args[1]
                    self.assertIn('--remote-debugging-port=9234', command)
                    self.assertIn('--remote-debugging-address=127.0.0.1', command)
                self.assertEqual(call.call_args.args[0], 'flatpak')
                launcher.disable(source.name)
                self.assertFalse(target.exists())
                # the last managed entry takes the port with it: no reader left trying it
                self.assertFalse(config.exists())
                target.write_text('[Desktop Entry]\nExec=custom-launcher\n')
                with self.assertRaisesRegex(ValueError, 'refusing'):
                    launcher.enable(source)
                launcher.disable(source.name)
                self.assertIn('custom-launcher', target.read_text())

    def test_aur_flags_are_idempotent_and_preserve_unrelated_options(self):
        original = '# My Wayland options\n--ozone-platform=wayland\n--enable-features=WebRTCPipeWireCapturer\n'
        updated = launcher.flags_text(original, 9234)
        self.assertEqual(launcher.flags_text(updated, 9234), updated)
        self.assertEqual(launcher.flags_text(updated), original)
        changed = launcher.flags_text(updated, 9235)
        self.assertNotIn('--remote-debugging-port=9234', changed)
        self.assertIn('--remote-debugging-port=9235', changed)
        self.assertIn(original, changed)
        with self.assertRaisesRegex(ValueError, 'refusing'):
            launcher.flags_text('--remote-debugging-port=9999\n', 9234)
        with self.assertRaisesRegex(ValueError, 'malformed'):
            launcher.flags_text(launcher.FLAGS_BEGIN + '\n', 9234)

    def test_aur_cli_and_desktop_keep_flags_after_package_upgrade(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / 'usr/share/applications/vesktop.desktop'
            source.parent.mkdir(parents=True)
            source.write_text('[Desktop Entry]\nName=Vesktop\nExec=vesktop %U\n')
            config = root / 'config/angelos/discord-voice.json'
            flags = root / 'config/vesktop-flags.conf'
            flags.parent.mkdir()
            flags.write_text('--ozone-platform=wayland\n')
            # Stand-in for AUR's shell launcher: exactly its flags-file/argv flow.
            binary = root / 'usr/bin/vesktop'
            binary.parent.mkdir(parents=True)
            wrapper = '#!/bin/sh\nflags=$(grep -v "^#" "$XDG_CONFIG_HOME/vesktop-flags.conf")\nprintf "%s\\n" $flags "$@"\n'
            binary.write_text(wrapper)
            binary.chmod(0o755)
            with patch.multiple(launcher, APPS=root / 'user/applications', CONFIG=config,
                                SELF=root / 'user/launcher.py', FLAGS=flags), patch.object(launcher, 'native_desktop', return_value=source):
                target = launcher.enable_aur(9234)
                self.assertTrue(target.exists())
                before = flags.read_text()
                # yay replaces the package wrapper and desktop entry, not user config.
                binary.write_text(wrapper + '# upgraded package\n')
                source.write_text('[Desktop Entry]\nName=Vesktop upgraded\nExec=vesktop --start-minimized %U\n')
                env = dict(os.environ, XDG_CONFIG_HOME=str(flags.parent))
                result = subprocess.run([str(binary), 'discord://channel/123'], env=env,
                                        capture_output=True, text=True, check=True)
                self.assertIn('--remote-debugging-port=9234', result.stdout.splitlines())
                self.assertIn('--ozone-platform=wayland', result.stdout.splitlines())
                self.assertIn('discord://channel/123', result.stdout.splitlines())
                self.assertEqual(flags.read_text(), before)
                with patch.object(launcher.os, 'execvp') as call:
                    launcher.launch_source(source, ['discord://channel/123'])
                    self.assertEqual(call.call_args.args[1][:3], ['vesktop', '--start-minimized', 'discord://channel/123'])
                launcher.disable_aur()
                self.assertEqual(flags.read_text(), '--ozone-platform=wayland\n')
                self.assertFalse(target.exists())

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


    @unittest.skipUnless(shutil.which('node'), 'Node.js is needed for stand-in Discord stores')
    def test_quiet_and_volume_through_the_clients_actions(self):
        # Discord's audio actions: setLocalVolume and toggleLocalMute, no setLocalMute
        from unittest.mock import Mock
        ws = Mock()
        reader = bridge.Reader(ws, {})
        voice = rpc.Voice(lambda line: None, fetch=False)
        voice.users = {'2': {}}
        exprs = []
        for line in ('quiet 2 1', 'quiet 2 1', 'volume 2 40', 'quiet 2 0'):
            reader.control(line, voice)
            exprs.append(ws.evaluate.call_args.args[0])
        snapshot = (SCRIPTS / 'discord-voice-snapshot.js').read_text()
        script = r'''
const vm = require('node:vm'), assert = require('node:assert/strict');
const muted = new Set(), volume = {}, log = [];
const stores = {
    SelectedChannelStore: {getVoiceChannelId: () => 'call'},
    VoiceStateStore: {getVoiceStatesForChannel: () => ({b: {userId: '2'}})},
    UserStore: {getCurrentUser: () => ({id: '1'}), getUser: id => ({username: 'user' + id})},
    ChannelStore: {getChannel: () => ({name: 'General'})},
    MediaEngineStore: {isLocalMute: id => muted.has(id), getLocalVolume: id => volume[id] ?? 100},
    SpeakingStore: {isSpeaking: () => false},
};
for (const [name, store] of Object.entries(stores)) store.getName = () => name;
const actions = {
    setLocalVolume: (id, v) => { log.push('volume'); volume[id] = v; },
    toggleLocalMute: id => { log.push('toggle'); muted.has(id) ? muted.delete(id) : muted.add(id); },
};
const cache = Object.fromEntries([...Object.values(stores), actions].map((exports, i) => [i, {exports}]));
const chunks = [];
chunks.push = entry => { entry[2]({c: cache}); return Array.prototype.push.call(chunks, entry); };
const window = {webpackChunkdiscord_app: chunks};
const context = vm.createContext({window});
assert.equal(vm.runInContext(SNAPSHOT, context).state, 'call');
const [on, again, loud, off] = EXPRS;
assert.equal(vm.runInContext(on, context), true); assert.ok(muted.has('2'));
vm.runInContext(again, context); assert.ok(muted.has('2'));   // a repeat does not flip it back
vm.runInContext(loud, context); assert.equal(volume['2'], 40);
vm.runInContext(off, context); assert.ok(!muted.has('2'));
assert.deepEqual(log, ['toggle', 'volume', 'toggle']);
const call = vm.runInContext(SNAPSHOT, context);
assert.equal(call.users[0].volume, 40); assert.equal(call.users[0].quiet, false);
'''.replace('SNAPSHOT', json.dumps(snapshot)).replace('EXPRS', json.dumps(exprs))
        subprocess.run(['node', '-e', script], check=True, timeout=20)


if __name__ == '__main__':
    unittest.main()
