pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// The tuning (PhoneScreen): what the phone wears — the shell, rhinestones, a sticker, the charm,
// the screen's wallpaper (PhoneScripts.looks). ◀ ▶ the part, 2 8 the piece, OK puts it on. A
// locked piece says what opens it (PhoneLine.locked): her tenderness, Snake and Raid scores,
// calls and texts, codes of the day, a talk with the demon; some only a code of the day gives.
Item {
    id: root

    required property var phone
    readonly property int k: Theme.u
    readonly property color ink: phone.screenInk
    readonly property color dimInk: phone.screenDim

    property int cat: 0
    property int at: 0
    readonly property var part: PhoneLine.looks[cat]
    readonly property var items: part.items.map(it => Object.assign({
                "key": part.id + ":" + it.id
            }, it))
    readonly property string worn: PhoneLine.wearing(part.id)
    readonly property var soft: ["", I18n.t("Надеть", "Wear"), I18n.t("Назад", "Back")]
    readonly property int openCount: PhoneLine.pieces.filter(p => !PhoneLine.locked(p)).length

    function key(k) {
        if (k === "left" || k === "4") {
            cat = (cat + PhoneLine.looks.length - 1) % PhoneLine.looks.length;
            at = 0;
            return true;
        }
        if (k === "right" || k === "6") {
            cat = (cat + 1) % PhoneLine.looks.length;
            at = 0;
            return true;
        }
        if (k === "up" || k === "2") {
            at = (at + items.length - 1) % items.length;
            return true;
        }
        if (k === "down" || k === "8") {
            at = (at + 1) % items.length;
            return true;
        }
        if (k === "ok" || k === "call" || k === "5") {
            const it = items[at];
            if (it && !PhoneLine.locked(it)) {
                PhoneLine.wear(part.id, it.id);
                PhoneLine.play("click", 0.6);
                Achievements.note("phone.tuning", it.key);
            } else {
                PhoneLine.play("busy", 0.4);
            }
            return true;
        }
        return false;
    }

    Row {
        id: head
        width: parent.width
        PxIcon {
            name: "arrowLeft"
            fill: root.phone.trim
        }
        PxText {
            width: parent.width - root.k * 20
            horizontalAlignment: Text.AlignHCenter
            text: PhoneLine.tr(root.part.name)
            kind: "tiny"
            color: root.phone.trim
        }
        PxIcon {
            name: "arrowRight"
            fill: root.phone.trim
        }
    }
    ListView {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: root.k * 2
        anchors.bottom: count.top
        width: parent.width
        clip: true
        interactive: false
        model: root.items
        currentIndex: root.at
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool shut: PhoneLine.locked(modelData)
            readonly property bool lit: index === root.at
            width: list.width
            height: root.k * 15
            color: lit ? root.phone.trim : "transparent"
            Row {
                x: root.k * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.k * 2
                PxIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.shut ? "lock" : row.modelData.id === root.worn ? "check" : "sparkle"
                    fill: row.lit ? "#ffffff" : root.phone.trim
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    PxText {
                        text: PhoneLine.tr(row.modelData.name)
                        kind: "tiny"
                        color: row.lit ? Theme.selectText : row.shut ? root.dimInk : root.ink
                    }
                    PxText {
                        visible: row.shut || !!row.modelData.note
                        text: row.shut ? PhoneLine.lockText(row.modelData) : PhoneLine.tr(row.modelData.note)
                        kind: "tiny"
                        color: row.lit ? Qt.alpha(Theme.selectText, 0.8) : root.dimInk
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.at = row.index;
                    root.key("ok");
                }
            }
        }
    }
    PxText {
        id: count
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: I18n.t("Открыто ", "Unlocked ") + root.openCount + " / " + PhoneLine.pieces.length
        kind: "tiny"
        color: root.dimInk
    }
}
