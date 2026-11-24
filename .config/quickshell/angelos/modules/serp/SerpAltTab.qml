pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// serp-skin: Alt+Tab (and ⌘Tab, AltTab.mode "apps") in Serpantinum's look, in place of AltTab.style's
// switchers while the skin is on (modules/alttab/AltTabHost loads it, hunks/alttab.py): a centred
// island of the skin (SGlass: flat, or the liquid glass) with the windows as rounded cards — the
// app's icon, the window's title — the picked one on the accent's tint inside an accent ring; under
// the cards the pick's full title, its app and its desk. The keys, the model and the picking are
// AltTabHost's / services/AltTab's own; the pointer picks too.
Item {
    id: root

    required property var host
    property Item backdrop: null
    readonly property bool apps: AltTab.mode === "apps"
    readonly property real r: Math.min(Serp.px(24), Math.round(Serp.radius * 1.4))
    readonly property real pad: Serp.px(14)
    readonly property real gap: Serp.px(8)
    readonly property real cellW: Serp.px(136)
    readonly property real cellH: Serp.px(112)
    readonly property real iconSize: Serp.px(48)
    readonly property real maxW: (host.screen ? host.screen.width : 1920) * 0.85
    readonly property int count: AltTab.items.length
    readonly property int perRow: Math.max(1, Math.min(count, Math.floor((maxW - pad * 2 + gap) / (cellW + gap))))
    readonly property int rows: Math.max(1, Math.ceil(count / perRow))
    implicitWidth: Math.max(perRow * cellW + (perRow - 1) * gap, Serp.px(260)) + pad * 2
    implicitHeight: pad + rows * cellH + (rows - 1) * gap + Serp.px(10) + footer.height + pad

    function titleOf(it) {
        if (!it)
            return "";
        return apps ? String(it.name || "") : (Niri.titleOf(it) || host.appName(it));
    }
    function appIdOf(it) {
        return it ? String(apps ? it.appId || "" : it.app_id || "") : "";
    }
    function subOf(it) {
        if (!it)
            return "";
        if (apps) {
            const n = it.windows ? it.windows.length : 0;
            return n > 1 ? I18n.t("окон: ", "windows: ") + n : "";
        }
        const p = host.place(it);
        return host.appName(it) + (p ? "  ·  " + p : "");
    }

    SGlass {
        anchors.fill: parent
        backdrop: root.backdrop
        radius: root.r
    }

    Grid {
        id: grid
        x: Math.round((root.width - width) / 2)
        y: root.pad
        columns: root.perRow
        spacing: root.gap
        Repeater {
            model: AltTab.items
            Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool picked: index === AltTab.index
                width: root.cellW
                height: root.cellH
                Rectangle {
                    anchors.fill: parent
                    radius: Serp.radius
                    color: card.picked ? Serp.selected : mouse.containsMouse ? Serp.hover : Qt.alpha(Serp.surface0, 0.45)
                    border.width: card.picked ? Serp.px(2) : 1
                    border.color: card.picked ? Serp.accent : Serp.line
                    Behavior on color {
                        ColorAnimation {
                            duration: Serp.quick
                        }
                    }
                }
                AppIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Serp.px(16)
                    appId: root.appIdOf(card.modelData)
                    size: root.iconSize
                    opacity: card.picked ? 1 : 0.85
                }
                // ⌘Tab: how many windows the app has
                Rectangle {
                    visible: root.apps && !!card.modelData.windows && card.modelData.windows.length > 1
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Serp.px(8)
                    width: Math.max(height, badge.implicitWidth + Serp.px(8))
                    height: Serp.px(18)
                    radius: height / 2
                    color: card.picked ? Serp.accent : Serp.surface1
                    SText {
                        id: badge
                        anchors.centerIn: parent
                        size: Serp.smallSize
                        bold: true
                        color: card.picked ? Serp.onAccent : Serp.subtext1
                        text: card.modelData.windows ? card.modelData.windows.length : ""
                    }
                }
                SText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Serp.px(12)
                    width: parent.width - Serp.px(16)
                    horizontalAlignment: Text.AlignHCenter
                    size: Serp.smallSize
                    bold: card.picked
                    color: card.picked ? Serp.accent : Serp.subtext1
                    text: root.titleOf(card.modelData)
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: AltTab.select(card.index)
                    onClicked: {
                        AltTab.select(card.index);
                        AltTab.commit();
                    }
                }
            }
        }
    }

    // the pick: its full title, its app and where it lives
    Column {
        id: footer
        x: root.pad
        y: grid.y + grid.height + Serp.px(10)
        width: root.width - root.pad * 2
        spacing: Serp.px(2)
        SText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            bold: true
            text: root.titleOf(AltTab.current)
        }
        SText {
            visible: text !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            size: Serp.smallSize
            dim: true
            text: root.subOf(AltTab.current)
        }
    }
}
