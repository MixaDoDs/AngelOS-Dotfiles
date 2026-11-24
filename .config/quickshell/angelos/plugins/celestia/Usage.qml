pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import Quickshell
import Quickshell.Io

// Plan limits (the same numbers as Claude Code's /usage): 5-hour window, week, per-model weeks.
// Reads the OAuth token Claude Code keeps in ~/.claude/.credentials.json — picked up automatically.
Singleton {
    id: root

    property var five: null        // {used, left, resetsAt}
    property var week: null
    property var weekOpus: null
    property var weekSonnet: null
    property var extra: null       // extra usage (pay-as-you-go), if enabled
    property string status: "idle" // idle | loading | ok | limited | expired | auth | offline | nologin
    property string plan: ""
    property date updated
    property int intervalSec: 300
    property real notBefore: 0      // backoff after 429 (ms since epoch)
    // stale data stays visible while Anthropic rate-limits us
    readonly property bool ok: (status === "ok" || status === "limited" || status === "loading" || status === "offline") && !!five
    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/angelos/claude-usage.json"
    readonly property real fiveLeft: five ? five.left : -1
    readonly property real weekLeft: week ? week.left : -1

    property string _token: ""
    property real _expires: 0

    function window(w) {
        if (!w || w.utilization === null || w.utilization === undefined)
            return null;
        const used = Math.max(0, Math.min(100, w.utilization));
        return {
            "used": used,
            "left": Math.round(100 - used),
            "resetsAt": w.resets_at ? new Date(w.resets_at) : null
        };
    }
    function untilText(d) {
        if (!d)
            return "";
        const m = Math.max(0, Math.round((d.getTime() - Date.now()) / 60000));
        if (m < 60)
            return m + I18n.t(" мин", " min");
        const h = Math.floor(m / 60);
        if (h < 48)
            return h + I18n.t(" ч ", " h ") + (m % 60) + I18n.t(" мин", " min");
        return Math.floor(h / 24) + I18n.t(" д ", " d ") + (h % 24) + I18n.t(" ч", " h");
    }
    function colorFor(left, theme) {
        return left < 0 ? theme.textDim : left <= 15 ? theme.danger : left <= 40 ? theme.accent3 : theme.ok;
    }

    function apply(d, when) {
        five = window(d.five_hour);
        week = window(d.seven_day);
        weekOpus = window(d.seven_day_opus);
        weekSonnet = window(d.seven_day_sonnet);
        extra = d.extra_usage && d.extra_usage.is_enabled ? d.extra_usage : null;
        updated = when || new Date();
    }
    // force: user asked (button / popup) — still honours the 429 backoff and a 60 s floor
    function refresh(force) {
        if (Quickshell.env("ANGELOS_DEV") === "1" && five)
            return;   // dev instances share the account's rate limit; don't burn it
        const now = Date.now();
        if (now < notBefore)
            return;
        if (five && updated && now - updated.getTime() < (force ? 60000 : (intervalSec - 10) * 1000))
            return;
        if (!_token) {
            status = "nologin";
            return;
        }
        if (_expires && _expires < Date.now()) {
            status = "expired";   // Claude Code refreshes it on its next run; we never touch the refresh token
            return;
        }
        if (status !== "ok")
            status = "loading";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try {
                    const d = JSON.parse(xhr.responseText);
                    root.apply(d, new Date());
                    root.status = "ok";
                    cache.setText(JSON.stringify({
                        "at": Date.now(),
                        "data": d
                    }));
                } catch (e) {
                    root.status = "offline";
                }
            } else if (xhr.status === 429) {
                const ra = parseInt(xhr.getResponseHeader("retry-after") || "0");
                root.notBefore = Date.now() + Math.max(600, ra || 0) * 1000;
                root.status = "limited";
            } else {
                root.status = xhr.status === 401 || xhr.status === 403 ? "auth" : "offline";
            }
        };
        xhr.open("GET", "https://api.anthropic.com/api/oauth/usage");
        xhr.setRequestHeader("Authorization", "Bearer " + _token);
        xhr.setRequestHeader("anthropic-beta", "oauth-2025-04-20");
        xhr.setRequestHeader("User-Agent", "angelOS-claude-companion");
        xhr.send();
    }

    Timer {
        interval: root.intervalSec * 1000
        running: true
        repeat: true
        onTriggered: root.refresh(false)
    }
    // last good answer survives restarts, so a reload doesn't hit the API again
    FileView {
        id: cache
        path: root.cacheFile
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (c && c.data && !root.five) {
                    root.apply(c.data, new Date(c.at));
                    root.status = "ok";
                }
            } catch (e) {}
        }
    }

    FileView {
        id: creds
        path: (Quickshell.env("CLAUDE_CONFIG_DIR") || (Quickshell.env("HOME") + "/.claude")) + "/.credentials.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text()).claudeAiOauth || {};
                const changed = o.accessToken !== root._token;
                root._token = o.accessToken || "";
                root._expires = o.expiresAt || 0;
                root.plan = o.subscriptionType || "";
                if (changed)
                    Qt.callLater(() => root.refresh(false));
            } catch (e) {
                root._token = "";
                root.status = "nologin";
            }
        }
        onLoadFailed: root.status = "nologin"
    }
}
