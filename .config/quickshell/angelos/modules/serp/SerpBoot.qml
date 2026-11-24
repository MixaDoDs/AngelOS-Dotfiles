pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// serp-skin: the boot screen under the serp skin («Пробуждение», in modules/y2k/BootScreen's
// window and on its clock `p`): a drop of light falls out of the dark, rings run out as on water,
// the drop opens into a halo that fills with light round from its top (the progress), the halo
// rises to where the Halo lives and the screen opens in a circle onto the desktop. The picture is
// one shader (shaders/serp_boot.frag) over the wallpaper as through frosted glass; the words are
// the skin's font. The show, its timing, its once-a-login and its click to skip stay the author's.
Item {
    id: root

    property real p: 0
    property string screenName: ""

    readonly property real m: Math.min(width, height)
    readonly property real cy: height * 0.42
    readonly property real fill: Math.max(0, Math.min(1, (p - 0.24) / 0.60))
    function smooth(a, b, x) {
        const t = Math.max(0, Math.min(1, (x - a) / (b - a)));
        return t * t * (3 - 2 * t);
    }

    // the wallpaper in screen space (the glass's own backdrop), on even with the glass off
    SerpBackdrop {
        id: wallBack
        screenName: root.screenName
        active: true
        blur: 0
    }

    ShaderEffect {
        anchors.fill: parent
        property real p: root.p
        property size resolution: Qt.size(width, height)
        property color accent: Serp.accent
        property color base: Serp.crust
        property real haloY: Serp.barHeight / 2
        property real wallOn: wallBack.ready ? 1 : 0
        property variant wall: wallBack.texture
        fragmentShader: Qt.resolvedUrl("shaders/serp_boot.frag.qsb")
    }

    // the words under the halo
    Column {
        id: words
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy + root.m * 0.17 * 0.30 + root.m * 0.07 + (1 - root.smooth(0.30, 0.46, root.p)) * root.m * 0.02
        spacing: root.m * 0.018
        opacity: root.smooth(0.30, 0.46, root.p) * (1 - root.smooth(0.80, 0.88, root.p))

        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "angelOS"
            size: root.m * 0.058
            bold: true
            color: Serp.text
            font.letterSpacing: root.m * 0.006
        }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.p < 0.42 ? I18n.t("Пробуждение…", "Waking up…")
                : root.p < 0.60 ? I18n.t("Собираю острова…", "Gathering the islands…")
                : root.p < 0.78 ? I18n.t("Наливаю стекло…", "Pouring the glass…")
                : I18n.t("Готово ♡", "Ready ♡")
            size: root.m * 0.024
            color: Qt.alpha(Serp.text, 0.78)
        }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.fill * 100) + "%  ·  " + I18n.t("клик — пропустить", "click to skip")
            size: root.m * 0.017
            color: Qt.alpha(Serp.text, 0.5)
        }
    }
}
