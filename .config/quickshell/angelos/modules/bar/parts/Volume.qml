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
    property bool showPercent: true

    compact: true
    icon: Audio.muted || Audio.volume <= 0.001 ? "speakerMute" : "speaker"
    text: showPercent ? Math.round(Audio.volume * 100) + "%" : ""
    checked: pop.visible
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
