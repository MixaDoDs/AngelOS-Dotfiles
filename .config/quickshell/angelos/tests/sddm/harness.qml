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
            stage.grabToImage(r => r.saveToFile(shots + "/sddm-" + (config.look || "stream") + "-" + name + ".png"));
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
    // SDDM reads theme.conf.user over theme.conf (the build keeps it in walls/)
    FileView {
        id: userConfFile
        path: "@THEME@/walls/theme.conf.user"
        blockLoading: true
    }
    QtObject {
        id: config
        Component.onCompleted: {
            for (const line of (String(confFile.text()) + "\n" + String(userConfFile.text())).split("\n")) {
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
        property string look
        property string role
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
        // the other shapes, out of sight: a portrait login screen; the second camera
        // standing and lying (`primary` false: SDDM's primaryScreen)
        Item {
            id: tallStage
            x: 2000
            width: 1080
            height: 1920
            Loader {
                id: tallTheme
                anchors.fill: parent
                source: "file://@THEME@/Main.qml"
            }
        }
        Item {
            id: camTallStage
            x: 3200
            width: 1080
            height: 1920
            Loader {
                id: camTallTheme
                anchors.fill: parent
                source: "file://@THEME@/Main.qml"
                onLoaded: item.primary = false
            }
        }
        Item {
            id: camWideStage
            x: 4400
            width: 1920
            height: 1080
            Loader {
                id: camWideTheme
                anchors.fill: parent
                source: "file://@THEME@/Main.qml"
                onLoaded: item.primary = false
            }
        }
    }

    // every named part on the screen, none over another
    function layout(name, loader, names) {
        const it = loader.item;
        if (!it) {
            report("layout-" + name, false, "not loaded");
            return;
        }
        const rects = [];
        let bad = "";
        for (const n of names) {
            const f = find(it, n);
            if (!f || !f.visible) {
                bad += n + " missing; ";
                continue;
            }
            const p = f.mapToItem(it, 0, 0);
            const r = Qt.rect(Math.round(p.x), Math.round(p.y), Math.round(f.width), Math.round(f.height));
            if (r.x < 0 || r.y < 0 || r.x + r.width > it.width || r.y + r.height > it.height)
                bad += n + " off-screen " + JSON.stringify([r.x, r.y, r.width, r.height]) + "; ";
            for (const o of rects)
                if (r.x < o.r.x + o.r.width && o.r.x < r.x + r.width && r.y < o.r.y + o.r.height && o.r.y < r.y + r.height)
                    bad += n + " over " + o.n + "; ";
            rects.push({ "n": n, "r": r });
        }
        report("layout-" + name, bad === "", bad || ("u " + it.u));
    }
    function shotOf(item, name) {
        if (shots)
            item.grabToImage(r => r.saveToFile(shots + "/sddm-" + (config.look || "stream") + "-" + name + ".png"));
    }

    readonly property bool stream: (config.look || "stream") === "stream"
    property int step: 0
    Timer {
        interval: 1200
        repeat: true
        running: true
        onTriggered: {
            const pw = shell.find(theme.item, "password");
            switch (shell.step++) {
            case 0:
                shell.report("load", theme.status === Loader.Ready && pw !== null, "status " + theme.status + ", look " + (theme.item ? theme.item.look : "?"));
                shell.report("look", !!theme.item && theme.item.look === (config.look || "stream"), "asked " + config.look);
                shell.shot("idle");
                shell.layout("wide", theme, stream ? ["center", "chat"] : ["center"]);
                shell.layout("tall", tallTheme, stream ? ["center", "chat"] : ["center"]);
                shell.layout("cam-tall", camTallTheme, stream ? ["camMain", "camChat"] : ["camMain"]);
                shell.layout("cam-wide", camWideTheme, stream ? ["camMain", "camChat"] : ["camMain"]);
                const camLogin = camTallTheme.item ? shell.find(camTallTheme.item, "login") || shell.find(camTallTheme.item, "center") : null;
                shell.report("cam-no-login", !!camTallTheme.item && !(camLogin && camLogin.visible) && shell.find(camTallTheme.item, "camMain").visible, "");
                if (stream)
                    shell.report("cam-angel", !!camTallTheme.item && shell.find(camTallTheme.item, "angel") !== null && shell.find(camTallTheme.item, "angel").ready, "");
                shell.shotOf(stage, "wide");
                shell.shotOf(tallStage, "tall");
                shell.shotOf(camTallStage, "cam-tall");
                shell.shotOf(camWideStage, "cam-wide");
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
