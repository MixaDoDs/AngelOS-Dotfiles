pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// The Angel's diary (services/Diary, story/diary.json), over the desktop: a black leather book
// with a gold pentagram slides in from its side, the key (story/items.json, the thing that
// opens it) turns in the clasp, and the cover swings open from that side — "right": the spine
// on the left, like a book; "left": the spine on the right (Settings → Achievements, or the
// author's story/diary.json → side). Two pages a spread; ‹ › or the arrow keys turn a page,
// Esc or a click beside the book closes it. Motion off: no swinging, it is just open.
PanelWindow {
    id: win

    screen: Shell.focusedScreen
    // open, or still closing (the cover swings shut first)
    visible: Shell.diaryOpen || phase !== "gone"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Qt.alpha("#0b0306", 0.55 * shade)
    WlrLayershell.namespace: "angelos-diary"
    WlrLayershell.layer: WlrLayer.Overlay
    // takes input: a book over the desktop: a click beside it closes it, the keys turn its pages
    WlrLayershell.keyboardFocus: Shell.diaryOpen ? (Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    // a board of the binding: black-red leather a little bigger than a page
    component Board: Rectangle {
        property real pad: 0
        property real pageW: 0
        property real pageH: 0
        y: -pad
        width: pageW + pad * 2
        height: pageH + pad * 2
        radius: pad * 0.8
        color: "#1d0a0e"
        border.width: Math.max(1, pad * 0.18)
        border.color: "#5b1520"
    }

    readonly property bool still: Motion.level === "off"
    function ms(n) {
        return still ? 0 : Motion.ms(n);
    }
    readonly property bool fromRight: Diary.side !== "left"   // the cover opens to the left, the spine on the left

    // ---- the size: a page is 0.7 of its height, the spread fits the screen ----
    readonly property real pageH: Math.min(height * 0.8, (width * 0.9) / 2 / 0.7, 820)
    readonly property real pageW: Math.round(pageH * 0.7)
    readonly property real coverPad: Math.round(pageH * 0.022)

    // ---- the pages: two a spread ----
    readonly property var pages: Diary.shown
    property int spread: 0
    readonly property int spreads: Math.max(1, Math.ceil(pages.length / 2))
    function pageAt(i) {
        return i >= 0 && i < pages.length ? pages[i] : null;
    }
    function spreadOf(id) {
        const i = pages.findIndex(p => p.id === id);
        return i < 0 ? -1 : Math.floor(i / 2);
    }
    function markSpread() {
        for (const p of [pageAt(spread * 2), pageAt(spread * 2 + 1)])
            if (p)
                Diary.markRead(p.id);
    }

    // ---- the show: gone → in (sliding in) → unlock (the key) → opening → open → closing ----
    property string phase: "gone"
    property real shade: 0          // the backdrop
    property real slide: 1          // 1: off screen at its side … 0: in place
    property real keyTurn: 0        // the key in the clasp: 0 … 1 (a quarter turn)
    property real clasp: 1          // the strap over the edge: 1 shut … 0 gone
    property real swing: 0          // the cover: 0 shut … 1 open (flat beside the page)

    // her steps: a sound once
    Connections {
        target: Diary
        function onReturningSoonChanged() {
            if (Diary.returningSoon && Shell.diaryOpen)
                Sounds.play("rocks");
        }
    }
    Connections {
        target: Shell
        function onDiaryOpenChanged() {
            if (Shell.diaryOpen)
                win.start();
            else
                win.finish();
        }
    }
    Component.onCompleted: if (Shell.diaryOpen)
        start()
    function start() {
        closeAnim.stop();
        // where to open: the page asked for, the first unread one, else the last spread read
        let at = Diary.startAt ? spreadOf(Diary.startAt) : -1;
        if (at < 0) {
            const firstNew = pages.findIndex(p => Diary.isOpen(p.id) && !Diary.readMarks[p.id]);
            at = firstNew >= 0 ? Math.floor(firstNew / 2) : 0;
        }
        spread = Math.max(0, Math.min(spreads - 1, at));
        phase = "in";
        if (still) {
            shade = 1;
            slide = 0;
            keyTurn = 1;
            clasp = 0;
            swing = 1;
            phase = "open";
            markSpread();
            return;
        }
        shade = 0;
        slide = 1;
        keyTurn = 0;
        clasp = 1;
        swing = 0;
        openAnim.restart();
        Sounds.play(Theme.hell ? "circleSoft" : "harp");
    }
    function finish() {
        openAnim.stop();
        if (phase === "gone")
            return;
        if (still) {
            phase = "gone";
            return;
        }
        phase = "closing";
        closeAnim.restart();
    }
    function close() {
        Shell.diaryOpen = false;
    }

    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            NumberAnimation {
                target: win
                property: "shade"
                to: 1
                duration: win.ms(260)
            }
            NumberAnimation {
                target: win
                property: "slide"
                to: 0
                duration: win.ms(520)
                easing.type: Easing.OutCubic
            }
        }
        ScriptAction {
            script: win.phase = "unlock"
        }
        NumberAnimation {
            target: win
            property: "keyTurn"
            to: 1
            duration: win.ms(380)
            easing.type: Easing.InOutBack
        }
        NumberAnimation {
            target: win
            property: "clasp"
            to: 0
            duration: win.ms(200)
        }
        ScriptAction {
            script: win.phase = "opening"
        }
        NumberAnimation {
            target: win
            property: "swing"
            to: 1
            duration: win.ms(950)
            easing.type: Easing.InOutCubic
        }
        ScriptAction {
            script: {
                win.phase = "open";
                win.markSpread();
            }
        }
    }
    SequentialAnimation {
        id: closeAnim
        ScriptAction {
            script: turnAnim.complete()
        }
        NumberAnimation {
            target: win
            property: "swing"
            to: 0
            duration: win.ms(520)
            easing.type: Easing.InCubic
        }
        ParallelAnimation {
            NumberAnimation {
                target: win
                property: "slide"
                to: 1
                duration: win.ms(320)
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: win
                property: "shade"
                to: 0
                duration: win.ms(320)
            }
        }
        ScriptAction {
            script: win.phase = "gone"
        }
    }

    // ---- turning a page: a leaf swings over the spine ----
    property int turnTo: -1
    property bool turnBack: false
    property real leaf: 0           // 0 … 1 while it turns
    function go(step) {
        if (phase !== "open" || turnAnim.running)
            return;
        const to = spread + step;
        if (to < 0 || to >= spreads)
            return;
        turnBack = step < 0;
        turnTo = to;
        if (still) {
            spread = to;
            markSpread();
            return;
        }
        leaf = 0;
        turnAnim.restart();
    }
    SequentialAnimation {
        id: turnAnim
        NumberAnimation {
            target: win
            property: "leaf"
            from: 0
            to: 1
            duration: win.ms(620)
            easing.type: Easing.InOutQuad
        }
        ScriptAction {
            script: {
                win.spread = win.turnTo;
                win.turnTo = -1;
                win.leaf = 0;
                win.markSpread();
            }
        }
    }
    // the spread under the leaf while it turns: the new one on the side it uncovers
    readonly property int leftIndex: (turnTo >= 0 && turnBack ? turnTo : spread) * 2
    readonly property int rightIndex: (turnTo >= 0 && !turnBack ? turnTo : spread) * 2 + 1

    // ---- input ----
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: win.close()
    }
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape)
                win.close();
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_PageDown || e.key === Qt.Key_Space)
                win.go(1);
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_PageUp || e.key === Qt.Key_Backspace)
                win.go(-1);
            else if (e.key === Qt.Key_Home)
                win.go(-win.spread);
            else if (e.key === Qt.Key_End)
                win.go(win.spreads - 1 - win.spread);
            else
                return;
            e.accepted = true;
        }
    }

    // ---- the book ----
    // the spine's x when open: the middle of the screen; shut, the book (one page wide) is centred
    Item {
        id: book
        readonly property real spineOpen: win.width / 2
        readonly property real spineShut: win.fromRight ? win.width / 2 - win.pageW / 2 : win.width / 2 + win.pageW / 2
        readonly property real spineIn: spineShut + (spineOpen - spineShut) * win.swing
        // off screen at its side while it slides in
        readonly property real offX: (win.fromRight ? 1 : -1) * (win.width / 2 + win.pageW * 1.2) * win.slide
        x: spineIn + offX
        y: (win.height - win.pageH) / 2
        width: 0
        height: win.pageH
        rotation: (win.fromRight ? 6 : -6) * win.slide

        // a click on the book itself does not close it
        MouseArea {
            x: -win.pageW - win.coverPad
            y: -win.coverPad
            width: win.pageW * 2 + win.coverPad * 2
            height: win.pageH + win.coverPad * 2
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        // the boards: the back one under the pages, the front one beside them once it has swung over
        Board {
            visible: win.fromRight || win.swing >= 1
            x: -win.coverPad
            pad: win.coverPad
            pageW: win.pageW
            pageH: win.pageH
        }
        Board {
            visible: !win.fromRight || win.swing >= 1
            x: -win.pageW - win.coverPad
            pad: win.coverPad
            pageW: win.pageW
            pageH: win.pageH
        }
        // a shadow on the desk
        Rectangle {
            z: -1
            x: (win.fromRight ? -win.pageW * win.swing : -win.pageW) - win.coverPad + win.pageH * 0.02
            y: win.pageH * 0.03
            width: win.pageW * (1 + win.swing) + win.coverPad * 2
            height: win.pageH + win.coverPad * 2
            radius: win.coverPad
            color: Qt.alpha("#000000", 0.35 * win.shade)
        }

        // the page under the cover (and the one beside it once open)
        DiaryPage {
            id: staticRight
            visible: win.fromRight || win.swing >= 1
            x: 0
            width: win.pageW
            height: win.pageH
            page: win.pageAt(win.rightIndex)
            number: page ? win.rightIndex + 1 : 0
        }
        DiaryPage {
            id: staticLeft
            visible: !win.fromRight || win.swing >= 1
            x: -win.pageW
            width: win.pageW
            height: win.pageH
            leftSide: true
            page: win.pageAt(win.leftIndex)
            number: page ? win.leftIndex + 1 : 0
        }
        // the spine's crease
        Rectangle {
            visible: win.swing > 0
            x: -width / 2
            width: win.pageW * 0.06
            height: win.pageH
            opacity: win.swing
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Qt.alpha("#3a2410", 0.35)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        // ---- the leaf that turns ----
        Flipable {
            id: leafItem
            visible: win.turnTo >= 0
            x: win.turnBack ? -win.pageW : 0
            width: win.pageW
            height: win.pageH
            front: DiaryPage {
                width: win.pageW
                height: win.pageH
                leftSide: win.turnBack
                // what the leaf showed before it turned
                page: win.turnBack ? win.pageAt(win.spread * 2) : win.pageAt(win.spread * 2 + 1)
                number: page ? (win.turnBack ? win.spread * 2 : win.spread * 2 + 1) + 1 : 0
            }
            back: DiaryPage {
                width: win.pageW
                height: win.pageH
                leftSide: !win.turnBack
                // what it shows once over: the new spread's page on the other side
                page: win.turnTo < 0 ? null : win.turnBack ? win.pageAt(win.turnTo * 2 + 1) : win.pageAt(win.turnTo * 2)
                number: page ? (win.turnBack ? win.turnTo * 2 + 1 : win.turnTo * 2) + 1 : 0
            }
            transform: Rotation {
                origin.x: win.turnBack ? win.pageW : 0
                origin.y: win.pageH / 2
                // a softer perspective than Qt's default: the near edge stays near the book
                distanceToPlane: win.pageW * 12
                axis {
                    x: 0
                    y: 1
                    z: 0
                }
                angle: (win.turnBack ? 180 : -180) * win.leaf
            }
        }

        // ---- the cover: leather, gold, the pentagram; its inside is the first page ----
        Flipable {
            id: cover
            visible: win.swing < 1
            x: win.fromRight ? 0 : -win.pageW
            width: win.pageW
            height: win.pageH
            front: Item {
                width: win.pageW
                height: win.pageH
                Rectangle {
                    x: -win.coverPad
                    y: -win.coverPad
                    width: parent.width + win.coverPad * 2
                    height: parent.height + win.coverPad * 2
                    radius: win.coverPad * 0.8
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#3a0d16"
                        }
                        GradientStop {
                            position: 1
                            color: "#16050a"
                        }
                    }
                    border.width: Math.max(1, win.coverPad * 0.18)
                    border.color: "#6d1a26"
                }
                // the gold frame, pressed in
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: win.pageW * 0.06
                    color: "transparent"
                    border.width: Math.max(1, win.pageW * 0.006)
                    border.color: "#c9a04a"
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: win.pageW * 0.018
                        color: "transparent"
                        border.width: Math.max(1, win.pageW * 0.003)
                        border.color: Qt.alpha("#c9a04a", 0.6)
                    }
                }
                // the corners: little gold pentagrams
                Repeater {
                    model: 4
                    Pentagram {
                        required property int index
                        width: win.pageW * 0.09
                        height: width
                        x: index % 2 ? win.pageW - width - win.pageW * 0.035 : win.pageW * 0.035
                        y: index < 2 ? win.pageW * 0.035 : win.pageH - height - win.pageW * 0.035
                        color: "#c9a04a"
                        glow: false
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.pageH * 0.12
                    width: parent.width * 0.8
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: Diary.title()
                    color: "#e7c15e"
                    font.family: Theme.fontHell
                    font.pixelSize: win.pageH * 0.062
                    style: Text.Raised
                    styleColor: "#2a0508"
                }
                Pentagram {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: win.pageH * 0.05
                    width: win.pageW * 0.62
                    height: width
                    color: "#e2b955"
                    glowColor: "#ff5a3c"
                    line: Math.max(2, width / 46)
                    animate: !win.still && win.phase !== "gone"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.pageH * 0.86
                    text: Diary.subtitle()
                    color: Qt.alpha("#e7c15e", 0.75)
                    font.family: Theme.fontScript
                    font.pixelSize: win.pageH * 0.034
                }
                // the clasp on the opening edge, and the key turning in it
                Item {
                    id: claspItem
                    opacity: win.clasp
                    width: win.pageW * 0.16
                    height: win.pageH * 0.14
                    x: win.fromRight ? win.pageW - width * 0.55 : -width * 0.45
                    y: (win.pageH - height) / 2
                    Rectangle {
                        anchors.fill: parent
                        radius: width * 0.18
                        color: "#2a0a10"
                        border.width: Math.max(1, width * 0.06)
                        border.color: "#c9a04a"
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.42
                        height: width
                        radius: width / 2
                        color: "#c9a04a"
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.22
                            height: parent.height * 0.55
                            radius: width / 2
                            color: "#120306"
                        }
                    }
                    PxIcon {
                        id: keyPic
                        readonly property var tex: Diary.thing ? Diary.thing.texture : null
                        visible: !!tex && win.phase !== "in"
                        anchors.centerIn: parent
                        bitmap: tex ? tex.rows : null
                        palette: tex ? tex.palette : ({})
                        pixel: Math.max(1, Math.round(win.pageH * 0.006))
                        rotation: -90 * (1 - win.keyTurn) + (win.fromRight ? 0 : 180)
                        scale: 0.8 + 0.2 * win.keyTurn
                    }
                }
            }
            back: Item {
                width: win.pageW
                height: win.pageH
                Board {
                    x: -win.coverPad
                    pad: win.coverPad
                    pageW: win.pageW
                    pageH: win.pageH
                }
                DiaryPage {
                    width: win.pageW
                    height: win.pageH
                    leftSide: win.fromRight
                    page: win.fromRight ? win.pageAt(win.leftIndex) : win.pageAt(win.rightIndex)
                    number: page ? (win.fromRight ? win.leftIndex : win.rightIndex) + 1 : 0
                }
            }
            transform: Rotation {
                origin.x: win.fromRight ? 0 : win.pageW
                origin.y: win.pageH / 2
                // a softer perspective than Qt's default: the near edge stays near the book
                distanceToPlane: win.pageW * 12
                axis {
                    x: 0
                    y: 1
                    z: 0
                }
                angle: (win.fromRight ? -180 : 180) * win.swing
            }
        }

        // ---- the ways to turn: ‹ › under the pages, the count, a ribbon with what's new ----
        Row {
            visible: win.phase === "open"
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.pageH + win.coverPad * 2.2
            spacing: win.pageW * 0.05
            PxButton {
                hell: Theme.hell
                compact: true
                icon: "arrowLeft"
                enabled: win.spread > 0
                onClicked: win.go(-1)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (win.spread + 1) + " / " + win.spreads + (Diary.unread > 0 ? "   ·   " + I18n.t("новых: ", "new: ") + Diary.unread : "")
                color: "#f3e3bd"
                font.family: Theme.fontScript
                font.pixelSize: win.pageH * 0.034
                style: Text.Outline
                styleColor: "#1a0508"
            }
            PxButton {
                hell: Theme.hell
                compact: true
                icon: "arrowRight"
                enabled: win.spread < win.spreads - 1
                onClicked: win.go(1)
            }
            PxButton {
                hell: Theme.hell
                compact: true
                icon: "close"
                text: I18n.t("Закрыть", "Close")
                onClicked: win.close()
            }
        }
        // ---- is she here? above the book: away (read while you can), her steps, her eyes ----
        Text {
            id: watchNote
            visible: win.phase === "open" && Story.enabled && text !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: -win.coverPad * 2 - height
            readonly property string stepsLine: {
                const l = ((Diary.doc.lines || {}).steps || []);
                return l.length ? Story.render(l[0]) : I18n.t("Шаги… она возвращается", "Steps… she's coming back");
            }
            text: Diary.returningSoon ? watchNote.stepsLine : Diary.watching ? I18n.t("Она смотрит.", "She is watching.") : Angel.away ? I18n.t("Её нет. Читай, пока можно.", "She's away. Read while you can.") : ""
            color: Diary.returningSoon || Diary.watching ? "#ff6b6b" : "#f3e3bd"
            font.family: Theme.fontScript
            font.pixelSize: win.pageH * 0.045
            style: Text.Outline
            styleColor: "#1a0508"
            onTextChanged: opacity = 1
            SequentialAnimation on opacity {
                running: Diary.returningSoon && !win.still
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.35
                    duration: 380
                }
                NumberAnimation {
                    to: 1
                    duration: 380
                }
            }
        }
        // the page corners turn the page too
        MouseArea {
            visible: win.phase === "open"
            x: win.pageW * 0.8
            y: win.pageH * 0.82
            width: win.pageW * 0.2
            height: win.pageH * 0.18
            cursorShape: Qt.PointingHandCursor
            onClicked: win.go(1)
        }
        MouseArea {
            visible: win.phase === "open"
            x: -win.pageW
            y: win.pageH * 0.82
            width: win.pageW * 0.2
            height: win.pageH * 0.18
            cursorShape: Qt.PointingHandCursor
            onClicked: win.go(-1)
        }
    }

    RightClickGuard {}
}
