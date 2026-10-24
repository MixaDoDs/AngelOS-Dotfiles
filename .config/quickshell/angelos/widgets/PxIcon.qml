import QtQuick
import qs.config
import "Icons.js" as Icons
import "IconSets.js" as IconSets

// Pixel-art icon rendered from an ASCII bitmap (see Icons.js).
Image {
    id: root
    // inside the P5 settings window: its colours (Theme.tone)
    readonly property bool p5: Theme.p5For(root.parent)

    property string name: "heart"
    property var bitmap: null   // optional custom rows, overrides `name`
    property int pixel: Theme.u
    // a fractional art pixel when the size has to match something exactly (AngelLogo's
    // pixel wordmarks next to text); 0 = `pixel`
    property real exactPixel: 0
    readonly property real _px: exactPixel > 0 ? exactPixel : pixel
    property bool hollow: false
    property color ink: Theme.dark ? Theme.tone("text", root.p5) : Theme.tone("edge", root.p5)
    property color fill: Theme.accent
    property color fill2: Theme.accent2
    property color fill3: Theme.accent3
    property color light: "#ffffff"
    property color body: Theme.dark ? Theme.tone("faceAlt", root.p5) : Theme.tone("sunken", root.p5)
    property color bad: Theme.danger
    // more colours for detailed art: {"char": "#rrggbb"}, also overriding the ones above
    property var palette: ({})

    // the icon style (Settings → Appearance → Icons, D3): angelOS's own, pixelarticons or
    // HackerNoon's. Theirs are drawn on a 24-unit grid, a whole number of screen pixels per
    // cell, in the box of ours — at most a third larger; smaller than that, or a name the set
    // lacks, and it is ours (a custom `bitmap` too)
    property string iconStyle: Config.appearance.iconStyle || "angelos"
    readonly property var _alt: {
        if ((bitmap && bitmap.length) || iconStyle === "angelos")
            return null;
        const rows = IconSets.get(iconStyle, name);
        if (!rows)
            return null;
        const own = Icons.get(name);
        const box = own.reduce((m, r) => Math.max(m, r.length), own.length) * _px;
        const cells = Math.max(rows.length, rows[0].length);
        const k = Math.max(1, Math.round(box / cells));
        return cells * k <= box * 1.35 ? {
            "rows": rows,
            "px": k
        } : null;
    }

    readonly property var _svg: Icons.svg(_alt ? _alt.rows : bitmap && bitmap.length ? bitmap : name, Object.assign({
        "#": Theme.hex(ink),
        "o": Theme.hex(fill),
        "x": Theme.hex(fill2),
        "y": Theme.hex(fill3),
        "w": Theme.hex(light),
        "f": Theme.hex(body),
        "r": Theme.hex(bad)
    }, palette || {}), hollow)

    source: _svg.url
    width: Math.round(_svg.width * (_alt ? _alt.px : _px))
    height: Math.round(_svg.height * (_alt ? _alt.px : _px))
    sourceSize: Qt.size(width, height)
    smooth: false
    mipmap: false
    cache: true
    // an icon whose source changes (the cat's frames) lost a frame while the next one loaded,
    // seen as a blink whenever a popup opened or closed (#82)
    retainWhileLoading: true
}
