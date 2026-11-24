import QtQuick
import qs.config
import qs.services
import qs.widgets
import "."
import "PaperGestures.js" as Gestures

Item {
    id: root
    property var plugin
    property string screenName
    property var widget
    readonly property string uid: widget ? widget.uid : ""
    readonly property string noteText: widget && widget.settings ? String(widget.settings.text || "") : ""
    readonly property bool wantVisible: noteText !== ""
    readonly property bool passive: false
    readonly property var host: {
        for (let item = parent; item; item = item.parent)
            if (item.uid === uid && item.role !== undefined) return item;
        return null;
    }
    readonly property bool fading: TyperNotes.fading.includes(uid)
    // Paper follows the pointer directly. The generic host resolves grid/collisions
    // every frame, which makes a small move jump to another grid line or widget edge.
    Binding {
        target: root.host
        property: "x"
        when: !!root.host && !!root.widget
        value: root.host && root.widget ? root.host.dragging ? DesktopWidgets.drag.x
            : root.host.clampX(root.widget.x < 0 ? root.host.area.width + root.widget.x - root.host.width : root.widget.x) : 0
        restoreMode: Binding.RestoreBinding
    }
    Binding {
        target: root.host
        property: "y"
        when: !!root.host && !!root.widget
        value: root.host && root.widget ? root.host.dragging ? DesktopWidgets.drag.y
            : root.host.clampY(root.widget.y < 0 ? root.host.area.height + root.widget.y - root.host.height : root.widget.y) : 0
        restoreMode: Binding.RestoreBinding
    }
    function finishDrag() {
        if (!host || DesktopWidgets.drag.uid !== uid) return;
        TyperNotes.move(uid, DesktopWidgets.drag.x, DesktopWidgets.drag.y);
        Qt.callLater(() => {
            if (DesktopWidgets.drag.uid === root.uid) DesktopWidgets.drag = {uid:"",x:0,y:0};
        });
    }
    property real appearance: 1
    readonly property color paper: Skin.hell ? Skin.mix(Theme.hellPlate, Theme.hellGold, 0.12) : Skin.mix(Skin.surfaceAlt, Theme.accent3, Skin.dark ? 0.19 : 0.1)
    readonly property color ink: Skin.hell ? Theme.hellText : Skin.text
    implicitWidth: Skin.px(225)
    implicitHeight: Skin.px(195)
    Item {
        id: art
        anchors.fill: parent
        opacity: root.fading || (root.host && !root.host.face && root.host.overFace && !root.host.dragging) ? 0 : root.appearance
        scale: root.fading ? 0.88 : 0.94 + root.appearance * 0.06
        transformOrigin: Item.Center
        Behavior on opacity { NumberAnimation { duration: Skin.ms(150) } }
        Behavior on scale { NumberAnimation { duration: Skin.ms(150); easing.type: Easing.InCubic } }
        Rectangle { x: Skin.px(2); y: Skin.px(3); width: parent.width; height: parent.height; radius: Skin.macWidgets ? Skin.px(7) : 0; color: Skin.shadow; opacity: 0.3 }
        Rectangle { anchors.fill: parent; radius: Skin.macWidgets ? Skin.px(7) : 0; color: root.paper; border.width: Skin.px(1); border.color: Skin.mix(root.paper, root.ink, 0.13) }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: -Skin.px(4); width: Skin.px(46); height: Skin.px(13); rotation: -4; color: Qt.alpha(Skin.accent, 0.48) }
        Flickable {
            id: page
            anchors.fill: parent
            anchors.margins: Skin.px(15)
            anchors.topMargin: Skin.px(24)
            anchors.bottomMargin: Skin.px(27)
            clip: true
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: false
            Text { id: body; width: page.width; text: root.noteText; textFormat: Text.PlainText; wrapMode: Text.Wrap; font.family: Skin.font; font.pixelSize: Skin.textSize; renderType: Skin.renderType; color: root.ink; lineHeight: 1.1 }
        }
        PxText { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: Skin.px(11); text: "3 клика — убрать"; kind: "small"; color: Qt.alpha(root.ink, 0.55) }
        Canvas {
            id: fold
            anchors.right: parent.right; anchors.bottom: parent.bottom
            width: Skin.px(19); height: width
            onPaint: {
                const ctx = getContext("2d"); ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = Skin.mix(root.paper, root.ink, 0.12);
                ctx.beginPath(); ctx.moveTo(0, height); ctx.lineTo(width, 0); ctx.lineTo(width, height); ctx.closePath(); ctx.fill();
            }
            Connections { target: root; function onPaperChanged() { fold.requestPaint(); } }
        }
    }
    Component.onCompleted: {
        const created = widget && widget.settings ? widget.settings.created || 0 : 0;
        if (Date.now() - created < 1200) arrival.start();
    }
    NumberAnimation { id: arrival; target: root; property: "appearance"; from: 0; to: 1; duration: Skin.ms(190); easing.type: Easing.OutCubic }
    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed && moved ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point start
        property point origin
        property bool moved: false
        property var clicks: null
        onPressed: function(event) {
            moved = false;
            if (!root.host) return;
            start = mapToItem(root.host.area, event.x, event.y);
            // Include the wallpaper parallax offset when the drag lifts the paper.
            origin = root.host.mapToItem(root.host.area, 0, 0);
        }
        onPositionChanged: function(event) {
            if (!pressed || !root.host || (root.widget && root.widget.locked)) return;
            const at = mapToItem(root.host.area, event.x, event.y);
            if (!moved && Math.abs(at.x-start.x)+Math.abs(at.y-start.y) < Qt.styleHints.startDragDistance) return;
            moved = true; clicks = null;
            const target = Gestures.dragPosition(origin, start, at,
                Qt.point(root.host.area.width-root.host.width, root.host.area.height-root.host.height));
            DesktopWidgets.drag = {uid:root.uid,screen:root.screenName,x:target.x,y:target.y,w:root.host.width,h:root.host.height};
        }
        onReleased: function(event) {
            if (moved) root.finishDrag();
            clicks = Gestures.released(clicks,event.x,event.y,Date.now(),moved,Qt.styleHints.mouseDoubleClickInterval,Skin.px(12));
            if (clicks.remove) TyperNotes.dismiss(root.uid);
        }
        onCanceled: { clicks = null; if (moved) root.finishDrag(); }
        onWheel: function(event) {
            const delta = event.pixelDelta.y || event.angleDelta.y/3;
            page.contentY = Math.max(0,Math.min(Math.max(0,page.contentHeight-page.height),page.contentY-delta));
            event.accepted = true;
        }
    }
}
