import QtQuick
import Quickshell
import qs.services
import qs.widgets

// A bar popup that is not there until it is asked for. Nine of them a screen — the calendar, the
// mixer, Wi-Fi, the tray… — built at start and kept hidden were ~2700 objects a screen
// (2026-10-12). The BarPopup inside is built in the background when the pointer comes to its
// button (`warm`), at once when it is toggled before that, and goes half a minute after it
// closed. `visible` and toggle() are the popup's; `angelos panel ID` and the gestures find it by
// `panelId` while it is not built (PopupManager.showPanel).
//
//   LazyPopup {
//       id: pop
//       panelId: "wifi"
//       anchorItem: root
//       warm: root.hovered
//       BarPopup { id: panel; panelId: "wifi"; anchorItem: root; … }
//   }
Scope {
    id: root

    default property Component popup
    property string panelId: ""
    // the popup's button: says which screen this one is on
    property Item anchorItem: null
    // the pointer is on the button: build now, the click finds it ready
    property bool warm: false
    readonly property var item: loader.item
    readonly property bool visible: !!loader.item && loader.item.visible
    readonly property string outputName: anchorItem && anchorItem.QsWindow.window && anchorItem.QsWindow.window.screen ? anchorItem.QsWindow.window.screen.name : ""
    property bool asked: false

    function toggle() {
        asked = true;
        loader.active = true;
        PopupManager.toggle(loader.item);
        asked = false;
    }
    function close() {
        if (loader.item)
            PopupManager.close(loader.item);
    }
    // built now, without opening (the UI self-test: a popup that is never built hides its errors)
    function build() {
        asked = true;
        loader.active = true;
        asked = false;
        return !!loader.item;
    }

    Component.onCompleted: PopupManager.registerLazy(root)
    Component.onDestruction: PopupManager.unregisterLazy(root)

    Linger {
        id: keep
        when: root.visible || root.warm || root.asked
        ms: 30000
    }
    LazyLoader {
        id: loader
        component: root.popup
        activeAsync: keep.alive
    }
}
