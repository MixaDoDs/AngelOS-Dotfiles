import QtQuick
import qs.config

// A line of text behind a layered scene's nearer layers (widgets/SceneWall: depth): set on the
// scene's art grid in the pixel title font at a whole multiple of its 9 px design size, as big
// as fits the place, one colour with no soft edges, then scaled up with the picture.
Item {
    id: root

    property string text
    property real k: 1                 // screen px per art px (SceneWall.k)
    // the colours come from the scene's palette: the theme's accent gives the hue, what stands
    // behind the text (`backdrop`, its luminance) says dark or light glyphs; the scene may fix
    // them (`fixed`). Four looks (`look`), all hard pixels.
    property var palette: []           // [[r, g, b], ...]
    property real backdrop: 0.5
    property color accent: Theme.accent
    property bool themeDark: Theme.dark
    property var fixed: ({})           // {"color", "shadow"} from scene.json depth_text
    // texture: the glyphs take the grain of the picture itself (a layer of the scene, from
    // `textureFrom` on the canvas, art px): its darker specks become a second shade of the glyphs
    property bool textured: true
    property url textureSource
    property point textureFrom: Qt.point(0, 0)
    property size canvasSize: Qt.size(1, 1)
    property real time: 0              // the scene's seconds
    // light touches on the neon, bits: 1 colour rising at the top, 2 electrodes, 4 scan lines,
    // 8 dust, 16 colour at the foot, 32 glow below (scene_text.frag); 0 is the first neon as it
    // was, the owner took the top brightest, electrodes and the glow below
    property int neonFx: 50
    // the whole scene, for chrome to mirror (SceneWall.depthReflection)
    property url reflectionSource

    function lin(c) {
        return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }
    function luma(c) {
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }
    function contrast(a, b) {
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
    }
    // [glyph, second, light, dark]: glyphs dark on a light backdrop (a light theme leans to dark
    // glyphs), in the palette colour nearest the accent's hue among those that stand out from the
    // backdrop (3:1, big text); the second (shadow, ring) must stand out from both the glyphs and
    // the backdrop — a light shadow vanished into light clouds — nearest the accent's hue among
    // the best of those; light and dark are the palette's ends
    readonly property var picked: {
        const cols = palette.map(c => Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1));
        if (cols.length === 0)
            return ["#ffffff", "#000000", "#ffffff", "#000000", "#ffffff", "#ffffff"];
        const hue = accent.hslHue;
        const off = c => {
            const dh = Math.abs(c.hslHue - hue);
            return c.hslSaturation < 0.12 || hue < 0 ? 0.5 : Math.min(dh, 1 - dh);
        };
        const darkGlyphs = backdrop > (themeDark ? 0.5 : 0.3);
        const side = cols.filter(c => (luma(c) < backdrop) === darkGlyphs);
        let fit = side.filter(c => contrast(luma(c), backdrop) >= 3);
        if (fit.length === 0)
            fit = side.length ? side : cols;
        const glyph = fit.reduce((a, c) => off(c) - 0.15 * c.hslSaturation < off(a) - 0.15 * a.hslSaturation ? c : a);
        // standing out from both counts most; the accent's hue and colour only tip the balance
        const both = c => Math.min(contrast(luma(c), backdrop), contrast(luma(c), luma(glyph)));
        const score = c => both(c) * (1.15 - 0.3 * off(c) + 0.15 * c.hslSaturation);
        const second = cols.reduce((a, c) => score(c) > score(a) ? c : a);
        const light = cols.reduce((a, c) => luma(c) > luma(a) ? c : a);
        const dark = cols.reduce((a, c) => luma(c) < luma(a) ? c : a);
        // the texture's second shade: near the glyphs' hue, a step off them, still clear of the backdrop
        const step = c => {
            const k = contrast(luma(c), luma(glyph));
            return k < 1.3 || k > 2.6 || contrast(luma(c), backdrop) < 2 ? 9 : off(c) + Math.abs(k - 1.7);
        };
        const alt = cols.reduce((a, c) => step(c) < step(a) ? c : a);
        // the neon tube's lower half: halfway between the light end and the glyphs, near the hue
        const want = (luma(light) + luma(glyph)) / 2;
        // it has to stay clear of the backdrop and keep the accent's colour
        const midOf = c => Math.abs(luma(c) - want) * 3 + off(c) * 4 - c.hslSaturation * 0.3 + (contrast(luma(c), backdrop) < 1.8 ? 9 : 0);
        const mid = cols.filter(c => c !== light).reduce((a, c) => midOf(c) < midOf(a) ? c : a);
        return [glyph, second, light, dark, step(alt) < 9 ? alt : glyph, mid];
    }
    readonly property color color: fixed.color || picked[0]
    readonly property color shadow: fixed.shadow || picked[1]
    // outline | neon | chrome | cutout | lcd | aqua (scene_text.frag); anything else is neon
    property string look: "neon"
    readonly property int styleIndex: [0, 1, 2, 3, 4, 5][["outline", "neon", "chrome", "cutout", "lcd", "aqua"].indexOf(look)] ?? 1
    readonly property bool cutout: look === "cutout"
    // the palette colour nearest to one asked for (the LCD's greys and greens)
    function nearest(want) {
        let best = Qt.rgba(1, 1, 1, 1), bd = 9;
        for (const c of palette) {
            const d = Math.pow(c[0] / 255 - want.r, 2) + Math.pow(c[1] / 255 - want.g, 2) + Math.pow(c[2] / 255 - want.b, 2);
            if (d < bd) {
                bd = d;
                best = Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1);
            }
        }
        return best;
    }
    // a calling card (Persona 5): every symbol cut from another magazine — [family, bold]
    // heavy faces only: a thin stroke falls apart on the art grid
    readonly property var cutFonts: [[Theme.fontTitle, true], [Theme.fontHell, false], ["Liberation Serif", true], ["DejaVu Sans", true], ["Liberation Sans", true]]
    // ink that stands out from a plate: the light or the dark end
    function inkOn(c) {
        return contrast(luma(c), luma(picked[2])) > contrast(luma(c), luma(picked[3])) ? picked[2] : picked[3];
    }
    function charHash(i) {
        const x = Math.sin((i + 1) * 91.7 + text.length * 7.3) * 43758.5453;
        return x - Math.floor(x);
    }

    anchors.fill: parent

    Image {
        id: reflImg
        source: root.look === "chrome" && root.textured ? root.reflectionSource : ""
        smooth: false
        visible: false
    }
    Image {
        id: texImg
        source: root.textured ? root.textureSource : ""
        smooth: false
        visible: false
    }

    TextMetrics {
        id: base
        font.family: Theme.fontTitle
        font.bold: true
        font.pixelSize: 9
        text: root.text
    }
    // room round the glyphs for rings and shadows, art px
    readonly property int pad: 6
    // how many art px one font px is: the biggest that fits the place
    readonly property int s: Math.max(1, Math.floor(Math.min((art.width - 2 * pad) / Math.max(1, base.advanceWidth), (art.height - pad) / 9)))
    // the ring / shadow width, art px (the shader looks 8 px round at most)
    readonly property int w: Math.min(look === "neon" ? 3 : 4, Math.max(1, Math.ceil(s / 2)))

    Item {
        id: art
        width: Math.floor(root.width / root.k)
        height: Math.floor(root.height / root.k)
        scale: root.k
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: false
        layer.textureSize: Qt.size(width, height)
        layer.effect: ShaderEffect {
            property color glyph: root.color
            property color second: root.shadow
            property color light: root.picked[2]
            property color dark: root.picked[3]
            property size texel: Qt.size(1 / art.width, 1 / art.height)
            // the glyphs' ink, top to bottom (chrome's bands)
            property point band: Qt.point((label.y + label.baselineOffset + base.tightBoundingRect.y * root.s) / art.height, (label.y + label.baselineOffset + (base.tightBoundingRect.y + base.tightBoundingRect.height) * root.s) / art.height)
            property real w: root.w
            property real style: root.styleIndex
            property color glyphAlt: root.picked[4]
            property real textured: root.textured && texImg.status === Image.Ready ? 1 : 0
            property var pattern: texImg
            property point texFrom: root.textureFrom
            property size canvas: root.canvasSize
            property size artSize: Qt.size(art.width, art.height)
            property color mid: root.picked[5] || root.picked[2]
            property real time: root.time
            property real neonFx: root.neonFx
            property point fontAt: Qt.point(label.x, label.y)
            property real fontPx: root.s
            property var reflection: reflImg.status === Image.Ready ? reflImg : texImg
            // a Nokia screen: its panel round the glyphs (art px), its greens out of the palette
            property rect panel: Qt.rect(label.x - 2 * root.s, band.x * art.height - 2 * root.s, label.width + 4 * root.s, (band.y - band.x) * art.height + 4 * root.s)
            property color lcdBg: root.nearest(Qt.rgba(0.70, 0.78, 0.60, 1))
            property color lcdInk: root.nearest(Qt.rgba(0.17, 0.22, 0.16, 1))
            property color lcdGhost: root.nearest(Qt.rgba(0.55, 0.62, 0.48, 1))
            fragmentShader: Qt.resolvedUrl("../shaders/scene_text.frag.qsb")
        }

        // the calling card: the symbols in a row, each its own font, size and tilt, on a plate
        // black, white or the accent by turns (now and then none: a big letter on its own);
        // as big as fits
        Item {
            id: card
            visible: root.cutout
            anchors.centerIn: parent
            width: cardRow.width
            height: cardRow.height
            scale: Math.min(1, (art.width - 2 * root.pad) / Math.max(1, width), (art.height - root.pad) / Math.max(1, height))
            Row {
                id: cardRow
                spacing: Math.round(root.s / 3)
                Repeater {
                    model: root.cutout ? root.text.split("") : []
                    Item {
                        id: cut
                        required property string modelData
                        required property int index
                        readonly property var f: root.cutFonts[Math.floor(root.charHash(index + 9) * root.cutFonts.length)]
                        // 0 dark, 1 light, 2 the accent by turns; now and then 3, no plate
                        readonly property int kind: index > 0 && root.charHash(index + 60) < 0.2 ? 3 : (index + Math.floor(root.charHash(99) * 3)) % 3
                        readonly property color plateColor: [root.picked[3], root.picked[2], root.color][Math.min(2, kind)]
                        readonly property real tilt: (index % 2 ? 1 : -1) * (6 + 12 * root.charHash(index + 30))
                        readonly property real size: cut.kind === 3 ? 1.45 : 0.8 + 0.6 * root.charHash(index + 10)
                        width: glyph.contentWidth * 0.92
                        height: 9 * root.s * 1.6
                        visible: modelData !== " "
                        Rectangle {
                            visible: cut.kind < 3
                            anchors.centerIn: parent
                            // tight round the letter, cut crooked: its own tilt, not the letter's
                            width: glyph.contentWidth + root.s * (0.5 + root.charHash(cut.index + 40))
                            height: glyph.font.pixelSize * (0.8 + 0.15 * root.charHash(cut.index + 41))
                            rotation: -cut.tilt * 0.5 + 10 * (root.charHash(cut.index + 42) - 0.5)
                            antialiasing: false
                            color: cut.plateColor
                        }
                        Text {
                            id: glyph
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: (root.charHash(cut.index + 20) - 0.5) * 2 * root.s
                            rotation: cut.tilt
                            text: cut.modelData
                            font.family: cut.f[0]
                            font.bold: cut.f[1]
                            font.pixelSize: Math.round(12 * root.s * cut.size)
                            font.weight: Font.Black
                            color: cut.kind === 3 ? root.color : root.inkOn(cut.plateColor)
                        }
                    }
                }
            }
        }

        Text {
            id: label
            visible: !root.cutout
            // whole art px: the neon's tube reads the glyphs on the font's own grid
            x: Math.floor((parent.width - width) / 2)
            y: root.pad / 2
            text: root.text
            font.family: Theme.fontTitle
            font.bold: true
            font.pixelSize: 9 * root.s
            color: "white"
        }
    }
}
