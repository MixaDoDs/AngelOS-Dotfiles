import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#0a0c14"

    readonly property real s: Screen.height / 768
    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property real ui: 0

    // Colors
    readonly property color cyanWire: "#5ce5e6"
    readonly property color electricBlue: "#62a3f0"
    readonly property color cleanWhite: "#ffffff"
    readonly property color metalDark: "#0b151f"
    readonly property color darkTeal: "#132c38"

    FolderListModel {
        id: fontFolder
        folder: Qt.resolvedUrl("font")
        nameFilters: ["*.ttf", "*.otf"]
    }

    FontLoader {
        id: pf
        source: fontFolder.count > 0 ? "font/" + fontFolder.get(0, "fileName") : ""
    }

    ListView {
        id: sessionHelper
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: root.sessionIndex
        opacity: 0
        width: 100
        height: 100
        z: -100
        delegate: Item {
            property string sName: model.name || ""
        }
    }

    ListView {
        id: userHelper
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: root.userIndex
        opacity: 0
        width: 100
        height: 100
        z: -100
        delegate: Item {
            property string uName: model.realName || model.name || ""
            property string uLogin: model.name || ""
        }
    }

    Timer {
        interval: 300
        running: true
        onTriggered: pwd.forceActiveFocus()
    }

    Component.onCompleted: {
        fadeAnim.start();
        keyboard.numLock = true;
    }

    NumberAnimation {
        id: fadeAnim
        target: root
        property: "ui"
        from: 0
        to: 1
        duration: 800
        easing.type: Easing.OutCubic
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        z: -1
    }

    Loader {
        anchors.fill: parent
        source: "BackgroundVideo.qml"
    }

    // Scanlines
    Rectangle {
        anchors.fill: parent
        z: 1
        opacity: 0.08
        color: "transparent"
        visible: root.ui > 0

        // Borders
        Rectangle {
            width: 2 * s
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 20 * s
            color: root.cyanWire
        }
        Rectangle {
            width: 2 * s
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: 20 * s
            color: root.cyanWire
        }
    }

    // Gradients
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 120 * s
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#e0070912" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 300 * s
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: "#f4050d14" }
        }
    }

    // Error
    Text {
        id: errText
        text: ""
        anchors.horizontalCenter: loginPanel.horizontalCenter
        anchors.bottom: loginPanel.top
        anchors.bottomMargin: 6 * s
        color: "#ff4766"
        font.family: pf.name
        font.pixelSize: 10 * s
        font.bold: true
        opacity: text.length > 0 ? 1 : 0
    }

    // Login
    Row {
        id: loginPanel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6 * s
        height: 28 * s
        spacing: 8 * s
        opacity: root.ui

        // User
        Item {
            width: 140 * s
            height: 28 * s

            // Background
            Rectangle {
                anchors.fill: parent
                color: root.metalDark
                opacity: 0.85
                border.color: userMouse.containsMouse ? root.cyanWire : root.electricBlue
                border.width: 1 * s
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            Text {
                id: userLabelText
                text: "USER //"
                color: root.electricBlue
                font.family: pf.name
                font.pixelSize: 11 * s
                font.bold: true
                font.letterSpacing: 1 * s
                anchors.left: parent.left
                anchors.leftMargin: 12 * s
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: ((userHelper.currentItem && userHelper.currentItem.uName) ? userHelper.currentItem.uName : (userModel.lastUser || "User")).toUpperCase()
                color: userMouse.containsMouse ? root.cyanWire : root.cleanWhite
                font.family: pf.name
                font.pixelSize: 11 * s
                font.bold: true
                font.letterSpacing: 1 * s
                anchors.left: userLabelText.right
                anchors.leftMargin: 6 * s
                anchors.right: parent.right
                anchors.rightMargin: 12 * s
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            MouseArea {
                id: userMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof userModel !== "undefined" && userModel.rowCount() > 0)
                        root.userIndex = (root.userIndex + 1) % userModel.rowCount()
                }
            }
        }

        // Password
        Item {
            width: 180 * s
            height: 28 * s

            // Background
            Rectangle {
                anchors.fill: parent
                color: root.metalDark
                opacity: 0.85
                border.color: pwd.focus ? root.cyanWire : root.electricBlue
                border.width: 1 * s
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            TextInput {
                id: pwd
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10 * s
                anchors.rightMargin: 10 * s
                color: root.cyanWire
                font.family: pf.name
                font.pixelSize: 12 * s
                font.letterSpacing: 3 * s
                echoMode: TextInput.Password
                passwordCharacter: "■"
                onTextEdited: errText.text = ""
                focus: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                cursorVisible: false
                cursorDelegate: Item { width: 0; height: 0 }
                selectionColor: root.cyanWire

                property bool wasClicked: false
                onActiveFocusChanged: if (!activeFocus && text.length === 0) wasClicked = false

                Keys.onReturnPressed: doLogin()
                Keys.onEnterPressed: doLogin()
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10 * s
                anchors.verticalCenter: parent.verticalCenter
                text: "PASSWORD"
                color: root.cleanWhite
                font.family: pf.name
                font.pixelSize: 9 * s
                font.letterSpacing: 1 * s
                opacity: pwd.text.length === 0 ? 0.5 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // Cursor
            Rectangle {
                id: customCursor
                width: 8 * s
                height: pwd.cursorRectangle.height
                color: root.cyanWire
                y: pwd.y + pwd.cursorRectangle.y
                x: pwd.x + pwd.cursorRectangle.x
                visible: pwd.focus && (pwd.text.length > 0 || pwd.wasClicked)

                SequentialAnimation {
                    loops: Animation.Infinite
                    running: customCursor.visible
                    NumberAnimation { target: customCursor; property: "opacity"; from: 1; to: 0.1; duration: 400 }
                    NumberAnimation { target: customCursor; property: "opacity"; from: 0.1; to: 1; duration: 400 }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    pwd.forceActiveFocus()
                    pwd.wasClicked = true
                }
            }
        }

        // Button
        Item {
            width: 80 * s
            height: 28 * s

            // Background
            Rectangle {
                anchors.fill: parent
                color: root.metalDark
                opacity: loginMouse.containsMouse ? 0.95 : 0.85
                border.color: loginMouse.containsMouse ? root.cyanWire : root.electricBlue
                border.width: 1 * s
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            Text {
                id: btnText
                anchors.centerIn: parent
                text: "➔ LOGIN"
                color: loginMouse.containsMouse ? root.cyanWire : root.cleanWhite
                font.family: pf.name
                font.pixelSize: 9 * s
                font.letterSpacing: 1 * s
                font.bold: true
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            MouseArea {
                id: loginMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: doLogin()
            }
        }
    }

    // Top HUD
    Item {
        id: topHud
        anchors.top: parent.top
        anchors.topMargin: 40 * s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 60 * s
        anchors.rightMargin: 60 * s
        height: 80 * s
        opacity: root.ui

        // Clock
        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * s

            Row {
                spacing: 8 * s
                Rectangle {
                    width: 6 * s
                    height: 6 * s
                    color: root.cyanWire
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 600 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 600 }
                    }
                }
                Text {
                    text: "WELCOME BACK, " + ((userHelper.currentItem && userHelper.currentItem.uName) ? userHelper.currentItem.uName : (userModel.lastUser || "USER")).toUpperCase()
                    color: root.cyanWire
                    font.family: pf.name
                    font.pixelSize: 11 * s
                    font.letterSpacing: 2 * s
                    font.bold: true
                }
            }

            Text {
                id: clockText
                text: Qt.formatTime(new Date(), "HH:mm")
                color: root.cleanWhite
                font.family: pf.name
                font.pixelSize: 32 * s
                font.bold: true
                font.letterSpacing: 1 * s

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
                }
            }
        }

        // Date
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: dateText.implicitWidth + 30 * s
            height: 28 * s

            Rectangle {
                anchors.fill: parent
                color: root.darkTeal
                opacity: 0.3
                border.color: root.electricBlue
                border.width: 1 * s
            }

            Text {
                id: dateText
                anchors.centerIn: parent
                text: Qt.formatDate(new Date(), "dddd, MMMM d").toUpperCase()
                color: root.electricBlue
                font.family: pf.name
                font.pixelSize: 10 * s
                font.letterSpacing: 3 * s
                font.bold: true
            }
        }

        // Actions
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * s

            Repeater {
                model: [
                    { l: (sessionHelper.currentItem && sessionHelper.currentItem.sName ? sessionHelper.currentItem.sName : "Session").toUpperCase(), a: 2 },
                    { l: "REBOOT", a: 0 },
                    { l: "SHUTDOWN", a: 1 }
                ]

                delegate: Item {
                    visible: modelData.a === 2 ? !root.isQuickshell : true
                    width: pmt.implicitWidth + 30 * s
                    height: 28 * s

                    // Panel
                    Rectangle {
                        anchors.fill: parent
                        color: root.darkTeal
                        opacity: pm.containsMouse ? 0.45 : 0.25
                        border.color: pm.containsMouse ? root.cyanWire : root.electricBlue
                        border.width: 1 * s
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        id: pmt
                        anchors.centerIn: parent
                        text: modelData.l
                        color: pm.containsMouse ? root.cyanWire : root.cleanWhite
                        font.family: pf.name
                        font.pixelSize: 10 * s
                        font.letterSpacing: 1.5 * s
                        font.bold: true

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: pm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.a === 0) {
                                if (typeof sddm !== "undefined") sddm.reboot()
                            } else if (modelData.a === 1) {
                                if (typeof sddm !== "undefined") sddm.powerOff()
                            } else if (typeof sessionModel !== "undefined" && sessionModel.rowCount() > 0) {
                                root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            errText.text = "ACCESS DENIED";
            pwd.text = "";
            pwd.focus = true;
        }
    }

    function doLogin() {
        var u = (userHelper.currentItem && userHelper.currentItem.uLogin) ? userHelper.currentItem.uLogin : (typeof userModel !== "undefined" ? userModel.lastUser : "");
        if (typeof sddm !== "undefined")
            sddm.login(u, pwd.text, root.sessionIndex)
    }
}
