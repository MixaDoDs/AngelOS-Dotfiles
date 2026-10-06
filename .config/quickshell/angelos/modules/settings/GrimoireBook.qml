pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Settings as a grimoire while the demon rules (Y2K → Angel or demon → Settings in hell):
// a leather-bound book open on its spread — the contents on the left page (with the search),
// the settings page on the right, re-inked on parchment by shaders/grimoire.frag and written
// by hand (Theme.fontScript, set for this window by SettingsView). The spine sits in the
// middle: two equal pages. Changing
// the section turns a page: forwards when it comes later in the contents, backwards when
// earlier. SettingsView puts its search field into `fieldSlot`, what it finds into
// `resultsSlot` and its page into `pageSlot`.
// Any other settings view (`spread: false`) is written whole on one parchment page inside
// the same cover (`viewSlot`, re-inked by SettingsView): the grimoire is hell's dress for
// whichever layout the user picked, the spread is the sidebar's.
Item {
    id: book

    required property var view              // SettingsView
    property bool spread: true              // the sidebar as a two-page spread; else one page
    readonly property alias searchSlot: searchSlot
    readonly property alias fieldSlot: fieldSlot
    readonly property alias resultsSlot: resultsSlot
    readonly property alias pageSlot: pageSlot
    readonly property alias viewSlot: viewSlot

    // the binding takes the circle's colours (HellLook); the pages stay parchment and ink, to be read
    readonly property color leather: Theme.mix(Theme.hellFace, Theme.hellBlood, 0.45)
    readonly property color leatherDark: Theme.hellBody
    readonly property color gold: Theme.hellGold
    readonly property color paper: "#ecdcb0"
    readonly property color paperShade: "#cdb682"
    readonly property color ink: "#3b2415"
    readonly property color redInk: "#8a1020"

    function roman(n) {
        const r = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let s = "";
        for (const [v, c] of r)
            while (n >= v) {
                s += c;
                n -= v;
            }
        return s || "—";
    }
    readonly property int pageIndex: view.allPages.findIndex(p => p.id === book.view.settingsNav.settingsPage)

    // ---- the page turn ----
    property real turn: 1                   // 0 → 1 while a page turns
    property bool backwards: false
    property int lastIndex: pageIndex
    onPageIndexChanged: {
        if (visible && spread && book.view.settingsNav.settingsOpen && pageIndex !== lastIndex) {
            backwards = pageIndex < lastIndex;
            turnAnim.restart();
        }
        lastIndex = pageIndex;
    }
    NumberAnimation {
        id: turnAnim
        target: book
        property: "turn"
        from: 0
        to: 1
        duration: Motion.ms(460)
        easing.type: Easing.InOutQuad
    }

    // ---- the cover ----
    Rectangle {
        id: cover
        anchors.fill: parent
        anchors.rightMargin: Theme.u * 2
        anchors.bottomMargin: Theme.u * 2
        radius: Theme.u * 4
        color: book.leather
        border.width: Math.max(2, Theme.u)
        border.color: book.leatherDark
        // leather grain: a darker lower half
        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.border.width
            radius: parent.radius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha("#ffffff", 0.05)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha("#000000", 0.25)
                }
            }
        }
        // stitching
        Canvas {
            anchors.fill: parent
            anchors.margins: Theme.u * 3
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "#8a5a2a";
                const d = Math.max(3, Theme.u * 3), g = Math.max(2, Theme.u * 2), t = Math.max(1, Theme.u / 2);
                for (let x = 0; x < width; x += d + g) {
                    ctx.fillRect(x, 0, Math.min(d, width - x), t);
                    ctx.fillRect(x, height - t, Math.min(d, width - x), t);
                }
                for (let y = 0; y < height; y += d + g) {
                    ctx.fillRect(0, y, t, Math.min(d, height - y));
                    ctx.fillRect(width - t, y, t, Math.min(d, height - y));
                }
            }
        }
        // gold corners
        Repeater {
            model: 4
            PxIcon {
                required property int index
                bitmap: ["yyyyy", "y#yy.", "yy#..", "yy...", "y...."]
                pixel: Math.max(1, Theme.u)
                ink: "#7a4a12"
                fill3: book.gold
                rotation: index * 90
                x: index === 1 || index === 2 ? cover.width - width - Theme.u * 2 : Theme.u * 2
                y: index >= 2 ? cover.height - height - Theme.u * 2 : Theme.u * 2
            }
        }
    }

    // ---- the title on the cover: drag, double-click maximizes, the clasp closes ----
    Item {
        id: head
        x: cover.x
        y: cover.y
        width: cover.width
        height: Theme.u * 17
        // the cover in gothic letters (Jacquard 24, Latin only like the title)
        PxText {
            anchors.centerIn: parent
            kind: "title"
            font.family: Theme.fontHell
            font.pixelSize: Theme.hellPx(1)
            renderType: Text.NativeRendering
            color: book.gold
            style: Text.Raised
            styleColor: book.leatherDark
            text: "✠ Liber Angelorum ✠"
        }
        MouseArea {
            anchors.fill: parent
            onPressed: if (book.view.hostWindow)
                book.view.hostWindow.startSystemMove()
            onDoubleClicked: if (book.view.hostWindow)
                book.view.hostWindow.maximized = !book.view.hostWindow.maximized
        }
        Rectangle {
            id: clasp
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 8
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.u * 11
            height: width
            radius: width / 2
            color: claspMouse.containsMouse ? Theme.mix(book.gold, Theme.hellText, 0.35) : book.gold
            border.width: Math.max(1, Theme.u / 2)
            border.color: "#7a4a12"
            PxIcon {
                anchors.centerIn: parent
                name: "close"
                pixel: Math.max(1, Math.round(Theme.u / 2))
                ink: book.leatherDark
                fill: book.leatherDark
            }
            MouseArea {
                id: claspMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: book.view.settingsNav.settingsOpen = false
            }
        }
    }

    // ---- the spread ----
    Item {
        id: spread
        x: cover.x + Theme.u * 7
        y: head.y + head.height
        width: cover.width - Theme.u * 14
        height: cover.height - head.height - Theme.u * 7
        // two equal pages, the spine in the middle
        readonly property real leftW: Math.round(width / 2)

        // the pages' edges under the paper
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.u
            color: "#bfa76f"
            radius: Theme.u
        }

        Rectangle {
            id: leftPage
            visible: book.spread
            width: spread.leftW
            height: spread.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: book.paper
                }
                GradientStop {
                    position: 0.85
                    color: book.paper
                }
                GradientStop {
                    position: 1
                    color: book.paperShade
                }
            }
        }
        Rectangle {
            id: rightPage
            visible: book.spread
            x: spread.leftW
            width: spread.width - spread.leftW
            height: spread.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: book.paperShade
                }
                GradientStop {
                    position: 0.08
                    color: book.paper
                }
                GradientStop {
                    position: 1
                    color: book.paper
                }
            }
        }
        // old stains
        Repeater {
            model: [[0.12, 0.8, 26], [0.55, 0.15, 34], [0.86, 0.7, 22], [0.3, 0.35, 16]]
            Rectangle {
                required property var modelData
                x: spread.width * modelData[0]
                y: spread.height * modelData[1]
                width: Theme.u * modelData[2]
                height: width * 0.8
                radius: width / 2
                color: Qt.alpha("#8a6a2a", 0.08)
            }
        }
        // one page, edge to edge (every other view)
        Rectangle {
            id: wholePage
            visible: !book.spread
            anchors.fill: parent
            color: book.paper
            Item {
                id: viewSlot
                anchors.fill: parent
                anchors.margins: Theme.u * 6
            }
        }
        // the spine
        Rectangle {
            visible: book.spread
            x: spread.leftW - width / 2
            width: Theme.u * 5
            height: spread.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Qt.alpha("#3b2415", 0)
                }
                GradientStop {
                    position: 0.5
                    color: Qt.alpha("#3b2415", 0.45)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha("#3b2415", 0)
                }
            }
        }

        // ---- left page: the contents ----
        PxText {
            id: tocTitle
            visible: book.spread
            x: Theme.u * 10
            y: Theme.u * 5
            width: spread.leftW - Theme.u * 20
            horizontalAlignment: Text.AlignHCenter
            kind: "title"
            color: book.redInk
            text: "❦ " + I18n.t("Оглавление", "Contents") + " ❦"
        }
        Item {
            id: searchSlot
            visible: book.spread
            x: Theme.u * 10
            y: tocTitle.y + tocTitle.height + Theme.u * 3
            width: spread.leftW - Theme.u * 20
            height: spread.height - y - seals.height - Theme.u * 6
            Item {
                id: fieldSlot
                width: parent.width
                height: book.view.searchFieldHeight
            }
            Item {
                id: resultsSlot
                width: parent.width
                y: fieldSlot.height + Theme.u * 8
                height: parent.height - y
            }
        }
        Flickable {
            id: toc
            visible: book.spread && book.view.query.trim() === ""
            x: searchSlot.x
            y: searchSlot.y + Theme.scriptPx(Theme.sizeBody) + Theme.u * 16
            width: searchSlot.width
            height: seals.y - y - Theme.u * 4
            contentHeight: tocCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            // a thin ink line shows where in the contents you are
            Rectangle {
                parent: toc
                visible: toc.contentHeight > toc.height
                x: toc.width - width
                y: toc.visibleArea.yPosition * toc.height
                width: Math.max(2, Theme.u)
                height: toc.visibleArea.heightRatio * toc.height
                color: Qt.alpha(book.redInk, 0.5)
            }
            Column {
                id: tocCol
                width: toc.width - Theme.u * 4
                spacing: Theme.u
                // the title page: the home tiles
                Rectangle {
                    width: tocCol.width
                    height: Math.max(Theme.u * 12, Theme.scriptPx(Theme.sizeBody) + Theme.u * 3)
                    color: homeMouse.containsMouse ? Qt.alpha(book.redInk, 0.08) : "transparent"
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.u * 2
                        color: book.view.settingsNav.settingsPage === "home" ? book.redInk : book.ink
                        font.bold: book.view.settingsNav.settingsPage === "home"
                        text: (book.view.settingsNav.settingsPage === "home" ? "☞ " : "") + I18n.t("Титульный лист", "Title page")
                    }
                    MouseArea {
                        id: homeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: book.view.settingsNav.settingsPage = "home"
                    }
                }
                Repeater {
                    model: book.view.visibleGroups
                    Column {
                        id: chapter
                        required property var modelData
                        required property int index
                        width: tocCol.width
                        spacing: 0
                        PxText {
                            topPadding: Theme.u * 4
                            bottomPadding: Theme.u
                            color: book.redInk
                            font.bold: true
                            text: book.roman(chapter.index + 1) + ". " + chapter.modelData.title
                        }
                        Repeater {
                            model: chapter.modelData.pages
                            Rectangle {
                                id: line
                                required property var modelData
                                readonly property bool sel: book.view.settingsNav.settingsPage === modelData.id
                                readonly property int number: book.view.allPages.findIndex(p => p.id === modelData.id) + 1
                                width: chapter.width
                                height: Math.max(Theme.u * 12, lineName.implicitHeight + Theme.u * 2)
                                color: lineMouse.containsMouse ? Qt.alpha(book.redInk, 0.08) : "transparent"
                                PxText {
                                    id: lineName
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Theme.u * 4
                                    width: Math.min(implicitWidth, line.width - lineNo.width - Theme.u * 12)
                                    elide: Text.ElideRight
                                    color: line.sel ? book.redInk : book.ink
                                    font.bold: line.sel
                                    text: (line.sel ? "☞ " : "") + line.modelData.label
                                }
                                // the dotted leader to the page number
                                PxText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: lineName.right
                                    anchors.right: lineNo.left
                                    anchors.leftMargin: Theme.u
                                    anchors.rightMargin: Theme.u
                                    clip: true
                                    kind: "tiny"
                                    color: Qt.alpha(book.ink, 0.5)
                                    text: ". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ."
                                }
                                PxText {
                                    id: lineNo
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.u * 2
                                    kind: "tiny"
                                    color: line.sel ? book.redInk : book.ink
                                    text: String(line.number)
                                }
                                MouseArea {
                                    id: lineMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: book.view.settingsNav.settingsPage = line.modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }
        // wax seals at the foot of the left page: undo, the usual window for now
        Row {
            id: seals
            visible: book.spread
            x: Theme.u * 10
            y: spread.height - height - Theme.u * 5
            spacing: Theme.u * 5
            Repeater {
                model: [
                    {
                        "icon": "refresh",
                        "label": I18n.t("Отменить", "Undo"),
                        "show": Config.canUndo,
                        "act": () => Config.undo()
                    },
                    {
                        "icon": "fire",
                        "label": I18n.t("Закрыть книгу", "Close the book"),
                        "show": true,
                        "act": () => book.view.settingsNav.settingsOpen = false
                    }
                ]
                Row {
                    id: seal
                    required property var modelData
                    visible: modelData.show
                    spacing: Theme.u * 2
                    Rectangle {
                        width: Theme.u * 13
                        height: width
                        radius: width / 2
                        color: sealMouse.containsMouse ? "#b01828" : book.redInk
                        border.width: Math.max(1, Theme.u / 2)
                        border.color: "#4a0810"
                        PxIcon {
                            anchors.centerIn: parent
                            name: seal.modelData.icon
                            pixel: Math.max(1, Math.round(Theme.u / 2))
                            ink: "#ffd9c2"
                            fill: "#ffd9c2"
                            fill3: "#ffd9c2"
                            bad: "#ffd9c2"
                            light: "#ffd9c2"
                        }
                        MouseArea {
                            id: sealMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: seal.modelData.act()
                        }
                    }
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "tiny"
                        color: book.ink
                        text: seal.modelData.label
                    }
                }
            }
        }

        // ---- right page: the settings page ----
        Item {
            id: pageSlot
            x: rightPage.x + Theme.u * 12
            y: Theme.u * 6
            width: rightPage.width - Theme.u * 22
            height: spread.height - Theme.u * 22
        }
        // the ribbon bookmark, down the outer edge of the right page (clear of the heading)
        Rectangle {
            visible: book.spread
            x: rightPage.x + rightPage.width - Theme.u * 9
            y: -Theme.u * 2
            width: Theme.u * 5
            height: Theme.u * 26
            color: "#9a1020"
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.u * 3
                height: width
                rotation: 45
                anchors.bottomMargin: -height / 2
                color: book.paper
            }
        }
        // folio numbers
        PxText {
            visible: book.spread
            anchors.horizontalCenter: rightPage.horizontalCenter
            y: spread.height - height - Theme.u * 4
            kind: "tiny"
            color: book.ink
            text: "— " + book.roman(Math.max(1, book.pageIndex + 1)) + " —"
        }

        // ---- the turning sheet ----
        // forwards: the right page lifts from its edge, folds onto the spine, lands on the
        // left page and settles; backwards the other way round
        Item {
            id: sheetRight
            visible: turnAnim.running && (book.backwards ? book.turn > 0.5 : book.turn < 0.5)
            x: rightPage.x
            width: rightPage.width
            height: spread.height
            readonly property real fold: book.backwards ? (book.turn - 0.5) * 2 : 1 - book.turn * 2
            opacity: book.backwards ? Math.min(1, (1 - book.turn) * 5) : 1
            transform: Scale {
                origin.x: 0
                xScale: Math.max(0.001, sheetRight.fold)
            }
            Rectangle {
                anchors.fill: parent
                color: book.paper
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Qt.alpha("#3b2415", 0.35 * (1 - sheetRight.fold))
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha("#3b2415", 0.05)
                        }
                    }
                }
                Column {
                    x: Theme.u * 10
                    y: Theme.u * 12
                    spacing: Theme.u * 5
                    Repeater {
                        model: 9
                        Rectangle {
                            required property int index
                            width: sheetRight.width * (0.55 + (index * 37 % 30) / 100)
                            height: Theme.u
                            color: Qt.alpha(book.ink, 0.18)
                        }
                    }
                }
            }
        }
        Item {
            id: sheetLeft
            visible: turnAnim.running && (book.backwards ? book.turn < 0.5 : book.turn >= 0.5)
            width: spread.leftW
            height: spread.height
            readonly property real fold: book.backwards ? 1 - book.turn * 2 : (book.turn - 0.5) * 2
            opacity: book.backwards ? 1 : Math.min(1, (1 - book.turn) * 5)
            transform: Scale {
                origin.x: spread.leftW
                xScale: Math.max(0.001, sheetLeft.fold)
            }
            Rectangle {
                anchors.fill: parent
                color: book.paper
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Qt.alpha("#3b2415", 0.05)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha("#3b2415", 0.35 * (1 - sheetLeft.fold))
                        }
                    }
                }
            }
        }
    }

    // resize grip
    PxIcon {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        name: "sparkle"
        fill: book.gold
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.u * 3
            cursorShape: Qt.SizeFDiagCursor
            onPressed: if (book.view.hostWindow)
                book.view.hostWindow.startSystemResize(Edges.Bottom | Edges.Right)
        }
    }
}
