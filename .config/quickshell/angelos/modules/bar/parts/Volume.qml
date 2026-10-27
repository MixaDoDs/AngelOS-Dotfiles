import QtQuick
import qs.config
import qs.services
import qs.widgets
import qs.modules.bar

PxButton {
    id: root

    // screen readers (widgets/A11y.js): what this icon is
    Accessible.name: I18n.t("Громкость", "Volume")
    Accessible.description: Audio.muted ? I18n.t("без звука", "muted") : Math.round(Audio.volume * 100) + "%"

    property bool above: true
    // the bubble over it (BarItem)
    readonly property string barTip: Audio.muted ? I18n.t("Без звука", "Muted") : I18n.t("Громкость ", "Volume ") + Math.round(Audio.volume * 100) + " %"
    property bool showPercent: true

    compact: true
    flat: true
    icon: Audio.muted || Audio.volume <= 0.001 ? "speakerMute" : "speaker"
    // the number only for a moment after the volume changes (the wheel, the keys, the mixer): it
    // slides out of the key and back in, the icon alone the rest of the time
    // (the hell bar keeps the number always)
    text: showPercent && (told.running || barInk) ? Math.round(Audio.volume * 100) + "%" : ""
    checked: pop.visible
    clip: true
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Motion.ms(140)
            easing.type: Easing.OutCubic
        }
    }
    Timer {
        id: told
        interval: 1600
    }
    // not for the sound coming up as the shell starts: only a second after the sink is there
    property bool armed: false
    Timer {
        running: Audio.ready && !root.armed
        interval: 1000
        onTriggered: root.armed = true
    }
    Connections {
        target: Audio
        enabled: root.armed
        function onVolumeChanged() {
            told.restart();
        }
        function onMutedChanged() {
            told.restart();
        }
    }
    onClicked: pop.toggle()
    onRightClicked: Audio.toggleMute()

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.02 : -0.02)
    }

    // built when the pointer comes to the button, gone a while after it closed (LazyPopup)
    LazyPopup {
        id: pop
        panelId: I18n.exe(I18n.t("звук", "audio"))
        anchorItem: root
        warm: root.hovered
        MixerPanel {
            id: mixer
            anchorItem: root
            above: root.above
        }
    }
}
