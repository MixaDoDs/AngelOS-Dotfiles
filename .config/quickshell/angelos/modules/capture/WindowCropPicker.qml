pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets
import "CropGeometry.js" as Geometry

Scope {
    LazyLoader {
        active: LiveCrops.pickerVisible

        PanelWindow {
            id: win

            readonly property var pick: LiveCrops.picking
            screen: pick ? Shell.screenByName(pick.screen) : null
            color: Qt.alpha(Theme.shadow, 0.79)
            exclusionMode: ExclusionMode.Ignore
            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "angelos-window-crop-picker"
            // takes input: the user is selecting a rectangle, and Escape cancels it.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            RightClickGuard {}

            WindowCropFeed {
                id: feed
                windowId: win.pick ? win.pick.windowId : -1
                requested: !!win.pick
                once: true
                maxWidth: 1440
                maxHeight: 900
            }

            FocusScope {
                id: form
                anchors.fill: parent
                focus: true

                property var selection: null

                function finish() {
                    if (selection && preview.status === Image.Ready)
                        LiveCrops.pin(selection, preview.sourceSize.width / preview.sourceSize.height);
                }

                Keys.onEscapePressed: LiveCrops.picking = null
                Keys.onReturnPressed: finish()
                Keys.onEnterPressed: finish()

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.pad * 2

                    PxText {
                        width: parent.width
                        text: win.pick ? win.pick.title : ""
                        color: Theme.text
                        kind: "title"
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                    }

                    PxBox {
                        id: frame
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property real aspect: preview.sourceSize.width > 0 && preview.sourceSize.height > 0
                            ? preview.sourceSize.width / preview.sourceSize.height : 16 / 9
                        readonly property real maxW: Math.max(1, win.width - Theme.u * 40)
                        readonly property real maxH: Math.max(1, win.height - Theme.u * 100)
                        width: Math.round(Math.min(maxW, maxH * aspect))
                        height: Math.round(width / aspect)
                        shadow: true

                        Image {
                            id: preview
                            anchors.fill: parent
                            source: feed.frameUrl
                            cache: false
                            fillMode: Image.Stretch
                        }

                        PxText {
                            anchors.centerIn: parent
                            visible: preview.status !== Image.Ready
                            text: feed.failed || preview.status === Image.Error
                                ? I18n.t("Кадр окна недоступен", "Window preview is unavailable")
                                : I18n.t("Получаю кадр окна…", "Getting a preview of the window…")
                        }

                        MouseArea {
                            id: selectArea
                            anchors.fill: parent
                            enabled: preview.status === Image.Ready
                            cursorShape: Qt.CrossCursor

                            property point start: Qt.point(0, 0)

                            onPressed: mouse => {
                                start = Qt.point(mouse.x, mouse.y);
                                form.selection = null;
                            }
                            onPositionChanged: mouse => {
                                if (pressed)
                                    form.selection = Geometry.select(start.x, start.y, mouse.x, mouse.y, width, height);
                            }
                            onReleased: mouse => {
                                form.selection = Geometry.select(start.x, start.y, mouse.x, mouse.y, width, height);
                            }
                        }

                        Rectangle {
                            readonly property var crop: form.selection
                            visible: !!crop
                            x: crop ? Math.round(crop.x * parent.width) : 0
                            y: crop ? Math.round(crop.y * parent.height) : 0
                            width: crop ? Math.round(crop.w * parent.width) : 0
                            height: crop ? Math.round(crop.h * parent.height) : 0
                            color: Qt.alpha(Theme.accent, 0.16)
                            border.width: Theme.u
                            border.color: Theme.accent
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.pad

                        PxButton {
                            text: I18n.t("Отмена", "Cancel")
                            onClicked: LiveCrops.picking = null
                        }
                        PxButton {
                            text: I18n.t("Оставить на столе", "Pin to desktop")
                            icon: "pin"
                            accent: true
                            enabled: !!form.selection
                            onClicked: form.finish()
                        }
                    }

                    PxText {
                        width: parent.width
                        text: I18n.t("Выделите нужную часть окна", "Drag to select part of the window")
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
