// The mini island (services/Island): a small browser of its own, a profile of its own
// (logins stay), no address bar. Its own process (qml6 + QtWebEngine): the shell can't host
// Chromium, and a page that falls over takes only this window with it.
// The shell talks by a little command file (ANGELOS_ISLAND_CMD, read here), the island
// answers with "ISLAND {json}" lines on stderr: tuck (to an edge), fullscreen, through,
// browser {url} (↗: the shell opens it), closed. Commands: open {url}, through {on}, browser (= ↗), quit.
import QtQuick
import QtQuick.Window
import QtWebEngine

Window {
    id: win
    // qml6 Island.qml -- URL CMDFILE WIDTH HEIGHT [dev] [shell-opens]   (the size is niri's rule's, this is a guess)
    // shell-opens: the shell opens ↗'s page (a shell of before it: the island does)
    readonly property var args: {
        const a = Qt.application.arguments;
        return a.slice(a.indexOf("--") + 1);
    }
    width: Number(args[2] || 460)
    height: Number(args[3] || 720)
    visible: true
    color: "#16141c"
    // the niri rule finds it by this title (the page's own title goes into the strip)
    title: args.indexOf("dev", 4) > 0 ? "angelOS · Остров [dev]" : "angelOS · Остров"
    readonly property bool shellOpens: args.indexOf("shell-opens", 4) > 0

    readonly property string cmdFile: args[1] || ""
    property int seq: -1
    property bool through: false        // clicks go through it to what is under it

    // our Lens page (services/Island.lens) is a file that posts the picture to Google: only it
    // may reach the net from file:// (a page loaded from a file can't otherwise)
    function go(u) {
        view.settings.localContentCanAccessRemoteUrls = /^file:\/\/.*\/angelos-island-lens\.html$/.test(u);
        view.url = u;
    }
    // ↗: the page it is on now (not the link it opened with) goes to the default browser —
    // the shell opens it (xdg-open, as all its links); on its own, the island opens it itself
    function toBrowser() {
        const u = view.url.toString();
        if (win.shellOpens)
            win.say({
                "ev": "browser",
                "url": u
            });
        else
            Qt.openUrlExternally(u);
        win.say({
            "ev": "closed"
        });
        Qt.quit();
    }
    function say(o) {
        console.warn("ISLAND " + JSON.stringify(o));
    }
    flags: through ? (Qt.Window | Qt.WindowTransparentForInput) : Qt.Window

    // shortcut: polls the command file (qml6 has no stdin), cheap at 4 Hz; a socket if it ever matters
    Timer {
        interval: 250
        running: win.cmdFile !== ""
        repeat: true
        onTriggered: {
            const x = new XMLHttpRequest();
            x.open("GET", "file://" + win.cmdFile, false);
            try {
                x.send();
            } catch (e) {
                return;
            }
            let c;
            try {
                c = JSON.parse(x.responseText);
            } catch (e) {
                return;
            }
            if (!c || typeof c.seq !== "number" || c.seq === win.seq)
                return;
            const first = win.seq < 0;
            win.seq = c.seq;
            if (first && c.cmd === "open" && c.url === win.args[0])
                return; // the link on the command line (a newer one, sent while it started, goes)
            if (c.cmd === "open")
                win.go(c.url);
            else if (c.cmd === "browser")
                win.toBrowser();
            else if (c.cmd === "through")
                win.through = !!c.on;
            else if (c.cmd === "quit")
                Qt.quit();
        }
    }

    WebEngineProfilePrototype {
        id: proto
        storageName: "angelos-island"
        persistentCookiesPolicy: WebEngineProfile.AllowPersistentCookies
    }

    WebEngineView {
        id: view
        anchors.fill: parent
        profile: proto.instance()
        Component.onCompleted: win.go(win.args[0] || "about:blank")
        opacity: win.through ? 0.82 : 1
        // a link that wants a new window stays here
        onNewWindowRequested: r => view.url = r.requestedUrl
        onFullScreenRequested: r => {
            r.accept();
            win.say({
                "ev": "fullscreen",
                "on": r.toggleOn
            });
        }
    }

    // the strip: shows when the pointer is near the top
    HoverHandler {
        id: hover
    }
    Rectangle {
        id: strip
        width: parent.width
        height: 34
        color: "#ee16141c"
        opacity: hover.hovered && hover.point.position.y < 60 || stripHover.hovered ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }
        HoverHandler {
            id: stripHover
        }
        Row {
            id: left
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Btn {
                glyph: "‹"
                tip: "Назад"
                enabled: view.canGoBack
                onHit: view.goBack()
            }
            Btn {
                glyph: view.loading ? "×" : "↻"
                tip: view.loading ? "Стоп" : "Обновить"
                onHit: view.loading ? view.stop() : view.reload()
            }
        }
        Text {
            anchors.left: left.right
            anchors.right: right.left
            anchors.margins: 6
            anchors.verticalCenter: parent.verticalCenter
            text: view.title || view.url
            elide: Text.ElideRight
            color: "#d8d0ea"
            font.pixelSize: 12
        }
        Row {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Btn {
                glyph: "◂"
                tip: "К краю: влево"
                onHit: win.say({
                        "ev": "tuck",
                        "side": "left"
                    })
            }
            Btn {
                glyph: "▴"
                tip: "К краю: вверх"
                onHit: win.say({
                        "ev": "tuck",
                        "side": "top"
                    })
            }
            Btn {
                glyph: "▾"
                tip: "К краю: вниз"
                onHit: win.say({
                        "ev": "tuck",
                        "side": "bottom"
                    })
            }
            Btn {
                glyph: "▸"
                tip: "К краю: вправо"
                onHit: win.say({
                        "ev": "tuck",
                        "side": "right"
                    })
            }
            Btn {
                glyph: "⇢"
                tip: "Клики сквозь остров (вернуть: Mod+Alt+I)"
                onHit: win.say({
                        "ev": "through"
                    })
            }
            Btn {
                glyph: "⛶"
                tip: "На весь экран"
                onHit: win.say({
                        "ev": "fullscreen"
                    })
            }
            Btn {
                glyph: "↗"
                tip: "Открыть в браузере"
                onHit: win.toBrowser()
            }
            Btn {
                glyph: "✕"
                tip: "Закрыть"
                onHit: {
                    win.say({
                        "ev": "closed"
                    });
                    Qt.quit();
                }
            }
        }
    }

    component Btn: Rectangle {
        id: b
        property string glyph
        property string tip
        signal hit
        width: 26
        height: 26
        radius: 7
        color: ma.containsMouse && enabled ? "#33c9b8ff" : "transparent"
        opacity: enabled ? 1 : 0.35
        Text {
            anchors.centerIn: parent
            text: b.glyph
            color: "#e8e0ff"
            font.pixelSize: 15
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (b.enabled)
                b.hit()
        }
    }
}
