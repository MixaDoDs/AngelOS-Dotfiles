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
    // the picture's own shape, at most a phone-like card
    readonly property size pic: {
        const w = img.implicitWidth || 16, h = img.implicitHeight || 9;
        const k = Math.min(u * 90 / w, u * 70 / h);
        return Qt.size(Math.round(w * k), Math.round(h * k));
    }
    readonly property int pad: inset + u
    width: pic.width + pad * 2
    height: pic.height + pad * 2
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
        x: card.u   // (a PxBox's children sit inside its frame already)
        y: card.u
        width: card.pic.width
        height: card.pic.height
        source: ShotEdit.path ? FileSearch.uri(ShotEdit.path) : ""
        sourceSize: Qt.size(card.u * 180, card.u * 140)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
    }
    Rectangle {
        anchors.fill: img
        color: Qt.alpha(Theme.accent, 0.14)
        visible: hover.hovered
        PxText {
            anchors.centerIn: parent
            kind: "tiny"
            text: I18n.t("Править", "Edit")
        }
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered)
            img.grabToImage(r => card.dragPic = r.url, Qt.size(card.u * 40, card.u * 24))
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: ShotEdit.edit()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: ShotEdit.dismiss()
    }
    // dragged out: the file (into a chat, a folder)
    property url dragPic
    DragHandler {
        id: drag
        target: null
    }
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
