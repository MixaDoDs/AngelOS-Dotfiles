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
            const sound = n.urgency === NotificationUrgency.Critical ? "error" : root.isScreenshot(entry) ? "screenshot" : "notify";
            // Golden Gate's shutter sounds under Do Not Disturb too (like a Mac's)
            if (!dnd || (sound === "screenshot" && GoldenGate.on))
                Sounds.play(sound);
        }
    }

    Timer {
        id: saveTimer
        interval: 800
        onTriggered: store.setText(JSON.stringify(root.history.slice(0, 80)))
    }
    FileView {
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
