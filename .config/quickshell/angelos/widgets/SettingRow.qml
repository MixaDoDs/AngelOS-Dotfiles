import QtQuick
import qs.config
import qs.services

// "label ........ control" row with an optional hint below the label.
// With `preview` set to a scene (widgets/previews/<scene>.qml), controls call
// show(value, caption) when an option is clicked and a looping preview.exe
// opens under the row; its × folds it away.
Item {
    id: root
    // inside the P5 settings window: its colours (Theme.tone)
    readonly property bool p5: settingsSkin === "p5"

    property string label: ""
    property string hint: ""
    readonly property string settingsSkin: Theme.settingsSkinFor(root.parent)
    // the P5 settings window draws like the classic look, in its own colours
    readonly property bool classicLike: settingsSkin === "classic" || settingsSkin === "p5"
    readonly property bool streamLayout: settingsSkin === "stream"
    // Settings (SettingsView.fluent): a row of its group's card, the control on its right, a
    // hairline between rows
    readonly property bool fluent: Theme.fluentFor(root.parent)
    // the Golden Gate skin's System Settings: no card of its own — a row of its group's box with
    // a hairline between rows, the label regular
    readonly property bool mac: settingsSkin === "goldengate"
    property int labelWidth: streamLayout ? width - Theme.u * 10 : Math.min(Theme.u * 120, width * 0.45)
    default property alias control: slot.data
    property string preview: ""
    property string previewVariant: ""
    property string previewCaption: ""
    property bool previewOpen: false
    // where it sits in its card: a catalog's row sits in a slot of its own (CatalogPage)
    readonly property real placeY: parent && parent.catRow === true ? parent.y : y
    readonly property int rowHeight: streamLayout ? labels.implicitHeight + slot.childrenRect.height + Theme.u * 12 : fluent ? Math.max(Theme.fit(mac ? 20 : 17), Math.max(labels.implicitHeight, slot.childrenRect.height) + Theme.u * (mac ? 8 : 6)) : Math.max(labels.implicitHeight, slot.childrenRect.height) + Theme.u * (settingsSkin === "windose" ? 8 : 2)

    // new since you last looked (services/SettingsNews): a star after the label. The row's group
    // and page file come from its place on the page
    // (looked up when the news change: by then the page is put together)
    readonly property bool isNew: {
        if (!SettingsNews.news.count || !label)
            return false;
        let group = null, src = "";
        for (let p = root.parent; p; p = p.parent) {
            if (!group && p.advanced !== undefined && p.name !== undefined && p.title !== undefined)
                group = p;
            if (p.srcName !== undefined) {
                src = p.srcName;
                break;
            }
        }
        return !!group && SettingsNews.rowNew(src, group.name, label);
    }

    function show(value, caption) {
        if (!preview)
            return;
        previewVariant = String(value);
        previewCaption = caption || "";
        previewOpen = true;
        if (gif.item)
            gif.item.restart();
    }

    width: parent ? parent.width : implicitWidth
    implicitHeight: rowHeight + (gif.item ? gif.item.implicitHeight + Theme.u * 3 : 0)

    // the hairline above every row but the first of its card
    Rectangle {
        visible: root.mac && root.placeY > 0
        x: Theme.u * 5
        width: parent.width - x * 2
        height: 1
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
    }
    Rectangle {
        visible: root.fluent && !root.mac && root.placeY > 0
        width: parent.width
        height: Math.max(1, Theme.u / 2)
        color: Qt.alpha(Theme.toneOf(root.settingsSkin, "lo"), Theme.dark ? 0.7 : 0.35)
    }
    // classic: a hairline between the rows of a card, in the middle of the gap above
    Rectangle {
        visible: !root.fluent && root.classicLike && root.placeY > 0 && !!root.parent && root.parent.fixedWidth === true
        y: -Math.round((root.parent && root.parent.spacing ? root.parent.spacing : Theme.u * 4) / 2) - height / 2
        width: parent.width
        height: Math.max(1, Theme.u / 2)
        color: Qt.alpha(Theme.toneOf(root.settingsSkin, "lo"), Theme.dark ? 0.9 : 0.55)
    }
    Rectangle {
        visible: !root.classicLike && !root.mac
        width: parent.width
        height: root.rowHeight
        radius: root.streamLayout ? Theme.u * 3 : 0
        color: root.streamLayout ? Theme.mix(Theme.streamPanel, Theme.streamLive, 0.055) : Theme.windoseSticker
        border.width: Math.max(1, Theme.u / 2)
        border.color: root.streamLayout ? Theme.mix(Theme.streamLive, Theme.streamPanel, 0.55) : Theme.mix(Theme.windoseInk, Theme.windosePaper, 0.55)
    }
    Rectangle {
        visible: !root.classicLike && !root.mac
        width: root.streamLayout ? Theme.u * 2 : Theme.u * 3
        height: root.rowHeight - Theme.u * 2
        x: Theme.u
        y: Theme.u
        radius: root.streamLayout ? Theme.u : 0
        color: root.streamLayout ? Theme.streamLive : Theme.windoseRose
    }

    Column {
        id: labels
        x: root.mac ? Theme.u * 5 : root.fluent || root.classicLike ? 0 : Theme.u * 6
        width: root.labelWidth
        y: root.streamLayout ? Theme.u * 4 : (root.rowHeight - implicitHeight) / 2
        PxText {
            id: labelText
            width: parent.width - (root.isNew ? newStar.width + Theme.u * 3 : 0)
            text: root.label
            wrapMode: Text.Wrap
            font.bold: !root.classicLike && !root.mac
            NewStar {
                id: newStar
                visible: root.isNew
                x: Math.min(labelText.contentWidth, labelText.width) + Theme.u * 2
                y: Math.max(0, (Math.min(labelText.contentHeight, labelText.font.pixelSize * 1.4) - height) / 2)
            }
        }
        PxText {
            visible: root.hint !== ""
            width: parent.width
            text: root.hint
            kind: "tiny"
            dim: true
            wrapMode: Text.Wrap
        }
    }
    Item {
        id: slot
        readonly property bool fixedWidth: true // PxToggle wraps its label to fit
        x: root.streamLayout ? Theme.u * 6 : labels.x + root.labelWidth + Theme.u * (root.fluent ? 5 : root.classicLike ? 6 : 12)
        width: root.width - x - (root.mac ? Theme.u * 5 : root.fluent || root.classicLike ? 0 : Theme.u * 5)
        y: root.streamLayout ? labels.y + labels.implicitHeight + Theme.u * 3 : (root.rowHeight - height) / 2
        height: childrenRect.height
    }
    Loader {
        id: gif
        active: root.preview !== "" && root.previewOpen
        y: root.rowHeight + Theme.u
        x: Math.min(root.labelWidth, Theme.u * 20)
        width: Math.min(root.width - x, Theme.u * 230)
        sourceComponent: PxPreview {
            width: gif.width
            height: implicitHeight
            scene: root.preview
            variant: root.previewVariant
            caption: root.previewCaption
            onCloseClicked: root.previewOpen = false
        }
    }
}
