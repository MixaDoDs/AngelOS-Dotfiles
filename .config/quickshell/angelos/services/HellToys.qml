pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// What hell's right-click menu toys say (story/toys.json): the rule under each look, the
// sullen souls' shouts, the courses served, the masks' lies, the summoned souls. The file
// reloads as it's edited; the lines are [ru, en] pairs.
Singleton {
    id: root

    readonly property string file: Quickshell.shellDir + "/story/toys.json"
    property var doc: ({})
    property bool loaded: false
    // souls pulled out by the pentagram, this session (so the next one is someone else)
    property int summoned: 0

    // a [ru, en] pair in the language, with %1, %2 filled in
    function t(pair, a, b) {
        const s = pair && pair.length ? I18n.t(String(pair[0]), String(pair[1] !== undefined ? pair[1] : pair[0])) : "";
        return s.replace(/%1/g, a === undefined ? "" : String(a)).replace(/%2/g, b === undefined ? "" : String(b));
    }
    function pick(list) {
        return list && list.length ? list[Math.floor(Math.random() * list.length)] : null;
    }
    function hint(look) {
        return t((doc.hints || {})[look]);
    }
    function part(name) {
        return doc[name] || {};
    }

    // read at once: the first menu may want the words before the file view says it's loaded
    Component.onCompleted: {
        try {
            doc = JSON.parse(view.text());
            loaded = true;
        } catch (e) {}
    }

    FileView {
        id: view
        path: root.file
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.doc = JSON.parse(text());
            } catch (e) {
                console.warn("story/toys.json: " + e);
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
}
