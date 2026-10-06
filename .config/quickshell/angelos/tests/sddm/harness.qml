import QtQuick
import Quickshell
import Quickshell.Io

// tests/sddm/run.sh: SDDM's objects stood in for (sddm, userModel, sessionModel, keyboard,
// config) and the theme loaded under them — the theme looks them up by name, as it does
// in the real greeter.
ShellRoot {
    id: shell

    property int failures: 0
    readonly property string shots: Quickshell.env("ANGELOS_TEST_SHOTS") || ""
    function report(name, ok, detail) {
        if (!ok)
            failures++;
        console.log("TEST " + name + " " + (ok ? "PASS" : "FAIL") + " " + (detail || ""));
    }
    function shot(name) {
        if (shots)
            stage.grabToImage(r => r.saveToFile(shots + "/sddm-" + name + ".png"));
    }
    function find(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        for (let i = 0; i < (item.children || []).length; i++) {
            const f = find(item.children[i], name);
            if (f)
                return f;
        }
        return null;
    }

    QtObject {
        id: sddm
        property string hostName: "angel"
        property bool canPowerOff: true
        property bool canReboot: true
        property bool canSuspend: true
        property var tried: []
        signal loginFailed
        signal loginSucceeded
        function login(user, password, session) {
            tried = tried.concat([[user, password, session]]);
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
        property string lastUser: "mixad"
        ListElement {
            name: "mixad"
            realName: "mixad"
            icon: ""
        }
        ListElement {
            name: "guest"
            realName: "Guest"
            icon: ""
        }
    }
    ListModel {
        id: sessionModel
        property int lastIndex: 0
        ListElement {
            name: "niri"
        }
        ListElement {
            name: "Plasma (Wayland)"
        }
    }
    QtObject {
        id: keyboard
        property var layouts: [
            {
                "shortName": "us"
            },
            {
                "shortName": "ru"
            }
        ]
        property int currentLayout: 1
        property bool capsLock: false
        property bool numLock: true
    }
    FileView {
        id: confFile
        path: "@THEME@/theme.conf"
        blockLoading: true
    }
    QtObject {
        id: config
        Component.onCompleted: {
            for (const line of String(confFile.text()).split("\n")) {
                const m = line.match(/^([A-Za-z0-9]+)=(.*)$/);
                if (m)
                    config[m[1]] = m[2];
            }
        }
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
    }

    FloatingWindow {
        // niri keeps "angelOS [dev]" windows on the side monitor, out of the screencast
        title: "angelOS [dev] sddm test"
        implicitWidth: 1280
        implicitHeight: 720
        color: "black"
        Item {
            id: stage
            width: 1920
            height: 1080
            Loader {
                id: theme
                anchors.fill: parent
                source: "file://@THEME@/Main.qml"
            }
        }
    }

    property int step: 0
    Timer {
        interval: 1200
        repeat: true
        running: true
        onTriggered: {
            const pw = shell.find(theme.item, "password");
            switch (shell.step++) {
            case 0:
                shell.report("load", theme.status === Loader.Ready && pw !== null, "status " + theme.status);
                shell.shot("idle");
                break;
            case 1:
                if (pw)
                    pw.text = "hunter22";
                interval = 150;
                break;
            case 2:
                shell.shot("typing");
                interval = 1200;
                if (pw)
                    pw.accepted();
                break;
            case 3:
                shell.report("login-call", sddm.tried.length === 1 && sddm.tried[0][0] === "mixad" && sddm.tried[0][1] === "hunter22", JSON.stringify(sddm.tried));
                sddm.loginFailed();
                interval = 120;
                break;
            case 4:
                shell.shot("fail");
                interval = 1500;
                break;
            case 5:
                if (pw) {
                    pw.text = "angel";
                    pw.accepted();
                }
                sddm.loginSucceeded();
                interval = 300;
                break;
            case 6:
                shell.shot("success");
                shell.report("cleared-after-fail", sddm.tried.length === 2, "tries " + sddm.tried.length);
                interval = 500;
                break;
            case 7:
                console.log("TEST DONE " + shell.failures);
                Qt.quit();
                break;
            }
        }
    }
}
