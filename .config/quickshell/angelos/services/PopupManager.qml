pragma Singleton

import QtQuick
import Quickshell

// Only one bar popup may be open at a time.
Singleton {
    id: root

    property var active: null
    property var registered: []
    // A popup's input grab only ends on clicks outside angelOS, so presses on the
    // bar itself close the open popup here. The click that follows such a press
    // must not reopen the popup it just closed (its own button toggles it).
    property var dismissed: null
    property double dismissedAt: 0
    function barPressed() {
        if (!active)
            return;
        dismissed = active;
        dismissedAt = Date.now();
        close(active);
    }
    function registerPopup(popup) {
        registered = registered.concat([popup]);
    }
    function unregisterPopup(popup) {
        if (active === popup)
            active = null;
        registered = registered.filter(p => p !== popup);
    }
    // popups that are built when first asked for (modules/bar/LazyPopup): known by their id
    // before that
    property var lazy: []
    function registerLazy(popup) {
        lazy = lazy.concat([popup]);
    }
    function unregisterLazy(popup) {
        lazy = lazy.filter(p => p !== popup);
    }
    function showPanel(name, output) {
        const popup = registered.find(p => p.panelId === name && (!output || p.outputName === output));
        if (popup) {
            toggle(popup);
            return true;
        }
        const later = lazy.find(p => p.panelId === name && (!output || p.outputName === output));
        if (later)
            later.toggle();
        return !!later;
    }

    function toggle(popup) {
        if (!popup)
            return;
        if (popup === dismissed && Date.now() - dismissedAt < 600) {
            dismissed = null;
            return;
        }
        dismissed = null;
        if (active === popup) {
            popup.visible = false;
            active = null;
            return;
        }
        if (active)
            active.visible = false;
        active = popup;
        popup.visible = true;
    }

    function close(popup) {
        if (popup)
            popup.visible = false;
        if (active === popup)
            active = null;
    }
}
