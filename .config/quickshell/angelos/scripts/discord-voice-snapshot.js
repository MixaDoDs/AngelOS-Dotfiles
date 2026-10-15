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
    let found;
    const all = () => found ||= exports();
    const safe = f => { try { return f(); } catch { return undefined; } };
    const has = (x, key) => safe(() => typeof x[key] === 'function');
    const store = name => safe(() => api?.Common?.[name]) || safe(() => window.BdApi?.Webpack?.getStore?.(name))
        || all().find(x => safe(() => x.getName?.() === name));
    // Found once per page and kept: scanning every module on each poll (five times a second)
    // would cost the client real CPU. A reload (Ctrl+R) starts a new window, so a new search.
    let s = window.__angelosVoiceStores;
    if (!s) {
        s = {};
        for (const name of ['SelectedChannelStore', 'VoiceStateStore', 'UserStore', 'ChannelStore', 'MediaEngineStore']) {
            s[name] = store(name);
            // Discord may still be loading modules. Try discovery again on reconnect.
            if (!s[name])
                return null;
        }
        s.GuildMemberStore = store('GuildMemberStore');
        s.SpeakingStore = store('SpeakingStore') || safe(() => api?.findByProps?.('isSpeaking'))
            || all().find(x => has(x, 'isSpeaking'));
        // the client's own audio actions, for «quiet» and «volume» from the shell
        s.AudioActions = safe(() => api?.findByProps?.('setLocalVolume'))
            || safe(() => window.BdApi?.Webpack?.getByKeys?.('setLocalVolume'))
            || all().find(x => has(x, 'setLocalVolume'));
        window.__angelosVoiceStores = s;
    }
    const users = s.UserStore, media = s.MediaEngineStore, members = s.GuildMemberStore, speaking = s.SpeakingStore;
    const me = users.getCurrentUser()?.id;
    if (!me) return null;
    const cid = s.SelectedChannelStore.getVoiceChannelId();
    if (!cid) return {state: 'idle', channel: '', users: [], error: ''};
    const channel = s.ChannelStore.getChannel(cid);
    const states = s.VoiceStateStore.getVoiceStatesForChannel(cid) || {};
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
