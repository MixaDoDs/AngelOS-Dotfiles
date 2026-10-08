pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Dims the screen, cuts a pixel circle around the current element and explains it.
PanelWindow {
    id: win

    readonly property var step: Tour.current
    readonly property var tgt: step ? Tour.target(step.key) : null
    // the tour's screen (Tour.start: the main one); its elements are the ones on it
    screen: Shell.screenByName(Tour.screen) || Shell.mainScreenFor("") || Shell.focusedScreen
    visible: Tour.running && !!step
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "angelos-tour"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: interface tips: a click goes on
    WlrLayershell.keyboardFocus: visible ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    // target rect in screen coordinates
    readonly property rect hole: {
        Tour.revision;
        if (!Tour.running || !step || step.key === "end")
            return Qt.rect(width / 2, height / 2, 0, 0);
        if (step.key === "desktop")
            return Qt.rect(width / 2 - Theme.u * 60, height / 2 - Theme.u * 60, Theme.u * 120, Theme.u * 120);
        // registered items can already be gone (a reload tears the bars down first)
        if (!tgt || !tgt.item || !tgt.window || typeof tgt.item.mapToItem !== "function" || !tgt.window.contentItem)
            return Qt.rect(width / 2, height / 2, 0, 0);
        const w = tgt.window, it = tgt.item;
        const p = it.mapToItem(w.contentItem, 0, 0);
        // layer-shell doesn't tell us where the bar sits; derive it from its anchors
        const wy = w.anchors && w.anchors.bottom && !w.anchors.top ? height - w.height - (w.margins ? w.margins.bottom : 0) : (w.margins ? w.margins.top : 0);
        const wx = w.anchors && w.anchors.left && w.anchors.right ? 0 : (width - w.width) / 2;
        return Qt.rect(wx + p.x, wy + p.y, it.width, it.height);
    }
    readonly property real cx: hole.x + hole.width / 2
    readonly property real cy: hole.y + hole.height / 2
    readonly property real radius: Math.max(Theme.u * 14, Math.sqrt(hole.width * hole.width + hole.height * hole.height) / 2 + Theme.u * 6)
    property real pulse: 0
    SequentialAnimation on pulse {
        running: win.visible && !Motion.still
        alwaysRunToEnd: true
        loops: Animation.Infinite
        NumberAnimation {
            to: 1
            duration: Motion.ms(900)
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 0
            duration: Motion.ms(900)
            easing.type: Easing.InOutSine
        }
    }
    onHoleChanged: dim.requestPaint()
    onPulseChanged: dim.requestPaint()

    Canvas {
        id: dim
        anchors.fill: parent
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.55);
            ctx.fillRect(0, 0, width, height);
            if (!win.step || win.step.key === "end")
                return;
            // blocky circle: punch it out, then draw a pixel ring
            const b = Theme.u * 2, r = win.radius, cx = win.cx, cy = win.cy;
            ctx.globalCompositeOperation = "destination-out";
            for (let y = -r; y <= r; y += b)
                for (let x = -r; x <= r; x += b)
                    if (x * x + y * y <= r * r)
                        ctx.fillRect(Math.round((cx + x) / b) * b, Math.round((cy + y) / b) * b, b, b);
            ctx.globalCompositeOperation = "source-over";
            const rr = r + b * (1 + Math.round(win.pulse * 2));
            ctx.fillStyle = Theme.accent;
            for (let a = 0; a < 360; a += 3) {
                const t = a * Math.PI / 180;
                ctx.fillRect(Math.round((cx + Math.cos(t) * rr) / b) * b, Math.round((cy + Math.sin(t) * rr) / b) * b, b, b);
            }
        }
    }

    // clicks outside the card do nothing (the tour is modal), inside the hole go to "next"
    MouseArea {
        anchors.fill: parent
        onClicked: m => {
            const dx = m.x - win.cx, dy = m.y - win.cy;
            if (dx * dx + dy * dy <= win.radius * win.radius)
                Tour.next();
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape)
                Tour.stop();
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                Tour.next();
            else if (e.key === Qt.Key_Left)
                Tour.back();
            e.accepted = true;
        }
    }
    onVisibleChanged: if (visible)
        keys.forceActiveFocus()

    PxWindow {
        id: card
        width: Theme.u * 150
        height: titleHeight + body.implicitHeight + Theme.pad * 2 + Theme.u * 8
        title: I18n.exe("tips") + " · " + (Tour.step + 1) + "/" + Tour.active.length
        icon: "info"
        compact: true
        onCloseClicked: Tour.stop()
        // beside the circle: above it for the bottom bar, below it otherwise, centered for the end
        x: Math.max(Theme.u * 6, Math.min(win.width - width - Theme.u * 6, win.cx - width / 2))
        y: win.step && win.step.key === "end" ? (win.height - height) / 2 : (win.cy > win.height / 2 ? win.cy - win.radius - height - Theme.u * 10 : win.cy + win.radius + Theme.u * 10)
        Behavior on x {
            NumberAnimation {
                duration: Motion.ms(Theme.normal)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Motion.ms(Theme.normal)
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: body
            width: parent.width
            spacing: Theme.u * 4
            PxText {
                text: win.step ? win.step.title : ""
                kind: "title"
                color: Theme.dark ? Theme.accent : Theme.edge
            }
            PxText {
                width: parent.width
                wrapMode: Text.Wrap
                text: win.step ? win.step.text : ""
            }
            Row {
                anchors.right: parent.right
                spacing: Theme.u * 3
                PxButton {
                    compact: true
                    text: I18n.t("Пропустить", "Skip")
                    visible: Tour.step + 1 < Tour.active.length
                    onClicked: Tour.stop()
                }
                PxButton {
                    compact: true
                    text: "◂"
                    enabled: Tour.step > 0
                    onClicked: Tour.back()
                }
                PxButton {
                    compact: true
                    accent: true
                    text: Tour.step + 1 < Tour.active.length ? I18n.t("Дальше ▸", "Next ▸") : I18n.t("Готово", "Done")
                    onClicked: Tour.next()
                }
            }
        }
    }

    RightClickGuard {}
}
