pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."

// Pixel meters for the plan limits: how much is LEFT and when it resets.
// `mac` (the macOS look: the desktop card, Skin.macWidgets; the menu bar popover, Skin.mac): thin rounded bars in
// SF Pro, and a problem (no login, an expired token) as a plain line of secondary text.
Column {
    id: root

    property bool compact: false
    // hell's look (the desktop orb while the demon rules): fire meters, bone text
    property bool hell: false
    property bool mac: false
    spacing: mac ? DesktopWidgets.mpx(8) : Theme.u * (compact ? 2 : 4)

    readonly property var rows: [
        {
            "label": I18n.t("5 часов", "5 hours"),
            "w": Usage.five
        },
        {
            "label": I18n.t("неделя", "week"),
            "w": Usage.week
        },
        {
            "label": I18n.t("неделя Opus", "Opus week"),
            "w": Usage.weekOpus
        },
        {
            "label": I18n.t("неделя Sonnet", "Sonnet week"),
            "w": Usage.weekSonnet
        }
    ].filter(r => !!r.w)

    readonly property string problem: ({
                "idle": "…",
                "loading": I18n.t("узнаю лимиты…", "Loading limits…"),
                "expired": I18n.t("токен Claude Code истёк — он обновится при следующем запуске claude", "Claude Code token expired. It refreshes the next time you start Claude Code."),
                "auth": I18n.t("Anthropic не пустил по токену (401) — перелогинься в claude", "Token rejected (401). Sign in to Claude Code again."),
                "offline": I18n.t("нет связи с api.anthropic.com", "Cannot reach api.anthropic.com"),
                "nologin": I18n.t("не нашёл ~/.claude/.credentials.json — войди в Claude Code", "Claude Code credentials not found. Sign in to Claude Code.")
            })[Usage.status] || Usage.status
    PxText {
        visible: !Usage.ok && !root.mac
        width: root.width
        wrapMode: Text.Wrap
        dim: true
        text: root.problem
    }

    // ---- macOS look ----
    Row {
        visible: !Usage.ok && root.mac
        width: root.width
        spacing: DesktopWidgets.mpx(6)
        MacIcon {
            id: macInfo
            name: "info"
            size: DesktopWidgets.mpx(14)
            color: DesktopWidgets.macSecondary
            y: DesktopWidgets.mpx(1)
        }
        MacWidgetText {
            width: parent.width - macInfo.width - parent.spacing
            text: root.problem.charAt(0).toUpperCase() + root.problem.slice(1)
            size: 12
            role: "secondary"
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }
    Repeater {
        model: Usage.ok && root.mac ? root.rows : []
        Column {
            id: mr
            required property var modelData
            readonly property color c: DesktopWidgets.macInk(Usage.colorFor(modelData.w.left, Theme))
            width: root.width
            spacing: DesktopWidgets.mpx(4)
            Item {
                width: parent.width
                height: mrLabel.implicitHeight
                MacWidgetText {
                    id: mrLabel
                    text: mr.modelData.label
                    size: 12
                    role: "secondary"
                }
                MacWidgetText {
                    anchors.right: parent.right
                    text: I18n.t("осталось ", "") + mr.modelData.w.left + "%" + I18n.t("", " left")
                    size: 12
                    weight: Font.DemiBold
                    color: mr.c
                }
            }
            Rectangle {
                width: parent.width
                height: DesktopWidgets.mpx(6)
                radius: height / 2
                color: DesktopWidgets.macSeparator
                Rectangle {
                    height: parent.height
                    radius: height / 2
                    width: mr.modelData.w.left > 0 ? Math.max(height, parent.width * mr.modelData.w.left / 100) : 0
                    color: mr.c
                }
            }
        }
    }

    Repeater {
        model: Usage.ok && !root.mac ? root.rows : []
        Column {
            id: r
            required property var modelData
            readonly property color c: root.hell ? (modelData.w.left <= 15 ? Theme.hellBlood : modelData.w.left <= 40 ? Theme.hellEmber : Theme.hellFlame) : Usage.colorFor(modelData.w.left, Theme)
            width: root.width
            spacing: Theme.u
            Row {
                width: parent.width
                PxText {
                    width: parent.width / 2
                    text: r.modelData.label
                    dim: !root.hell
                    color: root.hell ? Theme.hellTextDim : Theme.textDim
                }
                PxText {
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                    text: (root.hell ? I18n.t("душ осталось ", "Souls left ") : I18n.t("осталось ", "Remaining ")) + r.modelData.w.left + "%"
                    color: r.c
                    font.bold: true
                }
            }
            // blocky meter: filled blocks = what's left
            PxBox {
                width: parent.width
                height: Theme.u * (root.compact ? 6 : 8)
                sunken: true
                hell: root.hell
                color: root.hell ? Theme.hellSunken : Theme.sunken
                Row {
                    anchors.fill: parent
                    spacing: Math.max(1, Theme.u / 2)
                    Repeater {
                        model: 20
                        Rectangle {
                            required property int index
                            width: root.width > 0 ? (root.width - 19 * Math.max(1, Theme.u / 2)) / 20 : 0
                            height: Theme.u * (root.compact ? 6 : 8)
                            color: index < Math.round(r.modelData.w.left / 5) ? r.c : "transparent"
                        }
                    }
                }
            }
            PxText {
                visible: !root.compact && !!r.modelData.w.resetsAt
                text: r.modelData.w.resetsAt ? I18n.t("сброс через ", "Resets in ") + Usage.untilText(r.modelData.w.resetsAt) + "  (" + I18n.locale.toString(r.modelData.w.resetsAt, I18n.clock12 ? "ddd h:mm AP" : "ddd HH:mm") + ")" : ""
                kind: "tiny"
                dim: true
            }
        }
    }
    PxText {
        visible: Usage.ok && !root.compact && !root.mac
        text: I18n.t("план: ", "Plan: ") + (Usage.plan || "?") + I18n.t(" · обновлено ", " · updated ") + Qt.formatTime(Usage.updated, "HH:mm")
        kind: "tiny"
        dim: true
    }
}
