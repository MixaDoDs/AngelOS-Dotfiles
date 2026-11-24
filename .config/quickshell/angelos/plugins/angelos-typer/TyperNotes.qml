pragma Singleton
import QtQuick
import qs.config
import qs.services

QtObject {
    id: root
    property var context: null
    readonly property string type: "plugin:angelos-typer"
    readonly property var papers: DesktopWidgets.widgets.filter(w => w.type === root.type && w.settings && w.settings.text)
    readonly property string draft: context ? String(context.get("draft", "")) : ""
    readonly property var archive: context ? context.get("paperArchive", []) : []
    property var fading: []
    property string newest: ""
    property string error: ""
    function setDraft(text) { if (context && text !== draft) context.set("draft", text); }
    function finishPending() {
        for (const entry of archive)
            if (entry.uid && DesktopWidgets.byUid(entry.uid)) DesktopWidgets.remove(entry.uid);
        for (const paper of papers)
            if (paper.depth === "deep") DesktopWidgets.setDepth(paper.uid, "");
    }
    function move(uid, x, y) {
        if (!Number.isFinite(x) || !Number.isFinite(y)) return;
        Config.desktop.widgets = (Config.desktop.widgets || []).map(w => w.uid === uid
            ? Object.assign({}, w, {x:x,y:y}) : w);
    }
    function pin(text, screen) {
        error = "";
        text = String(text).trim();
        if (!context || !text) return "";
        if (text.length > 8000) { error = "Для бумажки — до 8000 символов."; return ""; }
        const before = new Set(DesktopWidgets.widgets.map(w => w.uid));
        DesktopWidgets.add(type, screen || Niri.focusedOutput || Shell.primaryName);
        const added = DesktopWidgets.widgets.find(w => w.type === type && !before.has(w.uid));
        if (!added) { error = "Не получилось прикрепить заметку."; return ""; }
        DesktopWidgets.setFrame(added.uid, "none");
        DesktopWidgets.setDepth(added.uid, "");
        DesktopWidgets.setSetting(added.uid, "text", text);
        DesktopWidgets.setSetting(added.uid, "created", Date.now());
        newest = added.uid;
        setDraft("");
        return added.uid;
    }
    function dismiss(uid) {
        if (!context || fading.includes(uid)) return;
        const paper = DesktopWidgets.byUid(uid);
        if (!paper || paper.type !== type) return;
        context.set("paperArchive", archive.concat([{uid: uid, text: paper.settings.text, screen: paper.screen,
            x: paper.x, y: paper.y, created: paper.settings.created}]).slice(-20));
        fading = fading.concat([uid]);
        dismissTimer.restart();
    }
    function restore() {
        if (!context || !archive.length || fading.length) return "";
        const copy = archive.slice(), saved = copy.pop(), before = draft;
        const uid = pin(saved.text, saved.screen);
        if (!uid) return "";
        setDraft(before);
        move(uid, saved.x, saved.y);
        context.set("paperArchive", copy);
        return uid;
    }
    property Timer dismissTimer: Timer {
        interval: Skin.ms(160) + 10
        onTriggered: {
            const ids = root.fading;
            root.fading = [];
            for (const uid of ids) DesktopWidgets.remove(uid);
        }
    }
}
