import QtQuick
import qs.config
import qs.services

// The toy in a circle's menu look (Settings → Right-click menu → "Toys in hell's menus"): the
// look's drawing you can play with — the wheel spins, the fork pokes, the water splashes. It
// lies under the entries, so hovering and clicking them works as before; it takes the clicks
// that would have closed the menu only inside its zone (`radius` round `center`, or `zone`
// for a rectangle, or the whole look), the rest still close it and a right click there
// still moves the menu. Both buttons play: `down(x, y, right)`, `drag(x, y)`, `up(x, y)`,
// in the look's coordinates (the toy covers only its zone's box: its cursor shows there).
MouseArea {
    id: toy

    required property var menu              // RadialMenu
    property point center: Qt.point(menu.cx, menu.cy)
    property real radius: 0
    property rect zone: Qt.rect(0, 0, 0, 0)
    property bool held: false               // a press is on it now
    readonly property bool on: Config.desktop.menuToys !== false
    signal down(real x, real y, bool right)
    signal drag(real x, real y)
    signal up(real x, real y)

    function inside(x, y) {
        if (radius > 0)
            return Math.hypot(x - center.x, y - center.y) <= radius;
        if (zone.width > 0)
            return x >= zone.x && x <= zone.x + zone.width && y >= zone.y && y <= zone.y + zone.height;
        return true;
    }
    // once a menu opening: what it counts for (achievements: deskmenu.toy, the look)
    property bool noted: false
    function played() {
        if (noted)
            return;
        noted = true;
        Achievements.note("deskmenu.toy", menu.look);
    }
    Connections {
        target: toy.menu && toy.menu.opened ? toy.menu : null
        ignoreUnknownSignals: true
        function onOpened() {
            toy.noted = false;
        }
    }

    x: radius > 0 ? center.x - radius : zone.width > 0 ? zone.x : 0
    y: radius > 0 ? center.y - radius : zone.width > 0 ? zone.y : 0
    width: radius > 0 ? radius * 2 : zone.width > 0 ? zone.width : (parent ? parent.width : 0)
    height: radius > 0 ? radius * 2 : zone.width > 0 ? zone.height : (parent ? parent.height : 0)
    enabled: on
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: m => {
        if (!inside(x + m.x, y + m.y) || menu.reveal < 0.6) {
            m.accepted = false;
            return;
        }
        held = true;
        played();
        down(x + m.x, y + m.y, m.button === Qt.RightButton);
    }
    onPositionChanged: m => {
        if (held)
            drag(x + m.x, y + m.y);
    }
    onReleased: m => {
        if (!held)
            return;
        held = false;
        up(x + m.x, y + m.y);
    }
    onCanceled: held = false
}
