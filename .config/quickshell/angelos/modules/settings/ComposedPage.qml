pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.widgets

// A settings page of the tree (services/SettingsTree, modules/settings/tree.json): its
// heading, then its parts — page files shown inside it (PxPage.embedded) with only the
// groups the tree gives this page. The settings keep their own code where they always were;
// the tree only says where they show. The parts' sub-pages (advanced groups) are this
// page's ("Title ›" links, or cards that open in place in the Windows 11 look), "Reset this
// page" resets what its groups change (SettingsKeys.keysOf).
// A page is short: its main groups ("blocks"), then the rest folded under «Ещё…» ("more"),
// loaded only when it opens (a click, or the search leading to a setting in it).
PxPage {
    id: root

    property string pageKey: ""
    readonly property var entry: SettingsTree.page(pageKey)
    readonly property var parts: SettingsTree.partsOf(pageKey, "top")
    readonly property var moreParts: SettingsTree.partsOf(pageKey, "more")
    readonly property bool hasMore: moreParts.length > 0
    readonly property bool moreOpen: hasMore && !!SettingsTree.moreOpen[pageKey]
    readonly property bool moreHasNew: hasMore && SettingsNews.moreNew(pageKey)
    readonly property bool breathing: breathe.running
    function openMore() {
        if (hasMore)
            SettingsTree.setMoreOpen(pageKey, true);
    }
    pageId: pageKey
    heading: entry ? entry.label : ""
    // what's new here (SettingsNews' stars) counts as seen once you leave the page
    Component.onDestruction: SettingsNews.seePage(pageKey, moreOpen)
    // a page that is one whole page file says what that file said about itself
    readonly property var wholePart: parts.length === 1 && parts[0].loose && partRepeater.count > 0 ? partRepeater.itemAt(0) : null
    subtitle: wholePart && wholePart.item ? wholePart.item.subtitle : ""

    component Part: Loader {
        id: part
        required property var modelData
        width: parent.width
        function load() {
            setSource(modelData.file, {
                "embedded": true,
                "only": modelData.only,
                "loose": modelData.loose,
                "partOf": root.pageKey,
                "srcName": modelData.src,
                // every group open: what is rare waits under «Ещё…», not in folded cards
                "unfold": ["*"]
            });
        }
        Component.onCompleted: load()
    }

    Repeater {
        id: partRepeater
        model: root.parts
        Part {}
    }

    // ---- the pages next door ("links": the lens from Mouse, the voice from the angel) ----
    readonly property var linkTargets: (entry && entry.links || []).map(l => {
            const [id, group] = String(l).split(":");
            const p = SettingsTree.page(id);
            const c = SettingsTree.categoryOf(id);
            return p && SettingsTree.shown(p) ? {
                "id": id,
                "group": group || "",
                "label": (c && c.pages.length > 1 && c.id !== (SettingsTree.categoryOf(root.pageKey) || {}).id ? c.label + " › " : "") + p.label,
                "icon": p.icon || "gear"
            } : null;
        }).filter(x => !!x)
    Flow {
        visible: root.linkTargets.length > 0
        width: parent.width
        spacing: Theme.u * 3
        PxText {
            text: I18n.t("Рядом:", "Next door:")
            dim: true
            height: Theme.fit(14)
            verticalAlignment: Text.AlignVCenter
        }
        Repeater {
            model: root.linkTargets
            PxButton {
                required property var modelData
                compact: true
                icon: modelData.icon
                text: modelData.label + " ›"
                onClicked: {
                    if (modelData.group && root.view && root.view.showGroup) {
                        root.nav.settingsPage = modelData.id;
                        root.view.showGroup(modelData.group);
                    } else
                        Shell.settingsGo(root, modelData.id);
                }
            }
        }
    }

    // ---- «Ещё…» ----
    // the names of the groups inside, from the search index (no need to load them for that)
    readonly property string moreSummary: {
        const names = [];
        const lang = I18n.english ? "en" : "ru";
        for (const part of moreParts)
            for (const e of SettingsSearch.entries || [])
                if (e.kind === "group" && e.page === part.src && (part.only.length === 0 || part.only.includes(e.name)) && e[lang] && !names.includes(e[lang]))
                    names.push(e[lang]);
        return names.slice(0, 5).join(", ") + (names.length > 5 ? "…" : "");
    }
    Rectangle {
        id: moreFold
        visible: root.hasMore
        width: parent.width
        height: Math.max(Theme.fit(22), moreTexts.implicitHeight + Theme.u * 8)
        readonly property bool macLook: root.settingsSkin === "goldengate"
        radius: macLook ? Theme.u * 5 : 0
        color: macLook ? (moreMouse.containsMouse ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)) : (Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.035))) : moreMouse.containsMouse ? Theme.mix(Theme.faceAlt, Theme.accent, 0.12) : Theme.mix(Theme.face, Theme.faceAlt, 0.55)
        border.width: macLook ? 0 : Math.max(1, Theme.u / 2)
        border.color: Qt.alpha(Theme.lo, Theme.dark ? 0.9 : 0.5)
        Column {
            id: moreTexts
            anchors.left: parent.left
            anchors.leftMargin: Theme.u * 5
            anchors.right: moreArrow.left
            anchors.rightMargin: Theme.u * 4
            anchors.verticalCenter: parent.verticalCenter
            Row {
                spacing: Theme.u * 3
                PxText {
                    text: I18n.t("Ещё…", "More…")
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                // something new waits in there (services/SettingsNews)
                NewStar {
                    visible: root.moreHasNew
                    anchors.verticalCenter: parent.verticalCenter
                }
                PxText {
                    visible: root.moreHasNew
                    text: I18n.t("новое", "new")
                    kind: "tiny"
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            PxText {
                visible: text !== ""
                width: parent.width
                text: root.moreSummary
                kind: "tiny"
                dim: true
                elide: Text.ElideRight
            }
        }
        // small waves from the arrow, fading as they grow: there is more here, it opens. A few
        // breaths when the page shows (and on, slower, while something new waits inside); none
        // with less motion, while the pointer is on it, or once it is open
        Item {
            id: ripples
            anchors.centerIn: moreArrow
            readonly property real base: Math.max(Theme.u * 5, moreArrow.height * 0.8)
            property real wave: 0
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property real p: Math.max(0, Math.min(1, (ripples.wave - index * 0.17) / 0.62))
                    readonly property real size: Math.round(ripples.base * (1 + p * 2.2) / 2) * 2
                    width: size
                    height: size
                    x: -size / 2
                    y: -size / 2
                    radius: moreFold.macLook ? size / 2 : 0
                    rotation: moreFold.macLook ? 0 : 45
                    color: "transparent"
                    border.width: Math.max(1, Math.round(Theme.u / 2))
                    border.color: Theme.accent
                    antialiasing: moreFold.macLook
                    opacity: p > 0 && p < 1 ? 0.42 * Math.pow(1 - p, 1.6) : 0
                }
            }
            SequentialAnimation {
                id: breathe
                running: root.hasMore && !root.moreOpen && !Motion.calm && !moreMouse.containsMouse && root.visible
                loops: root.moreHasNew ? Animation.Infinite : 3
                onStopped: ripples.wave = 0
                PauseAnimation {
                    duration: 900
                }
                NumberAnimation {
                    target: ripples
                    property: "wave"
                    from: 0
                    to: 1
                    duration: 1700
                    easing.type: Easing.OutSine
                }
                PauseAnimation {
                    duration: root.moreHasNew ? 5200 : 3200
                }
            }
        }
        PxText {
            id: moreArrow
            anchors.right: parent.right
            anchors.rightMargin: Theme.u * 5
            anchors.verticalCenter: parent.verticalCenter
            text: root.moreOpen ? "▴" : "▾"
            kind: "title"
            color: root.moreHasNew ? Theme.accent : Theme.textDim
        }
        MouseArea {
            id: moreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SettingsTree.setMoreOpen(root.pageKey, !root.moreOpen)
        }
    }
    Column {
        id: moreCol
        visible: root.moreOpen
        width: parent.width
        spacing: Theme.u * (root.settingsSkin === "stream" ? 6 : 8)
        Repeater {
            model: root.moreOpen ? root.moreParts : []
            Part {}
        }
    }
}
