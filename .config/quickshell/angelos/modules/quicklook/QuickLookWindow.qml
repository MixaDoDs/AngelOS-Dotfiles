pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Quick Look (services/QuickLook): the file in a window in the middle of the screen —
// a picture, a frame of a video, an album cover, a PDF's first page, text, a folder's or
// an archive's list, a font's letters. Space / Esc: away; Enter: open; arrows: the next
// file in Nautilus.
Scope {
    LazyLoader {
        active: QuickLook.open

        PanelWindow {
            id: win
            screen: Shell.focusedScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Qt.alpha(Theme.shadow, 0.35)
            WlrLayershell.namespace: "angelos-quicklook"
            WlrLayershell.layer: WlrLayer.Overlay
            // takes input: the preview: a click beside it closes it, Space too
            WlrLayershell.keyboardFocus: Shell.dev ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive

            readonly property int u: Theme.u
            readonly property var info: QuickLook.info || {}
            readonly property string kind: info.kind || ""
            readonly property real maxW: width * 0.78
            readonly property real maxH: height * 0.78
            // the picture's own size, fitted
            readonly property size pic: {
                // a video without a frame made for it: its own size
                const w = picImg.status === Image.Ready ? picImg.implicitWidth : kind === "video" ? info.width || 0 : 0;
                const h = picImg.status === Image.Ready ? picImg.implicitHeight : kind === "video" ? info.height || 0 : 0;
                if (!w || !h)
                    return Qt.size(u * 200, u * 130);
                const k = Math.min(1, (maxW - u * 8) / w, (maxH - u * 40) / h);
                // small pixel pictures: whole multiples, crisp
                const up = w < 300 && h < 300 ? Math.max(1, Math.floor(Math.min((maxW - u * 8) / w, (maxH - u * 40) / h, 4))) : k;
                return Qt.size(Math.round(w * up), Math.round(h * up));
            }
            readonly property bool usesPicture: kind === "image" || kind === "video" || ((kind === "pdf" || kind === "audio") && !!info.picture)
            readonly property bool plays: (kind === "video" || kind === "audio") && !QuickLook.loading

            MouseArea {
                anchors.fill: parent
                onClicked: QuickLook.close()
            }
            Item {
                id: keys
                focus: true
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Space || e.key === Qt.Key_Escape)
                        QuickLook.close();
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                        QuickLook.openIt();
                    else if (e.key === Qt.Key_Left)
                        QuickLook.step("left");
                    else if (e.key === Qt.Key_Right)
                        QuickLook.step("right");
                    else if (e.key === Qt.Key_Up && !textView.visible)
                        QuickLook.step("up");
                    else if (e.key === Qt.Key_Down && !textView.visible)
                        QuickLook.step("down");
                    else
                        return;
                    e.accepted = true;
                }
                Component.onCompleted: forceActiveFocus()
            }

            PxWindow {
                id: dialog
                anchors.centerIn: parent
                title: win.info.name || QuickLook.path.split("/").pop()
                icon: win.kind === "folder" ? "folder" : win.kind === "image" ? "image" : win.kind === "video" ? "play" : win.kind === "audio" ? "music" : win.kind === "text" ? "document" : win.kind === "archive" ? "package" : "document"
                translucent: false
                onCloseClicked: QuickLook.close()
                readonly property real contentW: win.usesPicture ? win.pic.width : win.kind === "text" ? Math.min(win.maxW, win.u * 260) : win.kind === "folder" || win.kind === "archive" ? win.u * 170 : win.kind === "font" ? Math.min(win.maxW, win.u * 240) : win.u * 150
                readonly property real contentH: win.usesPicture ? win.pic.height : win.kind === "text" ? Math.min(win.maxH - win.u * 40, win.u * 200) : win.kind === "folder" || win.kind === "archive" ? Math.min(win.maxH - win.u * 40, win.u * 150) : win.kind === "font" ? win.u * 120 : win.u * 60
                width: Math.max(win.u * 150, contentW + bodyPadding * 2 + chrome * 2)
                height: contentH + footer.implicitHeight + win.u * 4 + titleHeight + bodyPadding * 2 + chrome * 2

                MouseArea {
                    anchors.fill: parent
                }

                Item {
                    id: stage
                    width: parent.width
                    height: dialog.contentH

                    PxText {
                        anchors.centerIn: parent
                        visible: QuickLook.loading && !win.usesPicture
                        dim: true
                        text: I18n.t("Смотрю…", "Looking…")
                    }

                    // pictures: the file itself, or the frame / page / cover made for it
                    Image {
                        id: picImg
                        visible: win.usesPicture && !win.info.animated
                        anchors.centerIn: parent
                        width: win.pic.width
                        height: win.pic.height
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: implicitWidth >= 300 || implicitHeight >= 300
                        mipmap: smooth
                        source: !win.usesPicture ? "" : win.kind === "image" ? "file://" + QuickLook.path : win.info.picture ? "file://" + win.info.picture : ""
                    }
                    AnimatedImage {
                        visible: win.usesPicture && !!win.info.animated
                        anchors.centerIn: parent
                        width: win.pic.width
                        height: win.pic.height
                        fillMode: Image.PreserveAspectFit
                        playing: visible
                        source: visible ? "file://" + QuickLook.path : ""
                    }
                    // a video, a song: it plays (the frame above stays until the first picture);
                    // a click pauses, the strip below seeks
                    MediaPlayer {
                        id: player
                        source: win.plays ? "file://" + QuickLook.path : ""
                        audioOutput: AudioOutput {}
                        videoOutput: vout
                        onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia)
                            play()
                    }
                    VideoOutput {
                        id: vout
                        visible: win.kind === "video" && player.position > 0
                        anchors.centerIn: parent
                        width: win.pic.width
                        height: win.pic.height
                        fillMode: VideoOutput.PreserveAspectFit
                    }
                    MouseArea {
                        visible: win.plays
                        anchors.fill: parent
                        onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                    }
                    Rectangle {
                        id: seekBar
                        visible: win.plays && player.duration > 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: win.u * 2
                        color: Qt.alpha(Theme.shadow, 0.5)
                        Rectangle {
                            width: parent.width * Math.min(1, player.position / Math.max(1, player.duration))
                            height: parent.height
                            color: Theme.accent
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.topMargin: -win.u * 3
                            onPressed: m => player.position = m.x / width * player.duration
                            onPositionChanged: m => {
                                if (pressed)
                                    player.position = Math.max(0, Math.min(1, m.x / width)) * player.duration;
                            }
                        }
                    }
                    PxBox {
                        visible: win.kind === "video" || win.kind === "audio"
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: win.u * 3
                        anchors.bottomMargin: win.u * 5
                        width: vrow.implicitWidth + win.u * 6
                        height: vrow.implicitHeight + win.u * 4
                        Row {
                            id: vrow
                            anchors.centerIn: parent
                            spacing: win.u * 2
                            PxIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: player.playbackState === MediaPlayer.PlayingState ? "pause" : win.kind === "video" ? "play" : "music"
                            }
                            PxText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: [player.duration > 0 ? QuickLook.duration(player.position / 1000) + " / " + QuickLook.duration(player.duration / 1000) : QuickLook.duration(win.info.duration), win.info.width ? win.info.width + "×" + win.info.height : "", (win.info.tags || {}).artist || "", (win.info.tags || {}).title || ""].filter(s => s).join(" · ")
                            }
                        }
                    }
                    // a song without a cover: its tags, big
                    Column {
                        visible: win.kind === "audio" && !win.info.picture && !QuickLook.loading
                        anchors.centerIn: parent
                        spacing: win.u * 3
                        PxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "cd"
                            pixel: win.u * 3
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            kind: "title"
                            text: (win.info.tags || {}).title || win.info.name || ""
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            dim: true
                            text: [(win.info.tags || {}).artist, (win.info.tags || {}).album].filter(s => s).join(" — ")
                        }
                    }

                    // text
                    PxBox {
                        id: textView
                        visible: win.kind === "text"
                        anchors.fill: parent
                        sunken: true
                        Flickable {
                            id: flick
                            anchors.fill: parent
                            anchors.margins: win.u * 3
                            clip: true
                            contentWidth: width
                            contentHeight: body.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            TextEdit {
                                id: body
                                width: flick.width
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.WrapAnywhere
                                textFormat: TextEdit.PlainText
                                color: Theme.text
                                selectionColor: Theme.select
                                selectedTextColor: Theme.selectText
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.sizeMono
                                text: win.kind === "text" ? (win.info.text || "") + (win.info.cut ? "\n…" : "") : ""
                            }
                        }
                    }

                    // a folder or an archive: what is inside
                    Column {
                        visible: win.kind === "folder" || win.kind === "archive"
                        anchors.fill: parent
                        spacing: win.u * 2
                        PxText {
                            id: listHead
                            text: I18n.t("Внутри: ", "Inside: ") + (win.info.count || 0) + (win.kind === "folder" && win.info.size >= 0 ? " · " + QuickLook.size(win.info.size) : "")
                            dim: true
                        }
                        PxBox {
                            width: parent.width
                            height: parent.height - listHead.height - win.u * 2
                            sunken: true
                            ListView {
                                anchors.fill: parent
                                anchors.margins: win.u * 2
                                clip: true
                                model: win.info.list || []
                                delegate: Row {
                                    required property string modelData
                                    spacing: win.u * 2
                                    height: Theme.sizeBody + win.u * 3
                                    PxIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: parent.modelData.endsWith("/") ? "folder" : "document"
                                        pixel: Math.max(1, win.u / 2)
                                    }
                                    PxText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: parent.modelData
                                        elide: Text.ElideMiddle
                                        width: win.u * 150
                                    }
                                }
                            }
                        }
                    }

                    // a font: its letters
                    FontLoader {
                        id: fontFile
                        source: win.kind === "font" ? "file://" + QuickLook.path : ""
                    }
                    Column {
                        visible: win.kind === "font"
                        anchors.fill: parent
                        spacing: win.u * 2
                        clip: true
                        Repeater {
                            model: [40, 28, 18, 13]
                            Text {
                                required property int modelData
                                width: parent.width
                                elide: Text.ElideRight
                                font.family: fontFile.name
                                font.pixelSize: modelData
                                color: Theme.text
                                text: modelData > 30 ? (fontFile.name || "Aa") : I18n.t("Съешь же ещё этих мягких французских булок. The quick brown fox jumps over the lazy dog 0123456789", "The quick brown fox jumps over the lazy dog. Съешь же ещё этих мягких французских булок 0123456789")
                            }
                        }
                    }

                    // anything else: what it is
                    Column {
                        visible: win.kind === "other" || !!win.info.error
                        anchors.centerIn: parent
                        spacing: win.u * 3
                        PxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: win.info.error ? "warn" : "document"
                            pixel: win.u * 3
                        }
                        PxText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            dim: true
                            text: win.info.error === "missing" ? I18n.t("Файла нет", "No such file") : win.info.mime || ""
                        }
                    }
                }

                Row {
                    id: footer
                    y: stage.height + win.u * 4
                    width: parent.width
                    spacing: win.u * 3
                    PxText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - openBtn.width - (sendBtn.visible ? sendBtn.width + win.u * 3 : 0) - win.u * 3
                        elide: Text.ElideRight
                        kind: "tiny"
                        dim: true
                        text: [QuickLook.size(win.info.size), win.info.pages ? I18n.t(win.info.pages + " стр.", win.info.pages + " pages") : "", win.info.modified ? Qt.formatDateTime(new Date(win.info.modified * 1000), "d.MM.yyyy HH:mm") : "", I18n.t("пробел — закрыть", "Space to close") + (QuickLook.fromNautilus ? I18n.t(" · ←→ — соседние", " · ←→ next") : "")].filter(s => s).join(" · ")
                    }
                    // to a phone nearby (Quick Share / LocalSend): a file or a folder
                    PxButton {
                        id: sendBtn
                        visible: Config.quickshare.enabled
                        text: I18n.t("Отправить рядом", "Send nearby")
                        icon: "plane"
                        onClicked: {
                            QuickShare.share([QuickLook.path], "");
                            QuickLook.close();
                        }
                    }
                    PxButton {
                        id: openBtn
                        text: I18n.t("Открыть", "Open")
                        icon: "window"
                        accent: true
                        onClicked: QuickLook.openIt()
                    }
                }
            }
            RightClickGuard {}
        }
    }
}
