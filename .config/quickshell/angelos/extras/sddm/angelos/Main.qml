import QtQuick
import QtQuick.Window

// angelOS login (SDDM). Several looks, picked in angelOS (Settings → Lock → Login screen) and
// kept in theme.conf's `look` — theme.conf.user (a link into walls/, the user's own part of
// the theme) overrides it, so changing the look needs no password:
//   stream  the NGO stream that is "starting soon" (StreamLook.qml)
//   heaven  a gate above the clouds, the sky of the hour (HeavenLook.qml)
//   retro   angelOS 98: the logon dialog of a Y2K desktop (RetroLook.qml)
//   hell    a pentagram, embers and a contract to sign (HellLook.qml)
//   quiet   just the wallpaper, a big clock and a slim field (QuietLook.qml)
// Each look is a whole screen of its own; the login state they share is Greeter.qml.
Rectangle {
    id: root

    width: Screen.width
    height: Screen.height
    color: "#000000"

    function conf(key, fallback) {
        const v = typeof config !== "undefined" && config ? config[key] : undefined;
        return v === undefined || v === null || String(v) === "" ? fallback : String(v);
    }
    readonly property var looks: ({
            "stream": "StreamLook.qml",
            "heaven": "HeavenLook.qml",
            "retro": "RetroLook.qml",
            "hell": "HellLook.qml",
            "quiet": "QuietLook.qml"
        })
    readonly property string look: looks[conf("look", "stream")] ? conf("look", "stream") : "stream"
    // the login is on the primary screen; the others get the look's second screen
    // (theme.conf role=login|cam pins it: a preview of one or the other)
    property bool primary: conf("role", "") === "cam" ? false : conf("role", "") === "login" ? true : typeof primaryScreen === "undefined" ? true : !!primaryScreen
    readonly property int u: view.item ? view.item.u : 1

    Loader {
        id: view
        objectName: "look"
        anchors.fill: parent
        source: root.looks[root.look]
        focus: true
        onLoaded: item.primary = Qt.binding(() => root.primary)
        // a look that does not load (a broken edit): the stream, which always has
        onStatusChanged: if (status === Loader.Error && source.toString().indexOf("StreamLook") < 0)
            source = "StreamLook.qml"
    }
}
