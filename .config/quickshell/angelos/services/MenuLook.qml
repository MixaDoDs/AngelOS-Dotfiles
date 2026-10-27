pragma Singleton

import QtQuick
import Quickshell
import qs.config

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
    readonly property var classic: hell ? classicHell : plain
}
