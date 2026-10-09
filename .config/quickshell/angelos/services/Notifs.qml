pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// Notification daemon. `popups` drives on-screen cards, `history` feeds the calendar panel.
Singleton {
    id: root

    property var popups: []      // Notification objects currently on screen
    // every incoming notification ({appName, summary, urgency, quiet}); the Y2K
    // sounds and the angel listen here
    signal arrived(var info)
    property var history: []     // plain objects, newest first
    readonly property int unread: history.filter(h => !h.read).length
    readonly property string historyFile: Config.stateDir + "/notifications.json"

    function isScreenshot(info) {
        const shot = /screenshot|скриншот/i.test(info.appName || "") || (info.appName === "niri" && /screenshot|скриншот/i.test(info.summary || ""));
        return shot && !/ошибк|error|fail/i.test(info.summary || "");
    }
    function same(a, b) {
        return a === b || (!!a && !!b && a.id !== undefined && a.id === b.id);
    }
    function dismissPopup(n) {
        popups = popups.filter(p => !same(p, n));
        if (same(replyTo, n))
            replyTo = null;
    }
    // the notification whose card has its reply field open (one at a time)
    property var replyTo: null
    // a reply typed into the card goes back to the app (Telegram's inline reply)
    function reply(n, text) {
        text = String(text || "").trim();
        if (!text || !n || !n.hasInlineReply)
            return;
        n.sendInlineReply(text);
        close(n);
    }
    // The app's own window for a notification, from niri's app_id against the sender's name and
    // desktop entry (freshGram → io.github.snowyfluffy.freshgram, com.discordapp.Discord →
    // discord). Discord sends no name at all; its sender is in the summary and its window title
    // names the open chat, which is the last clue.
    function appWindow(n) {
        if (!n)
            return null;
        const names = [];
        for (const s of [n.appName, n.desktopEntry, (n.hints || {})["desktop-entry"]]) {
            const low = String(s || "").toLowerCase().replace(/\.desktop$/, "");
            if (!low)
                continue;
            names.push(low, low.split(".").pop());
        }
        const wins = Niri.windows.filter(w => w.app_id && w.app_id !== "org.quickshell");
        const own = wins.find(w => {
            const id = w.app_id.toLowerCase();
            return names.some(s => id === s || id.split(".").pop() === s);
        });
        if (own)
            return own;
        const who = String(n.summary || "").trim();
        return names.length === 0 && who.length >= 3 ? wins.find(w => String(w.title || "").includes(who)) || null : null;
    }
    // the field's hint: the app's own (KDE's "x-kde-reply-placeholder-text", Telegram sends it);
    // the reply action's label ("Reply") says nothing a field doesn't
    function replyHint(n) {
        return n ? String((n.hints || {})["x-kde-reply-placeholder-text"] || "") : "";
    }
    function canOpen(n) {
        return !!n && (n.actions.some(a => a.identifier === "default") || !!appWindow(n));
    }
    // "Open": the app's default action (Telegram opens the chat) and its window in front — niri
    // gives focus to a window only on a token the app gets from us, so we bring it ourselves
    function open(n) {
        if (!n)
            return;
        const w = appWindow(n);
        const def = n.actions.find(a => a.identifier === "default");
        if (def)
            def.invoke();
        if (w)
            Niri.focusWindow(w.id);
        dismissPopup(n);
    }
    function close(n) {
        dismissPopup(n);
        if (n && n.tracked)
            n.dismiss();
    }
    function clearHistory() {
        history = [];
        save();
    }
    function markRead() {
        history = history.map(h => Object.assign({}, h, {
                "read": true
            }));
        save();
    }
    function removeHistory(id) {
        history = history.filter(h => h.hid !== id);
        save();
    }
    function save() {
        saveTimer.restart();
    }

    // Notification bodies may carry markup. Keep a small whitelist: no images or
    // other remote fetches, links only to http(s)/mailto.
    function safeMarkup(text) {
        return String(text || "").replace(/<\s*(script|style|iframe|object)\b[\s\S]*?<\/\s*\1\s*>/gi, "").replace(/<(\/?)([a-z][a-z0-9]*)(\s[^>]*|\/)?>/gi, (m, close, name, attrs) => {
            name = name.toLowerCase();
            if (["b", "i", "u", "br", "em", "strong", "p"].includes(name))
                return "<" + close + name + ">";
            if (name === "a") {
                if (close)
                    return "</a>";
                const href = ((attrs || "").match(/href\s*=\s*["']([^"']*)["']/i) || [])[1] || "";
                return /^(https?:|mailto:)/i.test(href) ? "<a href=\"" + href.replace(/"/g, "&quot;") + "\">" : "<a>";
            }
            return "";
        });
    }
    function openLink(url) {
        if (/^(https?:|mailto:)/i.test(url))
            Qt.openUrlExternally(url);
    }

    function iconFor(n) {
        if (n.image)
            return n.image;
        if (n.appIcon)
            return n.appIcon.startsWith("/") || n.appIcon.includes("://") ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
        const entry = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null;
        return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true
        onNotification: n => {
            n.tracked = true;
            const entry = {
                "hid": Date.now() + "-" + n.id,
                "appName": n.appName || "",
                "summary": n.summary || "",
                "body": n.body || "",
                "icon": root.iconFor(n),
                "time": Date.now(),
                "urgency": n.urgency,
                "read": false
            };
            if (!n.transient) {
                root.history = [entry].concat(root.history).slice(0, 80);
                root.save();
            }
            const dnd = Config.notifications.dnd && n.urgency !== NotificationUrgency.Critical;
            if (!dnd)
                root.popups = root.popups.concat([n]).slice(-Config.notifications.maxPopups);
            n.closed.connect(() => root.dismissPopup(n));
            root.arrived({
                "appName": entry.appName,
                "summary": entry.summary,
                "critical": n.urgency === NotificationUrgency.Critical,
                "quiet": dnd
            });
            // a sender of ours may name its own sound (x-angelos-sound: heaven's stars ✦ have a quiet one)
            const own = String((n.hints || {})["x-angelos-sound"] || "");
            const sound = n.urgency === NotificationUrgency.Critical ? "error" : root.isScreenshot(entry) ? "screenshot" : Sounds.events.includes(own) ? own : "notify";
            if (root.isScreenshot(entry))
                Achievements.note("screenshot");
            // Golden Gate's shutter sounds under Do Not Disturb too (like a Mac's)
            if (!dnd || (sound === "screenshot" && GoldenGate.on))
                Sounds.play(sound);
        }
    }

    Timer {
        id: saveTimer
        interval: 800
        onTriggered: store.write(JSON.stringify(root.history.slice(0, 80)))
    }
    AsyncFile {
        id: store
        path: root.historyFile
        printErrors: false
        onLoaded: {
            try {
                // images handed over by the notifying app (image://qsimage/…) live only
                // as long as the shell that got them: after a restart they point nowhere
                root.history = (JSON.parse(text()) || []).map(h => String(h.icon || "").startsWith("image://qsimage/") ? Object.assign({}, h, {
                        "icon": ""
                    }) : h);
            } catch (e) {}
        }
    }
}
