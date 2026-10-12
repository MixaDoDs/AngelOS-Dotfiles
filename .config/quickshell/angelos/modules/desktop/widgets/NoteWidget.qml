pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.widgets

// A sticker on the desktop: text and a checklist. Kept as plain text in
// ~/.config/angelos/notes/<uid>.md (any editor may change it: the widget follows the file).
// A line "[ ] …" (or "- [ ] …") is a box to tick with a click, "[x] …" a ticked one, "# …" a
// heading. Written in a little editor over the sticker: a click on its text (or right-click → Edit).
// The editor is a window of its own over everything (layer Top, the keyboard its own while it is
// open: the desktop's layer never gets the keyboard, so a popup of it could not be typed in). It
// writes as you type; Enter after "[ ] …" starts the next box (on an empty box: ends the list),
// Ctrl+Enter / Esc / a click outside close it.
//   S / M / L: its width and how many lines show (the rest fades into "…")
// The paper takes one of the theme's accents (right-click → Colour). In hell: scorched paper.
// The text lives in DesktopWidgets.notes, so the face shows a tick the moment the input copy (the
// clicks, the editor) makes it; the input copy writes the file, both read it (an edit by hand).
Item {
    id: root

    property string screenName
    property var widget
    property string size: "m"
    property string frameKind: "window"
    property bool face: true
    readonly property bool passive: false    // the boxes tick, the editor opens

    readonly property var st: widget && widget.settings ? widget.settings : ({})
    readonly property string uid: widget ? widget.uid : "note"
    readonly property string path: Config.dir + "/notes/" + uid.replace(/[^\w-]/g, "_") + ".md"
    readonly property color tint: [Theme.accent, Theme.accent2, Theme.accent3, Theme.accent4][Math.max(0, Math.min(3, st.tint || 0))]
    readonly property color paper: Theme.hell ? Theme.mix(Theme.hellSunken, Theme.hellBlood, 0.18) : Theme.mix(Theme.face, tint, Theme.dark ? 0.22 : 0.35)
    readonly property color ink: Theme.hell ? Theme.hellText : Theme.text
    readonly property string noteFont: Theme.hell ? Theme.fontHellText : Theme.fontBody
    readonly property int px: Theme.hell ? Theme.hellTextPx(Theme.fs) : Theme.sizeBody
    readonly property int maxLines: ({
            "s": 5,
            "m": 10,
            "l": 20
        })[size] || 10

    implicitWidth: Theme.u * (({
                "s": 80,
                "m": 110,
                "l": 150
            })[size] || 110)
    implicitHeight: lines.implicitHeight + Theme.u * 8

    // ---- the file ----
    readonly property string text: DesktopWidgets.notes[uid] !== undefined ? DesktopWidgets.notes[uid] : ""
    property bool loaded: false
    readonly property string welcome: I18n.t("# Заметка ♡\n[ ] щёлкни по квадратику\n[ ] щёлкни по тексту — откроется редактор", "# A note ♡\n[ ] click a box\n[ ] click the text to edit it")
    AsyncFile {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reloadSoon()
        onLoaded: {
            DesktopWidgets.setNote(root.uid, text());
            root.loaded = true;
        }
        onLoadFailed: {
            // a new note: the welcome text, written by the copy that writes
            if (!root.loaded) {
                root.loaded = true;
                if (DesktopWidgets.notes[root.uid] === undefined)
                    root.save(root.welcome);
            }
        }
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", Config.dir + "/notes"]
        property string pending: ""
        onExited: file.write(pending)
    }
    function save(t) {
        DesktopWidgets.setNote(uid, t);
        if (face)
            return;
        mkdir.pending = t;
        mkdir.running = true;
    }

    // ---- the lines: {kind: head | box | text, text, done, at (the line in the file)} ----
    readonly property var parsed: {
        const out = [];
        const all = text.split("\n");
        for (let i = 0; i < all.length; i++) {
            const l = all[i];
            const box = l.match(/^\s*(?:[-*]\s+)?\[([ xX])\]\s?(.*)$/);
            if (box)
                out.push({
                    "kind": "box",
                    "text": box[2],
                    "done": box[1] !== " ",
                    "at": i
                });
            else if (/^#+\s/.test(l))
                out.push({
                    "kind": "head",
                    "text": l.replace(/^#+\s+/, ""),
                    "at": i
                });
            else
                out.push({
                    "kind": "text",
                    "text": l,
                    "at": i
                });
        }
        while (out.length && out[out.length - 1].kind === "text" && !out[out.length - 1].text.trim())
            out.pop();
        return out;
    }
    function tick(at) {
        const all = text.split("\n");
        all[at] = all[at].replace(/\[([ xX])\]/, (m, c) => c === " " ? "[x]" : "[ ]");
        save(all.join("\n"));
    }

    // ---- the paper ----
    Rectangle {
        anchors.fill: parent
        color: root.paper
        radius: DesktopWidgets.macLook ? DesktopWidgets.mpx(10) : 0
        border.width: DesktopWidgets.macLook ? 0 : Math.max(1, Theme.u / 2)
        border.color: Theme.hell ? Theme.hellEdge : Qt.alpha(Theme.edge, 0.35)
        // the folded corner
        Rectangle {
            visible: !DesktopWidgets.macLook
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Theme.u * 5
            height: width
            color: Theme.hell ? Theme.hellFaceAlt : Theme.mix(root.paper, Theme.edge, 0.2)
        }
        // a click on the text opens the editor (in edit mode the press is the frame's: a drag)
        MouseArea {
            anchors.fill: parent
            enabled: !root.face && !DesktopWidgets.editMode
            cursorShape: Qt.IBeamCursor
            onClicked: editor.open()
        }
    }

    Column {
        id: lines
        x: Theme.u * 4
        y: Theme.u * 4
        width: root.width - Theme.u * 8
        spacing: Theme.u
        Repeater {
            model: root.parsed.slice(0, root.maxLines)
            Item {
                id: line
                required property var modelData
                width: lines.width
                height: Math.max(label.implicitHeight, line.modelData.kind === "box" ? Theme.u * 6 : 0)
                // the box
                PxBox {
                    id: box
                    visible: line.modelData.kind === "box"
                    y: Theme.u
                    width: Theme.u * 5
                    height: width
                    sunken: true
                    hell: Theme.hell
                    color: Theme.hell ? Theme.hellSunken : Theme.sunken
                    PxIcon {
                        visible: !!line.modelData.done
                        anchors.centerIn: parent
                        name: "check"
                        pixel: Math.max(1, Math.round(Theme.u / 2))
                    }
                }
                PxText {
                    id: label
                    x: box.visible ? box.width + Theme.u * 2 : 0
                    width: parent.width - x
                    text: line.modelData.text || " "
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font.family: root.noteFont
                    font.pixelSize: line.modelData.kind === "head" ? Math.round(root.px * 1.15) : root.px
                    font.bold: line.modelData.kind === "head" && !Theme.hell
                    font.strikeout: line.modelData.kind === "box" && line.modelData.done
                    color: root.ink
                    opacity: line.modelData.kind === "box" && line.modelData.done ? 0.55 : 1
                }
                MouseArea {
                    visible: line.modelData.kind === "box" && !root.face
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tick(line.modelData.at)
                    onDoubleClicked: {}
                }
            }
        }
        PxText {
            visible: root.parsed.length > root.maxLines
            text: "… +" + (root.parsed.length - root.maxLines)
            kind: "tiny"
            font.family: root.noteFont
            color: root.ink
            opacity: 0.6
        }
    }

    // ---- the editor over the sticker (the input copy: it lives where the clicks are) ----
    Connections {
        target: DesktopWidgets
        function onRequest(uid, what) {
            if (!root.face && uid === root.uid && what === "edit")
                editor.open();
        }
    }
    readonly property alias editorState: editor
    function commitSoon() {
        autosave.restart();
    }
    QtObject {
        id: editor
        property bool shown: false
        property string draft: ""
        function open() {
            if (root.face)
                return;
            draft = root.text;
            shown = true;
        }
        function done() {
            if (!shown)
                return;
            commit();
            shown = false;
        }
        function commit() {
            if (draft !== root.text)
                root.save(draft);
        }
    }
    // what is typed is kept a moment after the last key (a restart of the shell loses nothing)
    Timer {
        id: autosave
        interval: 700
        onTriggered: editor.commit()
    }
    // Enter after a box line: the next box; on an empty box line: the list ends there
    function continueList(area) {
        const pos = area.input.cursorPosition;
        const txt = area.text;
        const lineStart = txt.lastIndexOf("\n", pos - 1) + 1;
        const line = txt.slice(lineStart, pos);
        const m = line.match(/^(\s*(?:[-*]\s+)?)\[[ xX]\]\s?(.*)$/);
        if (!m)
            return false;
        if (!m[2].trim() && txt.slice(pos).split("\n")[0].trim() === "") {
            area.text = txt.slice(0, lineStart) + txt.slice(pos);
            area.input.cursorPosition = lineStart;
            return true;
        }
        const add = "\n" + m[1] + "[ ] ";
        area.text = txt.slice(0, pos) + add + txt.slice(pos);
        area.input.cursorPosition = pos + add.length;
        return true;
    }
    LazyLoader {
        active: editor.shown && !root.face
        source: Qt.resolvedUrl("NoteEditor.qml")
        onItemChanged: if (item)
            item.note = root
    }
}
