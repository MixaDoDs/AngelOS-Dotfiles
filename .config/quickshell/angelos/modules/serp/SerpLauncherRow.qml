pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.widgets

// serp-skin: one row of the serp Start (SerpLauncher), Serpantinum's look: 44 px, a rounded box
// with the app's icon (or a line icon, a file's thumbnail, a site's favicon), the name and a
// dim line under it. The accent plate itself slides under the rows (SerpLauncher), the row only
// turns its ink and leans a hair right when it is the picked one.
Item {
    id: row
    required property var r            // the row: {section, label, sub, app?, file?, mac?, image?, run?, provider?}
    required property int index
    property Item host: null           // the SerpLauncher: pointed(), runRow(), askMenu()
    property bool sel: false
    height: Serp.px(44)

    readonly property color ink: sel ? Serp.onAccent : Serp.text
    readonly property color dimInk: sel ? Qt.alpha(Serp.onAccent, 0.75) : Serp.subtext0

    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: Serp.px(8) + (row.sel ? Serp.px(3) : 0)
        anchors.rightMargin: Serp.px(10)
        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: Serp.normal
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }

        // ---- the icon box ----
        Rectangle {
            id: box
            anchors.verticalCenter: parent.verticalCenter
            width: Serp.px(32)
            height: width
            radius: Serp.px(8)
            color: row.sel ? Qt.alpha(Serp.crust, 0.18) : Serp.surface1
            Behavior on color {
                ColorAnimation {
                    duration: Serp.quick
                }
            }
            Image {
                id: appIcon
                visible: !!row.r.app && status === Image.Ready
                anchors.centerIn: parent
                width: Serp.px(24)
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                smooth: true
                mipmap: true
                asynchronous: true
                source: row.r.app && row.r.app.icon ? (String(row.r.app.icon).startsWith("/") ? "file://" + row.r.app.icon : Quickshell.iconPath(row.r.app.icon, true)) : ""
            }
            FileThumb {
                id: thumb
                visible: ok
                anchors.fill: parent
                anchors.margins: Serp.px(2)
                hit: row.r.file || null
            }
            Image {
                id: favicon
                visible: !row.r.app && !!row.r.image && status === Image.Ready
                anchors.centerIn: parent
                width: Serp.px(18)
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                smooth: true
                asynchronous: true
                source: row.r.image || ""
            }
            SIcon {
                visible: !appIcon.visible && !thumb.ok && !favicon.visible
                anchors.centerIn: parent
                name: row.r.mac || (row.r.app ? "app-window" : "circle-dot")
                size: Serp.px(16)
                color: row.sel ? Serp.onAccent : Serp.subtext1
            }
        }

        // ---- the name and the line under it ----
        Column {
            anchors.left: box.right
            anchors.leftMargin: Serp.px(10)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Serp.px(1)
            SText {
                width: parent.width
                text: row.r.label || ""
                size: Serp.px(12)
                bold: row.sel
                color: row.ink
                Behavior on color {
                    ColorAnimation {
                        duration: Serp.quick
                    }
                }
            }
            SText {
                visible: text !== ""
                width: parent.width
                text: row.r.sub || ""
                size: Serp.px(10)
                color: row.dimInk
                elide: Text.ElideMiddle
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPositionChanged: m => {
            if (row.host)
                row.host.pointed(this, m, row.index);
        }
        onClicked: m => {
            if (!row.host)
                return;
            if (m.button === Qt.RightButton)
                row.host.askMenu(row.r, this, m.x, m.y);
            else
                row.host.runRow(row.r);
        }
    }
}
