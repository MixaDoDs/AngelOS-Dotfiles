import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The login screen (extras/sddm/angelos) live, in miniature (Settings → Lock → Login screen):
// the theme as `angelos sddm build` puts it together, loaded under stand-ins for SDDM's
// objects (sddm, userModel, sessionModel, keyboard, config — the theme looks them up by
// name) on a 1920×1080 stage (1080×1920 standing) scaled into the box. It only looks:
// keys and clicks never reach it; failed()/succeeded() play the answers.
Item {
    id: root

    property string look: "stream"
    property string screenKind: "wide"          // wide | tall | cam
    property string themeDir: ""                 // a built theme (sddm-theme.py build --out)
    property int stamp: 0                        // bump after a rebuild: theme.conf is read again
    readonly property bool ready: view.status === Loader.Ready
    readonly property real stageW: screenKind === "tall" ? 1080 : 1920
    readonly property real stageH: screenKind === "tall" ? 1920 : 1080

    implicitHeight: width * 9 / 16
    clip: true

    function failed() {
        sddm.loginFailed();
    }
    function succeeded() {
        sddm.loginSucceeded();
        again.restart();
    }
    // after "logged in" the theme stays in its end state: load it fresh
    Timer {
        id: again
        interval: 2600
        onTriggered: root.reload()
    }
    function reload() {
        view.active = false;
        view.active = true;
    }
    onLookChanged: reload()
    onScreenKindChanged: reload()

    QtObject {
        id: sddm
        property string hostName: "angel"
        property bool canPowerOff: true
        property bool canReboot: true
        property bool canSuspend: true
        signal loginFailed
        signal loginSucceeded
        function login(user, password, session) {
        }
        function powerOff() {
        }
        function reboot() {
        }
        function suspend() {
        }
    }
    ListModel {
        id: userModel
        property int lastIndex: 0
        property string lastUser: Quickshell.env("USER") || "angel"
        Component.onCompleted: append({
            "name": lastUser,
            "realName": lastUser,
            "icon": ""
        })
    }
    ListModel {
        id: sessionModel
        property int lastIndex: 0
        ListElement {
            name: "niri"
        }
    }
    QtObject {
        id: keyboard
        property var layouts: [
            {
                "shortName": I18n.english ? "us" : "ru"
            }
        ]
        property int currentLayout: 0
        property bool capsLock: false
        property bool numLock: true
    }
    FileView {
        id: confFile
        path: root.themeDir ? root.themeDir + "/theme.conf" : ""
        blockLoading: true
    }
    FileView {
        id: userConfFile
        path: root.themeDir ? root.themeDir + "/walls/theme.conf.user" : ""
        blockLoading: true
    }
    // after the path is set (themeDir and stamp change together)
    onStampChanged: Qt.callLater(reread)
    onThemeDirChanged: Qt.callLater(reread)
    function reread() {
        confFile.reload();
        userConfFile.reload();
        config.read();
        reload();
    }
    QtObject {
        id: config
        function read() {
            for (const line of (String(confFile.text()) + "\n" + String(userConfFile.text())).split("\n")) {
                const m = line.match(/^([A-Za-z0-9]+)=(.*)$/);
                if (m && (m[1] in config) && typeof config[m[1]] === "string" && m[1] !== "look" && m[1] !== "role")
                    config[m[1]] = m[2];
            }
        }
        Component.onCompleted: read()
        property string desk
        property string face
        property string faceAlt
        property string sunken
        property string edge
        property string hi
        property string lo
        property string text
        property string textDim
        property string titleText
        property string accent
        property string accent2
        property string accent3
        property string danger
        property string title1
        property string title2
        property string language
        property string pixelate
        property string palette
        property string background
        property string suffix
        property string look: root.look
        property string role: root.screenKind === "cam" ? "cam" : "login"
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }
    // the theme takes the keyboard for its password field (a timer, a click, a mistake):
    // in Settings it must not — the focus goes back where it was
    property Item lastFocus: null
    function inside(item) {
        for (let p = item; p; p = p.parent)
            if (p === stage)
                return true;
        return false;
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() {
            const f = root.Window.window.activeFocusItem;
            if (!f)
                return;
            if (!root.inside(f))
                root.lastFocus = f;
            else
                Qt.callLater(() => {
                    if (root.lastFocus)
                        root.lastFocus.forceActiveFocus();
                    else
                        f.focus = false;
                });
        }
    }
    Item {
        id: stage
        width: root.stageW
        height: root.stageH
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.TopLeft
        x: Math.round((root.width - width * scale) / 2)
        // view only: no focus, no clicks (the theme asks for the keyboard)
        enabled: false
        Loader {
            id: view
            anchors.fill: parent
            active: root.themeDir !== "" && root.visible
            source: root.themeDir ? "file://" + root.themeDir + "/Main.qml" : ""
        }
    }
}
