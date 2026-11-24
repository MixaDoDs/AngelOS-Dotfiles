pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "../widgets/MacIcons.js" as MacIcons  // serp-skin

// The look of the pixel menus (widgets/PxMenu: the desktop's, a widget's, the bar's, a task's,
// the tray's, the Halo's): one look for all of them, the bevelled box of Settings' cards, with
// a hell recolour (Theme.hell: the desktop is in hell while the demon rules). The table of
// tokens below is what the rows and the frame are drawn from. Everything is pixel-hard: no soft
// gradients, no blurred shadows.
Singleton {
    id: root

    function lookFor(kind) {
        return "classic";
    }

    // one width for every menu (art pixels × Theme.u): narrower ones grow, wider labels elide
    readonly property int minWidth: Theme.u * 120
    readonly property int maxWidth: Theme.u * 230

    // a shortcut in one format: ["Mod", "T"] or "Mod + T" → "Mod+T"
    function keyText(keys) {
        if (!keys)
            return "";
        const parts = typeof keys === "string" ? keys.split("+") : Array.from(keys);
        return parts.map(s => String(s).trim()).filter(s => s !== "").join("+");
    }
    // an entry's submenu: `children` (or the desktop lists' older `flyout`), a list or a
    // function that builds it as it opens
    function hasKids(it) {
        if (!it)
            return false;
        const c = it.children !== undefined ? it.children : it.flyout;
        return typeof c === "function" || (!!c && typeof c === "object" && c.length > 0);
    }
    function kidsOf(it) {
        if (!it)
            return [];
        const c = it.children !== undefined ? it.children : it.flyout;
        // a list that went through a model comes back as a sequence, not an Array
        const l = typeof c === "function" ? c() : c;
        return !!l && typeof l === "object" && l.length > 0 ? Array.from(l) : [];
    }
    function on(v, dflt) {
        return typeof v === "function" ? v() !== false : v === undefined ? dflt : v !== false;
    }

    // the tokens of the look a menu item stands in: the nearest parent with `menuTokens`
    // (PxMenuList), classic outside any (the bar's own menus as they are)
    function tokensFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.menuTokens !== undefined && p.menuTokens !== null)
                return p.menuTokens;
        return plain;
    }
    function tokens(look) {
        return classic;
    }

    readonly property bool hell: Theme.hell
    // tokens: frame (face, edge, hi, lo, flat, outline, hellBox, shadow, shadowColor, shadowU),
    // title (headText), rows (pad in art px, text, dim, ink for icons, outlineText: the text's
    // 1-pixel outline or "transparent", lit, litText, litInk, markerColor), lines (sepLo, sepHi),
    // tiles (tileBg, tileEdge, tileBevel)
    // classic in hell: hell's obsidian box (PxBox.hell), a blood-red highlight
    readonly property var classicHell: ({
            "name": "classic",
            "face": Theme.hellPanel,
            "edge": Theme.hellEdge,
            "hi": Theme.hellHi,
            "lo": Theme.hellLo,
            "flat": false,
            "outline": true,
            "hellBox": true,
            "shadow": true,
            "shadowColor": Qt.alpha(Theme.shadow, Theme.shadowAlpha),
            "shadowU": 2,
            "headText": Theme.hellTextDim,
            "pad": 5,
            "text": Theme.hellText,
            "dim": Theme.hellTextDim,
            "ink": Theme.hellText,
            "outlineText": "transparent",
            "lit": Theme.hellBlood,
            "litText": Theme.hellText,
            "litInk": Theme.hellText,
            "markerColor": Theme.hellBlood,
            "sepLo": Theme.hellLo,
            "sepHi": Theme.hellHi,
            "tileBg": Theme.mix(Theme.hellFace, Theme.hellBlood, 0.3),
            "tileEdge": Theme.hellEdge,
            "tileBevel": true
        })
    // classic as it always was; also what a PxMenuItem outside any PxMenu wears (the bar's
    // own menus, Start), in hell too: its box is not this engine's
    readonly property var plain: ({
            "name": "classic",
            "face": Qt.alpha(Theme.menuSurface, Theme.panelAlpha),
            "edge": Theme.edge,
            "hi": Theme.hi,
            "lo": Theme.lo,
            "flat": Theme.zine,
            "outline": true,
            "hellBox": false,
            "shadow": true,
            "shadowColor": Theme.popShadow,
            "shadowU": 2,
            "headText": Theme.textDim,
            "pad": 5,
            "text": Theme.text,
            "dim": Theme.textDim,
            "ink": Theme.dark ? Theme.text : Theme.edge,
            "outlineText": "transparent",
            "lit": Theme.select,
            "litText": Theme.selectText,
            "litInk": Theme.selectText,
            "markerColor": Theme.select,
            "sepLo": Theme.lo,
            "sepHi": Theme.hi,
            "tileBg": Theme.mix(Theme.face, Theme.accent, 0.18),
            "tileEdge": Theme.edge,
            "tileBevel": true
        })
    readonly property var classic: Serp.on ? serp : hell ? classicHell : plain  // serp-skin
    // serp-skin: the Serpantinum skin's menus. `serp` marks the set: PxMenuList lays `plate` (a
    // flat rounded Serp.solid) under a frame that draws nothing, rows light up rounded
    readonly property var serp: ({
            "name": "classic",
            "serp": true,
            "plate": Serp.solid,
            "face": "transparent",
            "edge": Serp.line,
            "hi": Serp.surface2,
            "lo": Serp.surface1,
            "flat": true,
            "outline": false,
            "hellBox": false,
            "shadow": false,
            "shadowColor": "transparent",
            "shadowU": 0,
            "headText": Serp.subtext0,
            "pad": 7,
            "text": Serp.text,
            "dim": Serp.subtext1,
            "ink": Serp.subtext1,
            "outlineText": "transparent",
            "lit": Serp.selected,
            "litText": Serp.accent,
            "litInk": Serp.accent,
            "markerColor": Serp.accent,
            "sepLo": Serp.line,
            "sepHi": "transparent",
            "tileBg": Serp.surface0,
            "tileEdge": Serp.line,
            "tileBevel": false
        })
    // a menu entry's pixel icon name → the line icon the skin draws (MacIcons, Lucide)
    readonly property var serpIcons: ({
            "prev": "skip-back", "next": "skip-forward", "pin": "star", "maximize": "maximize-2",
            "minimize": "minimize-2", "warn": "circle-x", "sparkleStar": "sparkles", "wifiOff": "wifi-off",
            "bolt": "zap", "chat": "bot", "width": "sliders-horizontal", "height": "sliders-horizontal",
            "spider": "activity", "skull": "angel-horns", "rotate": "rotate-ccw", "pill": "toggle-right",
            "note": "file-text", "allDesks": "layout-grid", "phone": "airplay", "headphones": "volume-2",
            "ampoule": "sun", "ethernet": "ethernet-port", "eye": "eye", "pause": "pause", "minus": "minus"
        })
    function serpIcon(n) {
        return serpIcons[n] || MacIcons.fromPixel(n || "") || "circle-dot";
    }
}
