import QtQuick
import qs.config
import qs.services
import qs.widgets

// Desktop widget content — one file, every look (docs/PLUGINS.md → «Theme API»):
//   pixel  angelOS wraps it in a draggable window "__ID__.exe" (manifest "desktopTitle")
//   mac    Golden Gate: the host draws a Liquid Glass card, no title (Skin.macWidgets)
//   hell   while the demon rules (Theme.hell): the host burns it over and draws the hell frame;
//          the content draws its own hell version with the same data (manifest "realms")
// Colours, fonts and sizes come from the Theme API (services/Skin): never hard-coded. The
// shared controls (PxText, PxButton …) change by themselves. Size: implicitWidth/implicitHeight.
// Optional: `property bool wantVisible` hides the frame when false.
Item {
    id: root

    property var plugin
    property string screenName
    property var widget          // {uid, x, y, settings} of this instance

    readonly property int clicks: plugin ? plugin.get("clicks", 0) : 0
    // the same count; in hell they are souls, in blackletter when its font has the letters
    readonly property string countText: (Theme.hell ? I18n.t("душ: ", "souls: ") : I18n.t("кликов: ", "clicks: ")) + clicks
    readonly property bool gothic: Theme.hell && Theme.hellCovers(countText)

    implicitWidth: Math.max(col.implicitWidth, Skin.px(150))
    implicitHeight: col.implicitHeight

    Column {
        id: col
        anchors.centerIn: parent
        spacing: Skin.spacing

        // small caption: the Mac look labels its cards like macOS widgets, pixel and hell don't
        PxText {
            visible: Skin.macWidgets
            text: "__NAME__"
            kind: "tiny"
            color: Skin.textDim
        }
        // the look's own text (PxText picks the font and size of the look) …
        PxText {
            visible: !root.gothic
            text: root.countText
            kind: Skin.macWidgets ? "big" : "body"
            color: Theme.hell ? Theme.hellFlame : Skin.text
        }
        // … or hell's blackletter
        Text {
            visible: root.gothic
            text: root.countText
            font.family: Theme.fontHell
            font.pixelSize: Theme.hellPx(Theme.fs)
            color: Theme.hellFlame
            renderType: Text.NativeRendering
        }
        PxButton {
            text: Theme.hell ? I18n.t("Ещё душу", "One more soul") : "+1"
            accent: !Theme.hell
            hell: Theme.hell
            compact: true
            onClicked: if (root.plugin)
                root.plugin.set("clicks", root.clicks + 1)
        }
    }
}
