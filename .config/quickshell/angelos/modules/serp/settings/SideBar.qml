import QtQuick
import qs.services
import qs.modules.serp
import "Index.js" as Index

// serp-skin settings: Serpantinum's GuideSidebar — the title and a search button, then the pages
// (Тема has sub-rows for its groups) under ONE accent plate that slides to the current row.
// While searching the list gives way to the results: ↑/↓ choose, Enter goes, Esc gives up.
Rectangle {
    id: side
    property string page: ""
    signal jump(string page, string key)
    signal searchClosed

    property string subSel: ""           // a sub-row picked last ("theme/colors")
    readonly property string current: subSel.indexOf(page + "/") === 0 ? subSel : page
    property bool searching: false
    readonly property var results: Index.search(input.text)
    property int pick: 0

    readonly property var rows: [
        {
            "id": "welcome",
            "icon": "angel",
            "label": "Добро пожаловать"
        },
        {
            "sep": true
        },
        {
            "id": "theme",
            "icon": "palette",
            "label": "Тема"
        },
        {
            "id": "theme/look",
            "icon": "type",
            "label": "Оформление",
            "sub": true
        },
        {
            "id": "theme/colors",
            "icon": "sparkles",
            "label": "Цвета",
            "sub": true
        },
        {
            "id": "bar",
            "icon": "layout-dashboard",
            "label": "Панель"
        },
        {
            "id": "dock",
            "icon": "app-window",
            "label": "Док"
        },
        {
            "id": "widgets",
            "icon": "layers",
            "label": "Виджеты"
        },
        {
            "sep": true
        },
        {
            "id": "about",
            "icon": "info",
            "label": "О скине"
        }
    ]

    function startSearch(ch) {
        searching = true;
        input.text = ch || "";
        input.focusField();
    }
    function stopSearch() {
        searching = false;
        input.text = "";
        searchClosed();
    }
    function go(r) {
        if (!r)
            return;
        subSel = "";
        jump(r.page, r.key);
    }
    onResultsChanged: pick = 0

    color: Qt.alpha(Serp.surface0, 0.4)
    radius: Serp.radius

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: Serp.px(12)
        spacing: Serp.px(8)

        // ---- header ----
        Item {
            width: parent.width
            height: Serp.px(34)
            SText {
                x: Serp.px(6)
                anchors.verticalCenter: parent.verticalCenter
                text: "Настройки"
                size: Serp.px(15)
                bold: true
            }
            Rectangle {
                anchors.right: parent.right
                width: Serp.px(34)
                height: width
                radius: Serp.radiusSmall
                color: side.searching ? Qt.alpha(Serp.mauve, 0.16) : sma.containsMouse ? Serp.surface1 : Qt.alpha(Serp.surface0, 0.7)
                Behavior on color {
                    ColorAnimation {
                        duration: Serp.quick
                    }
                }
                SIcon {
                    anchors.centerIn: parent
                    name: side.searching ? "x" : "search"
                    size: Serp.px(16)
                    color: side.searching ? Serp.mauve : Serp.subtext1
                }
                MouseArea {
                    id: sma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: side.searching ? side.stopSearch() : side.startSearch("")
                }
            }
        }

        SInput {
            id: input
            width: parent.width
            visible: side.searching
            placeholder: "Что ищем?"
            onEscaped: side.stopSearch()
            onUp: side.pick = Math.max(0, side.pick - 1)
            onDown: side.pick = Math.min(side.results.length - 1, side.pick + 1)
            onAccepted: side.go(side.results[side.pick])
        }

        // ---- the search's results ----
        Column {
            width: parent.width
            visible: side.searching
            spacing: Serp.px(2)
            Repeater {
                model: side.results
                delegate: Rectangle {
                    id: res
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: Serp.px(44)
                    radius: Serp.radiusSmall
                    color: index === side.pick ? Qt.alpha(Serp.mauve, 0.16) : rma.containsMouse ? Qt.alpha(Serp.text, 0.06) : "transparent"
                    Column {
                        x: Serp.px(12)
                        width: parent.width - Serp.px(24)
                        anchors.verticalCenter: parent.verticalCenter
                        SText {
                            width: parent.width
                            text: res.modelData.title
                            size: Serp.px(13)
                            color: res.index === side.pick ? Serp.mauve : Serp.text
                        }
                        SText {
                            width: parent.width
                            text: res.modelData.where
                            size: Serp.px(11)
                            color: Serp.subtext0
                        }
                    }
                    MouseArea {
                        id: rma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: side.pick = res.index
                        onClicked: side.go(res.modelData)
                    }
                }
            }
            SText {
                visible: input.text.trim() !== "" && side.results.length === 0
                x: Serp.px(12)
                text: "Ничего не нашлось"
                size: Serp.px(12)
                color: Serp.subtext0
            }
        }

        // ---- the pages ----
        Item {
            width: parent.width
            height: nav.height
            visible: !side.searching
            Rectangle {
                id: plate
                readonly property Item cur: {
                    if (rep.count === 0)
                        return null;
                    for (let i = 0; i < side.rows.length; i++)
                        if (side.rows[i].id === side.current)
                            return rep.itemAt(i);
                    return null;
                }
                visible: cur !== null
                width: parent.width
                y: cur ? cur.y : 0
                height: cur ? cur.height : 0
                radius: Serp.radiusSmall
                color: Qt.alpha(Serp.mauve, 0.16)
                Behavior on y {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }
            }
            Column {
                id: nav
                width: parent.width
                spacing: Serp.px(2)
                Repeater {
                    id: rep
                    model: side.rows
                    delegate: Item {
                        id: nr
                        required property var modelData
                        readonly property bool sep: !!modelData.sep
                        readonly property bool sub: !!modelData.sub
                        readonly property bool active: !sep && modelData.id === side.current
                        width: parent.width
                        height: sep ? Serp.px(9) : sub ? Serp.px(36) : Serp.px(40)
                        Rectangle {
                            visible: nr.sep
                            anchors.verticalCenter: parent.verticalCenter
                            x: Serp.px(8)
                            width: parent.width - Serp.px(16)
                            height: 1
                            color: Qt.alpha(Serp.surface2, 0.4)
                        }
                        Rectangle {
                            visible: !nr.sep
                            anchors.fill: parent
                            radius: Serp.radiusSmall
                            color: nma.containsMouse && !nr.active ? Qt.alpha(Serp.text, 0.06) : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: Serp.quick
                                }
                            }
                        }
                        Item {
                            id: ibox
                            visible: !nr.sep
                            x: Serp.px(14) + (nr.sub ? Serp.px(20) : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Serp.px(24)
                            height: width
                            SIcon {
                                anchors.centerIn: parent
                                name: nr.modelData.icon || "circle-help"
                                size: nr.sub ? Serp.px(16) : Serp.px(18)
                                color: nr.active ? Serp.mauve : nma.containsMouse ? Serp.text : Serp.subtext1
                            }
                        }
                        SText {
                            visible: !nr.sep
                            anchors.left: ibox.right
                            anchors.leftMargin: Serp.px(12)
                            anchors.right: parent.right
                            anchors.rightMargin: Serp.px(8)
                            anchors.verticalCenter: parent.verticalCenter
                            text: nr.modelData.label || ""
                            size: Serp.px(13)
                            color: nr.active ? Serp.mauve : nma.containsMouse ? Serp.text : Serp.subtext1
                            Behavior on color {
                                ColorAnimation {
                                    duration: Serp.quick
                                }
                            }
                        }
                        MouseArea {
                            id: nma
                            anchors.fill: parent
                            enabled: !nr.sep
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const id = nr.modelData.id;
                                if (nr.sub) {
                                    side.subSel = id;
                                    side.jump(id.split("/")[0], id.split("/")[1]);
                                } else {
                                    side.subSel = "";
                                    side.jump(id, "");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
