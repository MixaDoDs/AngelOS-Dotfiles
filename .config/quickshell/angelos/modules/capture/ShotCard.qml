pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import "../../widgets/Place.js" as Place

// The corner's picture of a screenshot just saved (services/ShotEdit; ShotPreview puts it in a
// layer window): a click opens the editor, a drag takes the file out, a right click or × sends
// it away; while the pointer is on it, it stays (held).
PxBox {
    id: card

    readonly property int u: Theme.u
    readonly property bool held: hover.hovered || drag.active
    readonly property var scan: ShotEdit.privacyScan
    readonly property bool found: !!scan && scan.boxes.length > 0
    // the picture's own shape, at most a phone-like card
    readonly property size pic: {
        const w = img.implicitWidth || 16, h = img.implicitHeight || 9;
        const k = Math.min(u * 90 / w, u * 70 / h);
        return Qt.size(Math.round(w * k), Math.round(h * k));
    }
    readonly property int pad: inset + u
    width: Math.max(pic.width, footer.implicitWidth) + pad * 2
    height: pic.height + footer.implicitHeight + pad * 2 + u * 2
    shadow: true
    // in from the screen's edge it sits at (ShotEdit.at)
    transform: Translate {
        id: slide
    }
    NumberAnimation {
        running: true
        target: slide
        property: Place.left(ShotEdit.at) || Place.right(ShotEdit.at) ? "x" : "y"
        from: (Place.left(ShotEdit.at) || Place.top(ShotEdit.at) ? -1 : 1) * ((Place.left(ShotEdit.at) || Place.right(ShotEdit.at) ? card.width : card.height) + card.u * 12)
        to: 0
        duration: Motion.calm ? 0 : 220
        easing.type: Easing.OutCubic
    }

    Image {
        id: img
        anchors.horizontalCenter: parent.horizontalCenter
        y: card.u
        width: card.pic.width
        height: card.pic.height
        source: ShotEdit.path ? FileSearch.uri(ShotEdit.path) : ""
        sourceSize: Qt.size(card.u * 180, card.u * 140)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false

        Repeater {
            model: card.found && img.status === Image.Ready ? card.scan.boxes : []
            Rectangle {
                required property var modelData
                x: (img.width - img.paintedWidth) / 2 + modelData.x * img.paintedWidth / card.scan.width
                y: (img.height - img.paintedHeight) / 2 + modelData.y * img.paintedHeight / card.scan.height
                width: modelData.w * img.paintedWidth / card.scan.width
                height: modelData.h * img.paintedHeight / card.scan.height
                color: Qt.alpha(Theme.accent, 0.23)
                border.color: Theme.accent
                border.width: 1
            }
        }
        TapHandler {
            acceptedButtons: Qt.LeftButton
            enabled: !!card.scan && !ShotEdit.copyingMasked
            onTapped: ShotEdit.review()
        }
        DragHandler {
            id: drag
            enabled: !!card.scan && !card.found
            target: null
        }
    }
    Column {
        id: footer
        anchors.horizontalCenter: parent.horizontalCenter
        y: img.y + img.height + card.u * 2
        spacing: card.u

        PxText {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "tiny"
            text: !card.scan ? I18n.t("Проверяю снимок…", "Checking screenshot…") :
                card.scan.failed ? I18n.t("Проверка не удалась", "Could not check") :
                card.found ? I18n.t("Найдено областей: %1", "Areas found: %1").arg(card.scan.boxes.length) :
                I18n.t("Совпадений нет", "No matches")
        }
        Row {
            spacing: card.u
            PxButton {
                objectName: "shot-privacy-copy"
                visible: card.found
                enabled: !ShotEdit.copyingMasked
                compact: true
                accent: true
                kind: "tiny"
                text: ShotEdit.copyingMasked ? I18n.t("Копирую…", "Copying…") : I18n.t("Копировать с плашками", "Copy with masks")
                onClicked: ShotEdit.copyMasked()
            }
            PxButton {
                objectName: "shot-privacy-review"
                enabled: !!card.scan && !ShotEdit.copyingMasked
                compact: true
                kind: "tiny"
                text: I18n.t("Править", "Edit")
                onClicked: ShotEdit.review()
            }
        }
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered)
            img.grabToImage(r => card.dragPic = r.url, Qt.size(card.u * 40, card.u * 24))
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: ShotEdit.dismiss()
    }
    // dragged out: the file (into a chat, a folder)
    property url dragPic
    Drag.active: drag.active
    Drag.dragType: Drag.Automatic
    Drag.imageSource: card.dragPic
    Drag.supportedActions: Qt.CopyAction
    Drag.mimeData: {
        "text/uri-list": ShotEdit.path ? FileSearch.uri(ShotEdit.path) : ""
    }
    Drag.onDragFinished: action => {
        if (action !== Qt.IgnoreAction)
            ShotEdit.dismiss();
    }
    PxButton {
        visible: hover.hovered
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.u
        compact: true
        icon: "close"
        onClicked: ShotEdit.dismiss()
    }
}
