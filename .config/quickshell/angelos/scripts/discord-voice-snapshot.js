// Read only the current call. No account tokens, chat history or network requests.
(() => {
    const api = window.Vencord?.Webpack || window.Equicord?.Webpack;
    let req;
    function exports() {
        if (!req && window.webpackChunkdiscord_app) {
            const key = 'angelos_voice_' + Date.now();
            window.webpackChunkdiscord_app.push([[key], {}, r => { req = r; }]);
            window.webpackChunkdiscord_app.pop();
        }
        return Object.values(req?.c || {}).flatMap(m => {
            try { return [m.exports, ...Object.values(m.exports || {})]; } catch { return []; }
        }).filter(x => x && (typeof x === 'object' || typeof x === 'function'));
    }
    const all = () => window.__angelosVoiceExports ||= exports();
    const store = name => api?.Common?.[name] || window.BdApi?.Webpack?.getStore(name)
        || all().find(x => { try { return x.getName?.() === name; } catch { return false; } });
    const selected = store('SelectedChannelStore'), voices = store('VoiceStateStore');
    const users = store('UserStore'), channels = store('ChannelStore'), media = store('MediaEngineStore');
    if (!selected || !voices || !users || !channels || !media) {
        // Discord may still be loading modules. Try discovery again on reconnect.
        delete window.__angelosVoiceExports;
        return null;
    }
    const me = users.getCurrentUser()?.id;
    if (!me) return null;
    const cid = selected.getVoiceChannelId();
    if (!cid) return {state: 'idle', channel: '', users: [], error: ''};
    const channel = channels.getChannel(cid);
    const speaking = api?.findByProps?.('isSpeaking') || all().find(x => typeof x.isSpeaking === 'function');
    const members = store('GuildMemberStore');
    const states = voices.getVoiceStatesForChannel(cid) || {};
    return {state: 'call', channel: channel?.name || 'Call', error: '',
        users: Object.values(states).map(v => {
            const id = v.userId || v.user?.id;
            const u = users.getUser(id) || v.user || {};
            return {id, name: members?.getMember(channel?.guild_id, id)?.nick || u.globalName || u.global_name || u.username || '?',
                avatar: '', speaking: !!speaking?.isSpeaking(id),
                muted: !!(v.mute || v.selfMute || v.suppress), deaf: !!(v.deaf || v.selfDeaf),
                me: id === me, quiet: !!media.isLocalMute(id), volume: Math.round(media.getLocalVolume(id) ?? 100),
                _user: {id, avatar: u.avatar}};
        }).filter(u => u.id)};
})()
