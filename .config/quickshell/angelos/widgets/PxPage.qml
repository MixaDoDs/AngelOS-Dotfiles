import QtQuick
import qs.config
import qs.services
import qs.widgets

// Scrollable settings page: a column of PxGroups, and at the bottom "Reset this
// page" for the settings the page shows (services/SettingsKeys) — asks once
// more before it resets; "Undo" at the top brings everything back.
// Like macOS: at the top the way up ("‹ Sound" on a sub-page), then a card of links
// ("Title ›") to the section's other pages and to this page's advanced groups, which
// open on their own (focusGroup = Shell.settingsSub: the rest of the page steps aside).
PxScroll {
    id: root

    property string heading: ""
    property string subtitle: ""
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)
    // the Windows 11 look: the view says where you are (big crumbs), sub-pages unfold in place
    readonly property bool fluent: Theme.fluentFor(root.parent)
    property color headingColor: settingsSkin === "windose" ? Theme.windoseTitle : settingsSkin === "stream" ? Theme.streamLive : Theme.dark ? Theme.accent : Theme.edge
    property color subtitleColor: Theme.textDim
    default property alias items: col.data
    readonly property int innerWidth: col.width
    // Put together from groups (modules/settings/ComposedPage.qml, the tree in tree.json):
    // this page shown as a part of another one — only the groups named in `only`, no heading,
    // links or reset of its own, as tall as its content (the page it is in scrolls).
    property bool embedded: false
    property var only: []                   // group names (PxGroup.name) to show; empty: all
    property bool loose: true               // what sits outside the groups (a note, buttons)
    property string partOf: ""              // the page it is a part of (Shell.settingsPage)
    property var unfold: []                 // groups that are the whole page: never a sub-page here
    scrolls: !embedded
    implicitHeight: embedded ? contentHeight : 0
    function wants(g) {
        return !only || only.length === 0 || only.indexOf(g.name) >= 0;
    }
    // the settings page this is (plugin pages and the home tiles have nothing to reset)
    property string pageId: partOf || Shell.settingsPage
    readonly property var changed: SettingsKeys.loaded ? SettingsKeys.changedOn(pageId) : []
    property bool confirming: false
    property int resetCount: -1
    // the sub-page open on this page: one of its advanced groups (PxGroup steps the others aside)
    readonly property string focusGroup: pageId === Shell.settingsPage ? Shell.settingsSub : ""
    readonly property var view: Shell.settingsView
    // the properties view shows the section's pages and the sub-pages as its tabs
    readonly property bool tabsOutside: !!view && view.ownsSubpages === true && pageId === Shell.settingsPage
    // the way up: from a sub-page to its page, from a section's other page to its first one
    readonly property var up: {
        if (focusGroup !== "")
            return {
                "label": heading,
                "page": pageId,
                "sub": ""
            };
        const parentId = view && view.parentOf ? view.parentOf(pageId) : "";
        return parentId ? {
            "label": view.labelOf(parentId),
            "page": parentId,
            "sub": ""
        } : null;
    }
    // the links at the top: the section's other pages, then this page's advanced groups
    // (a page put together from parts: theirs, in order)
    readonly property var advancedGroups: {
        const out = [];
        for (const c of col.children) {
            if (c.advanced === true && c.title && c.shown !== false && root.wants(c))
                out.push(c);
            else if (c.item && c.item.embedded === true)
                for (const g of c.item.advancedGroups)
                    out.push(g);
        }
        return out;
    }
    readonly property var links: focusGroup !== "" || tabsOutside || embedded || fluent ? [] : (view && view.subpagesOf ? view.subpagesOf(pageId) : []).map(p => ({
                "label": p.label,
                "icon": p.icon,
                "tint": view.tintOf(p.id),
                "page": p.id,
                "sub": ""
            })).concat(advancedGroups.map(g => ({
                "label": g.title,
                "icon": g.icon || "gear",
                "tint": "",
                "page": pageId,
                "sub": g.title
            })))
    function go(l) {
        if (!l)
            return;
        if (Shell.settingsPage !== l.page)
            Shell.settingsPage = l.page;
        Shell.settingsSub = l.sub || "";
        scrollBy(-flick.contentY);
    }
    // everything else on the page steps aside while a sub-page is open
    Component {
        id: asideBinding
        Binding {
            property: "visible"
            value: false
            restoreMode: Binding.RestoreBindingOrValue
        }
    }
    property var _aside: []
    function bindAside() {
        for (const c of col.children) {
            // groups step aside themselves; the parts of a page put together do it inside
            if (c === head || c === linkCard || c.advanced !== undefined || c.item !== undefined || c.itemAt !== undefined || root._aside.indexOf(c) >= 0)
                continue;
            root._aside.push(c);
            asideBinding.createObject(root, {
                "target": c,
                "when": Qt.binding(() => (root.focusGroup !== "" && !root.fluent) || (root.embedded && !root.loose))
            });
        }
    }
    Connections {
        target: col
        function onChildrenChanged() {
            Qt.callLater(root.bindAside);
        }
    }

    contentHeight: embedded ? col.implicitHeight : col.implicitHeight + (footer.visible ? footer.height + Theme.u * 8 : 0) + Theme.u * 10

    Column {
        id: col
        x: root.embedded ? 0 : Theme.u * 4
        y: root.embedded ? 0 : Theme.u * 4
        width: parent.width - (root.embedded ? 0 : Theme.u * 8)
        spacing: Theme.u * (root.settingsSkin === "stream" ? 6 : 8)

        Column {
            id: head
            visible: root.heading !== "" && !root.embedded && (!root.fluent || root.subtitle !== "")
            width: parent.width
            spacing: Theme.u * (root.settingsSkin === "classic" ? 1 : 2)
            // "‹ Sound": up to the page or the section this is part of
            PxText {
                id: upLink
                visible: !!root.up && !root.tabsOutside && !root.fluent
                text: "‹ " + (root.up ? root.up.label : "")
                color: upMouse.containsMouse ? Theme.accent : Theme.textDim
                font.bold: true
                MouseArea {
                    id: upMouse
                    anchors.fill: parent
                    anchors.margins: -Theme.u * 2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.go(root.up)
                }
            }
            PxText {
                visible: root.settingsSkin !== "classic" && root.settingsSkin !== "goldengate"
                text: root.settingsSkin === "stream" ? "● LIVE  /  angelOS" : "▸ " + I18n.exe("settings") + " / angelOS"
                kind: "tiny"
                color: root.settingsSkin === "stream" ? Theme.streamLive : Theme.windoseLavender
                font.bold: true
            }
            PxText {
                // a long heading in big fonts wraps instead of running off the page
                visible: !root.fluent
                width: Math.min(implicitWidth, parent.width)
                wrapMode: Text.Wrap
                text: root.focusGroup || root.heading
                kind: "big"
                color: root.headingColor
            }
            Rectangle {
                visible: root.settingsSkin !== "classic" && root.settingsSkin !== "goldengate"
                width: parent.width
                height: Theme.u * (root.settingsSkin === "stream" ? 2 : 1)
                color: root.settingsSkin === "stream" ? Theme.streamLive : Theme.windoseRose
            }
            PxText {
                visible: root.subtitle !== "" && root.focusGroup === ""
                width: parent.width
                text: root.subtitle
                color: root.subtitleColor
                wrapMode: Text.Wrap
            }
        }

        // "Title ›": the section's other pages and this page's sub-pages, one card
        PxBox {
            id: linkCard
            visible: root.links.length > 0
            width: parent.width
            height: links.implicitHeight + inset * 2
            color: root.settingsSkin === "classic" ? Theme.mix(Theme.face, Theme.faceAlt, 0.35) : root.settingsSkin === "stream" ? Theme.streamPanel : Theme.windosePaper
            Column {
                id: links
                width: parent.width
                Repeater {
                    model: root.links
                    Item {
                        id: link
                        required property var modelData
                        required property int index
                        width: links.width
                        height: Theme.u * 17
                        Rectangle {
                            anchors.fill: parent
                            color: lm.containsMouse ? Theme.mix(Theme.face, Theme.accent, 0.16) : "transparent"
                        }
                        Rectangle {
                            visible: link.index > 0
                            x: Theme.u * 18
                            width: parent.width - x - Theme.u * 3
                            height: Math.max(1, Theme.u / 2)
                            color: Qt.alpha(Theme.lo, Theme.dark ? 0.9 : 0.55)
                        }
                        Row {
                            x: Theme.u * 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.u * 4
                            SettingsTile {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: link.modelData.icon
                                tint: link.modelData.tint || Theme.mix(Theme.accent, Theme.face, 0.25)
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: link.modelData.label
                            }
                        }
                        PxText {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.u * 5
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›"
                            kind: "title"
                            dim: true
                        }
                        MouseArea {
                            id: lm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.go(link.modelData)
                        }
                    }
                }
            }
        }
    }

    Row {
        id: footer
        visible: !root.embedded && root.pageId !== "home" && root.pageId !== "more" && SettingsKeys.keysOf(root.pageId).length > 0 && (root.changed.length > 0 || root.resetCount >= 0)
        x: col.x
        y: col.y + col.implicitHeight + Theme.u * 8
        spacing: Theme.u * 4
        PxButton {
            compact: true
            danger: root.confirming
            icon: "refresh"
            enabled: root.changed.length > 0
            text: root.confirming ? I18n.t("Точно сбросить? Нажми ещё раз", "Sure? Click again") : I18n.t("Сбросить эту страницу", "Reset this page")
            onClicked: {
                if (!root.confirming) {
                    root.confirming = true;
                    unconfirm.restart();
                    return;
                }
                root.confirming = false;
                root.resetCount = Config.resetKeys(root.changed);
            }
        }
        PxText {
            anchors.verticalCenter: parent.verticalCenter
            kind: "tiny"
            dim: true
            text: root.resetCount >= 0 && root.changed.length === 0 ? I18n.t("Сброшено ♡ «Отменить» вверху вернёт как было", "Reset ♡ “Undo” at the top brings it back") : I18n.t("изменено здесь: ", "changed here: ") + root.changed.length
        }
    }
    Timer {
        id: unconfirm
        interval: 4000
        onTriggered: root.confirming = false
    }
    Component.onCompleted: {
        SettingsKeys.load();
        // a sub-page that is all the page shows is just the page (Stream mode, Hell…)
        for (const c of col.children)
            if (c.advanced === true && unfold && unfold.indexOf(c.name) >= 0)
                c.advanced = false;
        bindAside();
    }
}
