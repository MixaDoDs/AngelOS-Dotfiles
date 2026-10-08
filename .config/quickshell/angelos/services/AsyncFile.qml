import QtQuick
import Quickshell.Io

// A FileView for files the shell writes again and again (state, history, caches).
// A FileView write is atomic: a temp file, fdatasync on a worker thread, rename.
// Writing again (or reloading) before the last write is on disk makes Quickshell
// wait for it on the main thread, the whole shell with it; on a busy disk (btrfs
// while Steam downloads) that fdatasync took over 15 s and the guard restarted the
// shell (#52). write() never waits: while one write is on its way only the newest
// text is kept and goes out after it. Use write() and reloadSoon() instead of
// setText() and reload().
FileView {
    id: root

    readonly property bool writing: _busy
    property bool _busy: false
    property var _next: null
    property bool _reloadAfter: false
    // what the file holds as far as FileView knows: setText() of the same text sends
    // nothing (and no `saved` would come to end the write)
    property var _last: null

    function write(text) {
        text = String(text);
        if (_busy) {
            _next = text;
            return;
        }
        if (text === _last)
            return;
        _busy = true;
        _last = text;
        setText(text);
    }
    function reloadSoon() {
        if (_busy)
            _reloadAfter = true;
        else
            reload();
    }
    // `saved` comes before Quickshell lets go of the finished write: a write from the
    // handler would count as "while one is on its way" again, hence the next turn
    function _done() {
        Qt.callLater(_after);
    }
    function _after() {
        _busy = false;
        if (_next !== null) {
            const next = _next;
            _next = null;
            write(next);
        } else if (_reloadAfter) {
            _reloadAfter = false;
            reload();
        }
    }

    // (FileView's default property is its adapter: the watcher goes in a property)
    property Connections _watch: Connections {
        target: root
        function onSaved() {
            root._done();
        }
        function onSaveFailed() {
            root._last = null;
            root._done();
        }
        function onLoaded() {
            if (!root._busy)
                root._last = root.text();
        }
        function onPathChanged() {
            root._last = null;
        }
    }
}
