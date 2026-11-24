pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets
import qs.modules.serp

// serp-skin: the sound (Serpantinum's VolumePopup) over angelOS's services/Audio: the liquid
// core with its gauge ring (drag / wheel = volume, click = mute), the default device beside it,
// the switch Выходы | Входы | Потоки and the rows under it: every output or input (the default
// one marked, a click makes another one the default) or every program playing, each with its
// own slider. Outputs blue, inputs mauve, streams green, as his.
Item {
    id: root
    property string screenName: ""
    property real progress: 1
    function st(d) {
        return Math.max(0, Math.min(1, (progress - d) / Math.max(0.01, 1 - d)));
    }
    implicitWidth: Serp.px(410)
    implicitHeight: Serp.px(580)

    property int tab: 0                       // 0 outputs · 1 inputs · 2 streams
    property color tint: tab === 0 ? Serp.blue : tab === 1 ? Serp.mauve : Serp.green
    Behavior on tint {
        ColorAnimation {
            duration: Serp.normal
        }
    }

    // ---- the device the core and the header drive: the mic on Inputs, else the output ----
    readonly property bool onMic: tab === 1
    readonly property var node: onMic ? Audio.source : Audio.sink
    readonly property bool hasNode: !!node && !!node.audio
    readonly property real vol: onMic ? Audio.micVolume : Audio.volume
    readonly property bool mute: onMic ? Audio.micMuted : Audio.muted
    function setMain(v) {
        if (onMic)
            setNode(Audio.source, v);
        else
            Audio.setVolume(v);
    }
    function toggleMain() {
        if (onMic)
            Audio.toggleMic();
        else
            Audio.toggleMute();
    }

    // any node: the default ones through Audio (it unmutes and tells the OSD), others directly
    function isDefault(n) {
        return !!n && (tab === 0 ? !!Audio.sink && n.id === Audio.sink.id : tab === 1 ? !!Audio.source && n.id === Audio.source.id : false);
    }
    function setNode(n, v) {
        if (!n || !n.audio)
            return;
        v = Math.max(0, Math.min(1.5, v));
        if (Audio.sink && n.id === Audio.sink.id) {
            Audio.setVolume(v);
            return;
        }
        if (v > 0 && n.audio.muted)
            n.audio.muted = false;
        n.audio.volume = v;
    }
    function muteNode(n) {
        if (!n || !n.audio)
            return;
        if (Audio.sink && n.id === Audio.sink.id)
            Audio.toggleMute();
        else if (Audio.source && n.id === Audio.source.id)
            Audio.toggleMic();
        else
            n.audio.muted = !n.audio.muted;
    }
    function volIcon(v, m) {
        return m || v === 0 ? "volume-x" : v < 0.34 ? "volume" : v < 0.67 ? "volume-1" : "volume-2";
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Serp.radius * 1.4, 24)
        color: Serp.ground
        border.width: 1
        border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
    }
    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Serp.px(18)
        spacing: Serp.px(15)

        // ---- the core and the default device ----
        RowLayout {
            Layout.fillWidth: true
            spacing: Serp.px(16)
            opacity: root.st(0)
            transform: Translate {
                y: Serp.px(25) * (1 - root.st(0))
            }

            SerpSoundCore {
                Layout.preferredWidth: Serp.px(124)
                Layout.preferredHeight: Serp.px(124)
                level: root.vol
                muted: root.mute
                tint: root.tint
                live: root.visible && root.hasNode
                enabled: root.hasNode
                opacity: root.hasNode ? 1 : 0.4
                onMoved: v => root.setMain(v)
                onToggled: root.toggleMain()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Serp.px(10)
                Column {
                    Layout.fillWidth: true
                    spacing: Serp.px(2)
                    SText {
                        width: parent.width
                        text: root.hasNode ? Audio.nodeName(root.node) : root.onMic ? "Нет микрофона" : "Нет выхода"
                        size: Serp.px(17)
                        black: true
                    }
                    SText {
                        width: parent.width
                        text: root.tab === 0 ? "выход по умолчанию" : root.tab === 1 ? "микрофон по умолчанию" : "общая громкость · " + Audio.appStreams.length + " " + root.plural(Audio.appStreams.length)
                        size: Serp.px(12)
                        dim: true
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Serp.px(8)
                    SButton {
                        implicitWidth: Serp.px(26)
                        implicitHeight: Serp.px(26)
                        flat: false
                        ground: Serp.surface1
                        enabled: root.hasNode
                        SIcon {
                            name: root.onMic ? "mic" : root.volIcon(root.vol, root.mute)
                            size: Serp.px(15)
                            color: root.mute ? Serp.red : Serp.subtext0
                        }
                        onClicked: root.toggleMain()
                    }
                    SerpSoundSlider {
                        Layout.fillWidth: true
                        value: root.vol
                        tint: root.tint
                        muted: root.mute
                        enabled: root.hasNode
                        onMoved: v => root.setMain(v)
                    }
                    SText {
                        Layout.preferredWidth: Serp.px(38)
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(root.vol * 100) + "%"
                        size: Serp.px(11)
                        bold: true
                        color: root.mute ? Serp.overlay : Serp.subtext0
                    }
                }
            }
        }

        // ---- Выходы | Входы | Потоки ----
        Item {
            id: tabs
            Layout.fillWidth: true
            Layout.preferredHeight: Serp.px(38)
            opacity: root.st(0.08)
            transform: Translate {
                y: Serp.px(15) * (1 - root.st(0.08))
            }
            readonly property var labels: ["Выходы", "Входы", "Потоки"]
            readonly property real cell: width / 3
            Rectangle {
                anchors.fill: parent
                radius: Serp.radius
                color: Serp.surface0
                border.width: 1
                border.color: Qt.tint(Serp.base, Qt.alpha(Serp.text, 0.12))  // opaque: blur noise showed through the clear line
            }
            Rectangle {
                x: root.tab * tabs.cell + Serp.px(3)
                y: Serp.px(3)
                width: tabs.cell - Serp.px(6)
                height: parent.height - Serp.px(6)
                radius: Math.max(2, Serp.radius - Serp.px(3))
                color: root.tint
                Behavior on x {
                    NumberAnimation {
                        duration: Serp.slow
                        easing.type: Easing.OutQuint
                    }
                }
            }
            Row {
                anchors.fill: parent
                Repeater {
                    model: tabs.labels
                    Item {
                        id: tcell
                        required property int index
                        required property string modelData
                        width: tabs.cell
                        height: tabs.height
                        readonly property int count: index === 0 ? Audio.sinks.length : index === 1 ? Audio.sources.length : Audio.appStreams.length
                        Row {
                            anchors.centerIn: parent
                            spacing: Serp.px(5)
                            SText {
                                text: tcell.modelData
                                size: Serp.px(12)
                                bold: true
                                color: root.tab === tcell.index ? Serp.onAccent : tma.containsMouse ? Serp.text : Serp.subtext0
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Serp.quick
                                    }
                                }
                            }
                            SText {
                                visible: tcell.count > 0
                                text: tcell.count
                                size: Serp.px(10)
                                bold: true
                                color: root.tab === tcell.index ? Qt.alpha(Serp.onAccent, 0.6) : Serp.overlay
                            }
                        }
                        MouseArea {
                            id: tma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tab = tcell.index
                        }
                    }
                }
            }
        }

        // ---- the rows ----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: root.st(0.16)
            transform: Translate {
                y: Serp.px(15) * (1 - root.st(0.16))
            }

            ListView {
                id: list
                anchors.fill: parent
                spacing: Serp.px(10)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // by identity: a row being dragged stays when angelOS's own clicks come and go
                model: ScriptModel {
                    values: root.tab === 0 ? Audio.sinks : root.tab === 1 ? Audio.sources : Audio.appStreams
                }
                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Serp.slow
                        easing.type: Easing.OutQuint
                    }
                }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property var n: modelData
                    readonly property bool apps: root.tab === 2
                    readonly property bool def: root.isDefault(n)
                    readonly property bool live: !!n && !!n.audio
                    readonly property real v: live ? n.audio.volume : 0
                    readonly property bool m: live ? n.audio.muted : false
                    readonly property var props: n && n.properties ? n.properties : ({})
                    readonly property string title: apps ? Audio.streamName(n) : Audio.nodeName(n)
                    readonly property string sub: {
                        if (apps) {
                            const media = String(props["media.name"] || "");
                            return media && media !== title ? media : "приложение";
                        }
                        if (def)
                            return "по умолчанию";
                        return cma.containsMouse ? "нажми, чтобы сделать основным" : root.tab === 0 ? "выход" : "вход";
                    }
                    width: list.width
                    height: Serp.px(84)
                    radius: Serp.radius
                    color: def ? Qt.alpha(root.tint, 0.16) : cma.containsMouse ? Serp.surface1 : Serp.surface0
                    border.width: 1
                    border.color: def ? Qt.alpha(root.tint, 0.55) : Serp.line
                    Behavior on color {
                        ColorAnimation {
                            duration: Serp.normal
                        }
                    }

                    // a staggered entrance on every tab switch
                    property real born: 0
                    Component.onCompleted: bornAnim.start()
                    SequentialAnimation {
                        id: bornAnim
                        PauseAnimation {
                            duration: 40 + Math.min(row.index, 8) * 40
                        }
                        NumberAnimation {
                            target: row
                            property: "born"
                            from: 0
                            to: 1
                            duration: 500
                            easing.type: Easing.OutQuint
                        }
                    }
                    opacity: born
                    transform: Translate {
                        y: Serp.px(12) * (1 - row.born)
                    }

                    MouseArea {
                        id: cma
                        anchors.fill: parent
                        hoverEnabled: !row.apps
                        cursorShape: !row.apps && !row.def ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (row.apps || row.def)
                                return;
                            if (root.tab === 0)
                                Audio.setDefaultSink(row.n);
                            else
                                Audio.setDefaultSource(row.n);
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Serp.px(12)
                        anchors.rightMargin: Serp.px(12)
                        anchors.topMargin: Serp.px(10)
                        anchors.bottomMargin: Serp.px(12)
                        spacing: Serp.px(8)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Serp.px(10)
                            Rectangle {
                                Layout.preferredWidth: Serp.px(30)
                                Layout.preferredHeight: Serp.px(30)
                                radius: Serp.radiusSmall
                                color: row.def ? root.tint : Serp.surface1
                                SIcon {
                                    anchors.centerIn: parent
                                    visible: !row.apps
                                    name: root.tab === 1 ? "mic" : "volume-2"
                                    size: Serp.px(16)
                                    color: row.def ? Serp.onAccent : Serp.subtext1
                                }
                                AppIcon {
                                    anchors.centerIn: parent
                                    visible: row.apps
                                    size: Serp.px(20)
                                    iconName: String(row.props["application.icon-name"] || "")
                                    appId: String(row.props["application.process.binary"] || row.props["application.name"] || "").toLowerCase()
                                }
                            }
                            Column {
                                Layout.fillWidth: true
                                spacing: Serp.px(1)
                                SText {
                                    width: parent.width
                                    text: row.title
                                    size: Serp.px(13)
                                    bold: true
                                }
                                SText {
                                    width: parent.width
                                    text: row.sub
                                    size: Serp.px(10.5)
                                    color: row.def ? root.tint : Serp.subtext0
                                }
                            }
                            SIcon {
                                visible: row.def
                                name: "check"
                                size: Serp.px(16)
                                color: root.tint
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Serp.px(10)
                            SButton {
                                implicitWidth: Serp.px(24)
                                implicitHeight: Serp.px(24)
                                flat: false
                                ground: Serp.surface1
                                enabled: row.live
                                SIcon {
                                    name: root.tab === 1 ? "mic" : root.volIcon(row.v, row.m)
                                    size: Serp.px(14)
                                    color: row.m ? Serp.red : Serp.subtext0
                                }
                                onClicked: root.muteNode(row.n)
                            }
                            SerpSoundSlider {
                                Layout.fillWidth: true
                                // a node not bound yet reads 0: keep it still until it is
                                enabled: row.live
                                value: row.v
                                tint: root.tint
                                muted: row.m
                                onMoved: x => root.setNode(row.n, x)
                            }
                            SText {
                                Layout.preferredWidth: Serp.px(36)
                                horizontalAlignment: Text.AlignRight
                                text: row.live ? Math.round(row.v * 100) + "%" : "—"
                                size: Serp.px(11)
                                bold: true
                                color: row.m ? Serp.overlay : Serp.subtext0
                            }
                        }
                    }
                }
            }

            // nothing here
            Column {
                anchors.centerIn: parent
                visible: list.count === 0
                spacing: Serp.px(8)
                SIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.tab === 0 ? "volume-x" : root.tab === 1 ? "mic" : "music"
                    size: Serp.px(28)
                    color: Serp.surface2
                }
                SText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.tab === 0 ? "Нет выходов" : root.tab === 1 ? "Нет микрофонов" : "Сейчас ничего не играет"
                    size: Serp.px(13)
                    color: Serp.overlay
                }
            }
        }
    }

    function plural(k) {
        const a = k % 10, b = k % 100;
        return a === 1 && b !== 11 ? "приложение" : a >= 2 && a <= 4 && (b < 10 || b >= 20) ? "приложения" : "приложений";
    }
}
