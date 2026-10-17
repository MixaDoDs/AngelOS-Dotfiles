pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets
import qs.modules.y2k

// The phone's camera (PhoneScreen): not a screenshot — a selfie with her. In the finder she
// (the demon while she rules) poses over a backdrop, ◀ ▶ change it, 5 / OK / the green key
// shoot: a flash, the shutter, a pose of her own each time (a wink, a smile, wings up, a
// tilt), the date in yellow in the corner as the 2002 cameras stamped it; now and then the
// other one photobombs. The photo goes to the album (PhoneLine.keepPhoto, files in
// ~/.local/share/angelos/phone/album) and she says something about it. * opens the album:
// ◀ ▶ through it, the green key copies the photo to ~/Pictures/angelOS, # throws it away.
Item {
    id: root

    required property var phone
    readonly property int k: Theme.u
    readonly property color ink: phone.screenInk
    readonly property color dimInk: phone.screenDim
    readonly property string who: Angel.demon ? "demon" : "angel"

    property string mode: "finder"         // finder | album
    readonly property var backdrops: [["clouds", I18n.t("Облака", "Clouds"), "#bfe3ff", "#ffffff"], ["stars", I18n.t("Ночь", "Night"), "#1b1638", "#ffe07a"], ["hearts", I18n.t("Сердечки", "Hearts"), "#ffd2e4", "#ff6fa8"], ["flames", I18n.t("Ад", "Hell"), "#2a0a10", "#ff5a3a"], ["checker", I18n.t("Студия", "Studio"), "#e9e4f2", "#b9a8d8"]]
    property int bd: 0
    readonly property var album: Story.phone ? Story.phone.album || [] : []
    property int pic: 0
    readonly property var soft: mode === "album" ? [I18n.t("В Картинки", "To Pictures"), "", I18n.t("Назад", "Back")] : [I18n.t("Снять", "Shoot"), I18n.t("Снять", "Shoot"), I18n.t("Назад", "Back")]

    // the pose of the next shot
    property bool wink: false
    property bool smile: false
    property bool wings: false
    property real lean: 0
    property bool bomb: false
    property string caption: ""
    property int tick: 0
    Timer {
        interval: 125
        running: root.visible && root.mode === "finder"
        repeat: true
        onTriggered: root.tick++
    }

    function key(k) {
        if (mode === "album") {
            if (k === "left" || k === "4") {
                pic = Math.max(0, pic - 1);
                return true;
            }
            if (k === "right" || k === "6") {
                pic = Math.min(album.length - 1, pic + 1);
                return true;
            }
            const a = album[pic];
            if (k === "call" && a) {
                Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && cp -n "$2" "$1/"', "sh", Config.home + "/Pictures/angelOS", a.path]);
                PhoneLine.play("sms", 0.5);
                return true;
            }
            if (k === "#" && a) {
                PhoneLine.dropPhoto(a.path);
                pic = Math.max(0, Math.min(pic, album.length - 2));
                return true;
            }
            if (k === "end") {
                mode = "finder";
                return true;
            }
            return false;
        }
        if (k === "left" || k === "4") {
            bd = (bd + backdrops.length - 1) % backdrops.length;
            return true;
        }
        if (k === "right" || k === "6") {
            bd = (bd + 1) % backdrops.length;
            return true;
        }
        if (k === "5" || k === "ok" || k === "call") {
            shoot();
            return true;
        }
        if (k === "*") {
            mode = "album";
            pic = 0;
            return true;
        }
        return false;
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", PhoneLine.albumDir])
    function shoot() {
        if (posing.running)
            return;
        // her pose for this one
        wink = Math.random() < 0.4;
        smile = Math.random() < 0.5;
        wings = Math.random() < 0.5;
        lean = (Math.random() - 0.5) * 12;
        bomb = Math.random() < 0.12;
        caption = "";
        posing.restart();
    }
    SequentialAnimation {
        id: posing
        PauseAnimation {
            duration: 350
        }
        ScriptAction {
            script: {
                PhoneLine.play("shutter", 0.8);
                flash.opacity = 1;
                const path = PhoneLine.albumDir + "/" + Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss") + ".png";
                photo.grabToImage(r => {
                    if (r.saveToFile(path)) {
                        PhoneLine.keepPhoto(path, root.who);
                        root.caption = root.bomb ? PhoneLine.photobomb : PhoneLine.selfieLine(root.who);
                    }
                }, Qt.size(photo.width * 2, photo.height * 2));
            }
        }
        NumberAnimation {
            target: flash
            property: "opacity"
            to: 0
            duration: 400
        }
    }

    // ---- the finder: what the photo will be ----
    Item {
        id: photo
        visible: root.mode === "finder"
        width: parent.width
        height: parent.height - root.k * 12
        clip: true
        readonly property var b: root.backdrops[root.bd]
        Rectangle {
            anchors.fill: parent
            color: photo.b[2]
        }
        PhoneWall {
            anchors.fill: parent
            kind: photo.b[0]
            color: photo.b[3]
            opacity: 0.55
        }
        // the other one, peeking in from the side
        PhoneCharm {
            visible: root.bomb && posing.running || root.bomb && root.caption !== ""
            x: parent.width - width * 0.6
            y: parent.height * 0.25
            who: root.who === "angel" ? "demon" : "angel"
            pixel: root.k * 2
            rotation: -20
        }
        // her, posing
        SpriteRig {
            id: her
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -height * 0.18
            width: ready ? implicitWidth : 0
            height: ready ? implicitHeight : 0
            who: root.who
            angelVariant: Angel.angelLook === "glitch" || Angel.angelLook === "ophanim" ? Angel.angelLook : ""
            demonVariant: Config.y2k.demonLook === "glitch" ? "glitch" : ""
            skin: root.who === "demon" && Story.inHell ? HellLook.circle : ""
            use: true
            tick: root.tick
            swingTick: root.tick
            blink: root.wink && (posing.running || root.caption !== "")
            talk: root.smile && (posing.running || root.caption !== "")
            flutter: root.wings
            blush: posing.running || root.caption !== "" ? 1 : 0
            px: ready ? Math.max(0.5, photo.height * 0.95 / Math.max(1, rig.size[1])) : 1
            rotation: posing.running || root.caption !== "" ? root.lean : 0
        }
        PhoneCharm {
            visible: !her.ready
            anchors.centerIn: parent
            who: root.who
            pixel: root.k * 2
            tick: root.tick
        }
        // the date, the way they stamped it
        PxText {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.k * 2
            text: Qt.formatDate(new Date(), "dd MM 'yy")
            kind: "tiny"
            color: "#ffb21a"
            style: Text.Outline
            styleColor: "#5a3000"
        }
        Rectangle {
            id: flash
            anchors.fill: parent
            color: "#ffffff"
            opacity: 0
        }
    }
    // what she says about it, and which backdrop
    PxText {
        visible: root.mode === "finder"
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.caption || ("◀ " + root.backdrops[root.bd][1] + " ▶   * " + I18n.t("альбом", "album"))
        kind: "tiny"
        color: root.caption ? root.phone.trim : root.dimInk
    }

    // ---- the album ----
    Item {
        visible: root.mode === "album"
        anchors.fill: parent
        PxText {
            visible: !root.album.length
            anchors.centerIn: parent
            text: I18n.t("Альбом пуст", "The album is empty")
            kind: "tiny"
            color: root.dimInk
        }
        Image {
            visible: root.album.length > 0
            width: parent.width
            height: parent.height - root.k * 12
            fillMode: Image.PreserveAspectFit
            smooth: false
            source: root.album[root.pic] ? "file://" + root.album[root.pic].path : ""
        }
        PxText {
            visible: root.album.length > 0
            anchors.bottom: parent.bottom
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: (root.pic + 1) + " / " + root.album.length + "   # " + I18n.t("удалить", "delete")
            kind: "tiny"
            color: root.dimInk
        }
    }
}
